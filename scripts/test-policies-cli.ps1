<#
.SYNOPSIS
    Agent-driven test runner for a batch of policy definitions of one effect type.

.DESCRIPTION
    Reads policies from ./allPolicyContents.json (a JSON array), and for each one asks the
    specialised agent to generate a bash (or PowerShell) test script, executes it via WSL/native
    bash or pwsh, reads the logging.json result written by the script's cleanup trap, and formats
    the outcome. Writes RESULT.md, DEBUG.md and evidence.md to the CI runner's temp directory for
    the calling workflow to upload as artifacts, and exits 1 if any policy errored during testing.
    See docs/Scripts-Reference.md for the full flow and script-extraction fallback order.

.PARAMETER Endpoint
    Azure AI Foundry project endpoint.

.PARAMETER AssistantId
    Identifier of the specialised (or ephemeral, per-policy) agent to call.

.PARAMETER AgentType
    One of deny, audit, dine, modify. Controls prompt wording and DINE-specific handling.

.PARAMETER JobId
    Prefix applied to resource names created by generated scripts, to avoid naming clashes
    between concurrent test runs. Forwarded to scripts via the JOB_ID_PREFIX environment variable.

.PARAMETER MaxParallelPolicies
    Reserved for future parallel execution; policies are currently processed sequentially.

.PARAMETER MaxRetryAttempts
    Maximum number of script-generation attempts (including the initial attempt) before a policy
    is reported as errored with no script generated.

.PARAMETER InitialRetryDelaySeconds
    Reserved for future backoff between retry attempts.

.PARAMETER WorkflowRunUrl
    URL of the calling workflow run, included in result markdown and evidence records for traceability.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Endpoint,

    [Parameter(Mandatory = $true)]
    [string]$AssistantId,

    [Parameter()]
    [string]$AgentType = "modify",

    [Parameter()]
    [string]$JobId = "default",

    [Parameter()]
    [int]$MaxParallelPolicies = 2,

    [Parameter()]
    [int]$MaxRetryAttempts = 3,

    [Parameter()]
    [int]$InitialRetryDelaySeconds = 2,

    [Parameter()]
    [string]$WorkflowRunUrl = ""
)

# ── Validation ─────────────────────────────────────────────────────────────────

$validAgentTypes = @("deny", "audit", "dine", "modify")
if ($AgentType -notin $validAgentTypes) {
    Write-Error "Invalid agent type '$AgentType'. Valid types are: $($validAgentTypes -join ', ')"
    exit 1
}

# ── Output paths ───────────────────────────────────────────────────────────────

# Resolve the CI-provided temp directory so this script makes no Linux/`/tmp` assumption.
$OutputDir = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP }
elseif ($env:AGENT_TEMPDIRECTORY) { $env:AGENT_TEMPDIRECTORY }
else { [System.IO.Path]::GetTempPath() }
$ResultPath = Join-Path $OutputDir 'RESULT.md'
$DebugPath = Join-Path $OutputDir 'DEBUG.md'
$EvidencePath = Join-Path $OutputDir 'evidence.md'

# ── Helper functions ───────────────────────────────────────────────────────────

# Detects whether WSL or native bash is available for script execution.
function Test-BashEnvironment {
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        Write-Host "✅ WSL detected - will use WSL bash"
        return @{ Available = $true; Method = "wsl" }
    }
    elseif (Get-Command bash -ErrorAction SilentlyContinue) {
        Write-Host "✅ Native bash detected - will use native bash"
        return @{ Available = $true; Method = "bash" }
    }
    else {
        Write-Host "❌ No bash environment detected (neither WSL nor native bash)"
        return @{ Available = $false; Method = $null }
    }
}

# Extracts the first fenced code block from agent response text.
# Returns @{ Content = '...'; Language = 'powershell'|'bash' } or $null.
function Get-ScriptFromText {
    param([string]$Text)

    # Explicit PowerShell fence labels
    $match = [regex]::Match($Text, '(?s)```(?:powershell|pwsh|ps1)\s*\n(.*?)\n```')
    if ($match.Success) { return @{ Content = $match.Groups[1].Value.Trim(); Language = 'powershell' } }

    # Explicit bash/sh fence labels
    $match = [regex]::Match($Text, '(?s)```(?:bash|sh)\s*\n(.*?)\n```')
    if ($match.Success) { return @{ Content = $match.Groups[1].Value.Trim(); Language = 'bash' } }

    # Fallback: any fenced block — infer language from content heuristics
    $match = [regex]::Match($Text, '(?s)```\w*\s*\n(.*?)\n```')
    if ($match.Success) {
        $content = $match.Groups[1].Value.Trim()
        $isPowerShell = $content -match '^param\s*\(' -or
        $content -match '\$ErrorActionPreference' -or
        $content -match 'New-Az|Get-Az|Set-Az|Remove-Az|Write-Host'
        return @{ Content = $content; Language = if ($isPowerShell) { 'powershell' } else { 'bash' } }
    }

    # Fallback: un-fenced script returned as raw text with a shebang line.
    # Agents frequently emit the script body directly (e.g. "#!/bin/bash ...")
    # without wrapping it in a markdown code fence. Extract from the shebang to EOF.
    $shebang = [regex]::Match($Text, '(?m)^\s*#!.*$')
    if ($shebang.Success) {
        $content = $Text.Substring($shebang.Index).Trim()
        $language = if ($shebang.Value -match 'pwsh|powershell') { 'powershell' } else { 'bash' }
        return @{ Content = $content; Language = $language }
    }

    # Fallback: un-fenced PowerShell body with no shebang, detected via strong heuristics.
    $psSignal = $Text -match '(?m)^\s*param\s*\(' -or
    $Text -match '\$ErrorActionPreference' -or
    $Text -match 'New-Az|Get-Az|Set-Az|Remove-Az'
    if ($psSignal) {
        return @{ Content = $Text.Trim(); Language = 'powershell' }
    }

    # Fallback: un-fenced bash body with no shebang, detected via common az CLI usage.
    $bashSignal = $Text -match '(?m)^\s*set\s+-euo\s+pipefail' -or
    $Text -match '(?m)^\s*az\s+\w' -or
    $Text -match '(?m)^\s*(if|for|while)\s'
    if ($bashSignal) {
        return @{ Content = $Text.Trim(); Language = 'bash' }
    }

    return $null
}

function Invoke-DineConversation {
    param(
        [string]$AgentId,
        [string]$ConversationId,
        [string]$UserInput,
        [int]$TimeoutSeconds = 300
    )

    $body = @{
        agent        = @{ type = 'agent_reference'; name = $AgentId }
        input        = $UserInput
        conversation = $ConversationId
    }
    $response = Invoke-MetroAIApiCall -Service 'openai/responses' -Operation 'responses' `
        -Method Post -ContentType 'application/json' -Body $body -TimeoutSeconds $TimeoutSeconds
    if (-not $response) { throw "No response returned from the DINE agent." }

    $assistantTextParts = @()
    foreach ($outputItem in @($response.output)) {
        if ($outputItem.type -eq 'mcp_approval_request') {
            throw "The DINE agent requested MCP approval, but policy test agents must not have MCP tools configured."
        }
        if ($outputItem.type -ne 'message' -or $outputItem.role -ne 'assistant') { continue }
        foreach ($contentPart in @($outputItem.content)) {
            if ($contentPart.type -ne 'output_text' -or -not $contentPart.text) { continue }
            if ($contentPart.text -is [string]) {
                $assistantTextParts += $contentPart.text
            }
            elseif ($contentPart.text.PSObject.Properties.Name -contains 'value') {
                $assistantTextParts += $contentPart.text.value
            }
        }
    }

    return [PSCustomObject]@{
        AssistantText = $assistantTextParts -join "`n"
        ResponseId    = $response.id
        RawResponse   = $response
    }
}

# Calls the agent using a two-turn conversation.
# Turn 1: policy analysis only (short, fast response keeps the model within 100 seconds).
# Turn 2: full script generation using the analysis as context.
# DINE generation uses Invoke-MetroAIApiCall directly because Metro.AI 2.0.0 does not
# expose its TimeoutSeconds parameter through Invoke-MetroAIConversation.
# Falls back to additional retry turns if no script is found in the generation response.
# Returns @{ Content; Language } or $null if all attempts fail.
function Invoke-AgentScript {
    param(
        [string]$AgentId,
        [string]$ConversationId,
        [string]$PolicyContent,
        [string]$AgentType,
        [int]$MaxAttempts
    )

    # Turn 1 — analysis only
    $turn1Prompt = @"
$PolicyContent

Analyze the above policy definition step by step:
1. Identify the trigger resource type from policyRule.if
2. Identify the deployed resource type from policyRule.then.details.type
3. List all roleDefinitionIds required
4. List all assignment parameters and their default values

Do NOT generate the script yet — analysis only.
"@
    Write-Host "Sending policy analysis request (turn 1 of 2)..."
    $analysisText = ""
    try {
        $turn1 = Invoke-MetroAIConversation -AgentId $AgentId -ConversationId $ConversationId -UserInput $turn1Prompt -AutoApprove
        $analysisText = $turn1.AssistantText
        Write-Host "Analysis received (length: $($analysisText.Length) chars)"
    }
    catch {
        Write-Warning "Analysis turn timed out or failed: $($_.Exception.Message) — will retry script generation directly"
    }

    # Turn 2: script generation in a fresh conversation.
    # Reusing the same conversation after an MCP-backed analysis turn can leave the
    # conversation pinned to an unresolved approval request even when -AutoApprove
    # was used internally by Invoke-MetroAIConversation. Carry the analysis text
    # forward explicitly instead of relying on the original conversation history.
    Write-Host "Requesting script generation (turn 2 of 2 — fresh conversation)..."
    $turn2ConversationId = $null
    try {
        $turn2Conversation = New-MetroAIConversation
        $turn2ConversationId = $turn2Conversation.id
        Write-Host "Script-generation conversation created. ID: $turn2ConversationId"
    }
    catch {
        Write-Warning "Failed to create fresh conversation for script generation: $($_.Exception.Message)"
    }
    $priorContext = ""
    if ($analysisText.Length -gt 0) { $priorContext = "Here is the prior analysis for this policy:`n$analysisText`n`n" }
    $turn2Prompt = if ($priorContext.Length -gt 0) {
        @"
$PolicyContent

$priorContext
Using the policy JSON and the prior context above, generate the complete executable test script as a fenced bash code block.
Use the policy JSON, agent instructions, and established Azure CLI syntax directly. Do not call external tools.
"@
    }
    else {
        "$PolicyContent`n`nGenerate the complete executable test script as a fenced bash code block using established Azure CLI syntax directly. Do not call external tools."
    }
    $turn2ConversationToUse = if ($turn2ConversationId) { $turn2ConversationId } else { $ConversationId }
    $turn2 = if ($AgentType -eq 'dine') {
        Invoke-DineConversation -AgentId $AgentId -ConversationId $turn2ConversationToUse -UserInput $turn2Prompt
    }
    else {
        Invoke-MetroAIConversation -AgentId $AgentId -ConversationId $turn2ConversationToUse -UserInput $turn2Prompt -AutoApprove
    }
    $responseText = $turn2.AssistantText
    Write-Host "Script generation response received (length: $($responseText.Length) chars)"

    $scriptResult = Get-ScriptFromText -Text $responseText
    $attempts = 2  # Two turns already consumed

    # Fallback retry turns if no script was found.
    # Each retry uses a FRESH conversation to avoid HTTP 400 "MCP approval not resolved"
    # errors. When Invoke-MetroAIConversation handles an MCP approval internally via
    # previous_response_id chaining, Foundry's conversation-level state pointer does not
    # advance — so continuing the same conversation always hits the stuck approval. A new
    # conversation has no history and is immune to this.
    while (-not $scriptResult -and $attempts -lt $MaxAttempts) {
        $attempts++
        Write-Host "No script found in response. Requesting generation (attempt $attempts of $MaxAttempts — fresh conversation)..."
        try {
            $retryConversation = New-MetroAIConversation
            $retryConvId = $retryConversation.id
            Write-Host "Retry conversation created. ID: $retryConvId"
        }
        catch {
            Write-Warning "Failed to create retry conversation: $($_.Exception.Message)"
            break
        }
        $retryPrompt = "$PolicyContent`n`nGenerate the complete executable test script as a fenced bash code block to test this $AgentType policy. Do not call external tools."
        $retryTurn = if ($AgentType -eq 'dine') {
            Invoke-DineConversation -AgentId $AgentId -ConversationId $retryConvId -UserInput $retryPrompt
        }
        else {
            Invoke-MetroAIConversation -AgentId $AgentId -ConversationId $retryConvId `
                -UserInput $retryPrompt -AutoApprove
        }
        $scriptResult = Get-ScriptFromText -Text $retryTurn.AssistantText
    }

    return $scriptResult
}

# Executes a generated test script and returns @{ ExitCode; Output }.
# Dispatches to pwsh, WSL bash, or native bash based on language and environment.
function Invoke-TestScript {
    param(
        [string]$ScriptPath,
        [string]$ScriptLanguage,
        [string]$BashMethod,
        [string]$JobId
    )

    $env:JOB_ID_PREFIX = $JobId
    $outputFile = [System.IO.Path]::GetTempFileName()
    try {
        if ($ScriptLanguage -eq 'powershell') {
            & pwsh -NonInteractive -File $ScriptPath 2>&1 | Tee-Object -FilePath $outputFile
        }
        elseif ($BashMethod -eq "wsl") {
            $wslPath = $ScriptPath.Replace('\', '/').Replace('C:', '/mnt/c')
            & wsl bash -c "export JOB_ID_PREFIX='$JobId' && chmod +x $wslPath && $wslPath" 2>&1 | Tee-Object -FilePath $outputFile
        }
        else {
            & chmod +x $ScriptPath
            & bash -c "export JOB_ID_PREFIX='$JobId' && $ScriptPath" 2>&1 | Tee-Object -FilePath $outputFile
        }
        $exitCode = $LASTEXITCODE
    }
    catch {
        if (Test-Path $outputFile) { Remove-Item $outputFile -Force -ErrorAction SilentlyContinue }
        throw
    }

    $output = if (Test-Path $outputFile) { Get-Content $outputFile -Raw } else { "" }
    Remove-Item $outputFile -Force -ErrorAction SilentlyContinue

    Write-Host "Script completed with exit code: $exitCode"
    return @{ ExitCode = $exitCode; Output = $output }
}

# Reads and parses logging.json written by the test script's cleanup trap.
# Returns @{ Data = <PSObject|$null>; RawJson = <string>; Error = <string|$null> }
function Read-TestLog {
    $logPath = "./logging.json"
    if (-not (Test-Path $logPath)) {
        return @{ Data = $null; RawJson = $null; Error = "not-found" }
    }

    $raw = Get-Content $logPath -Raw
    Remove-Item $logPath -Force -ErrorAction SilentlyContinue

    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @{ Data = $null; RawJson = $raw; Error = "empty" }
    }

    try {
        $parsed = $raw | ConvertFrom-Json
        return @{ Data = $parsed; RawJson = $raw; Error = $null }
    }
    catch {
        return @{ Data = $null; RawJson = $raw; Error = "parse-failed: $($_.Exception.Message)" }
    }
}

# Builds the markdown result block for a single policy from a parsed logging.json object.
# Returns a markdown string with the appropriate status icon and details list.
function Format-PolicyResult {
    param(
        [object]$LogData,
        [string]$PolicyName,
        [string]$AgentTypeDisplay,
        [string]$AgentType,
        [string]$RunLinkLine
    )

    # Extract TestResult (PascalCase key written by agents)
    $testResultProp = $LogData.PSObject.Properties | Where-Object { $_.Name -ieq "testresult" } | Select-Object -First 1
    $testResult = if ($testResultProp) { $testResultProp.Value } else { $null }

    # Build detail bullet list from all other properties
    $detailsLines = foreach ($prop in $LogData.PSObject.Properties) {
        if ($prop.Name -ine "testresult") {
            $label = $prop.Name.Substring(0, 1).ToUpper() + $prop.Name.Substring(1)
            $label = ($label -creplace '([A-Z])', ' $1').Trim()
            "- **${label}:** $($prop.Value)"
        }
    }
    $detailBlock = ($detailsLines -join "`n") + "`n"
    if ($RunLinkLine) { $detailBlock += "$RunLinkLine`n" }

    $isPass = $testResult -match '^(pass|success)'
    $isFail = $testResult -match '^fail'
    $isError = $testResult -match '^error'

    if ($isPass) {
        return "### ✅ $AgentTypeDisplay Policy Test Passed for ``$PolicyName```n" +
        "The $AgentType policy test completed successfully.`n`n" +
        "**Details:**`n$detailBlock" +
        "- **Test Result:** ✅ $testResult"
    }
    elseif ($isFail) {
        return "### ❌ $AgentTypeDisplay Policy Test FAILED for ``$PolicyName```n" +
        "> **The policy test did not pass.** Review the details and workflow log below.`n`n" +
        "**Details:**`n$detailBlock" +
        "- **Test Result:** ❌ $testResult"
    }
    elseif ($isError) {
        return "### 🔴 $AgentTypeDisplay Policy Test Errored for ``$PolicyName```n" +
        "> **The test did not complete.** An error occurred during execution — no pass/fail verdict was reached.`n`n" +
        "**Details:**`n$detailBlock" +
        "- **Test Result:** 🔴 $testResult"
    }
    else {
        $out = "### ℹ️ $AgentTypeDisplay Policy Test Completed for ``$PolicyName```n`n**Details:**`n$detailBlock"
        if ($testResult) { $out += "- **Test Result:** $testResult" }
        return $out
    }
}

# Normalises an agent-reported TestResult string to a stable evidence status.
function Get-EvidenceStatus {
    param([string]$TestResult)
    if ($TestResult -match '^(pass|success)') { return 'PASS' }
    if ($TestResult -match '^fail') { return 'FAIL' }
    if ($TestResult -match '^error') { return 'ERROR' }
    return 'UNKNOWN'
}

# Computes a stable SHA-256 hash of the canonical policy content for evidence and future dedup.
function Get-PolicyContentHash {
    param([string]$Content)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $hash = $sha.ComputeHash($bytes) } finally { $sha.Dispose() }
    return 'sha256:' + (([System.BitConverter]::ToString($hash)) -replace '-', '').ToLower()
}

# Orchestrates a complete test run for a single policy definition.
# Calls the agent, executes the script, reads the log, and formats results.
# Returns @{ ResultMarkdown = <string>; DebugMarkdown = <string>; Result = <string>; ContentHash = <string> }
function Invoke-PolicyTest {
    param(
        [object]$Policy,
        [int]$Index,
        [string]$AssistantId,
        [string]$AgentType,
        [string]$AgentTypeDisplay,
        [string]$JobId,
        [string]$BashMethod,
        [string]$RunLinkLine,
        [int]$MaxRetryAttempts
    )

    $policyName = if ($Policy.name) { $Policy.name } else { "Policy $Index" }
    $policyContent = $Policy | ConvertTo-Json -Depth 20 -Compress
    $contentHash = Get-PolicyContentHash -Content $policyContent

    Write-Host "Processing $AgentType policy ($Index): $policyName"
    Write-Host "Policy Content Retrieved:"
    Write-Host $policyContent

    $conversationId = $null
    try {
        Write-Host "Creating new conversation..."
        $conversation = New-MetroAIConversation
        $conversationId = $conversation.id
        if (-not $conversationId) { throw "Failed to create conversation" }
        Write-Host "Conversation created. ID: $conversationId"

        # ── Generate test script ────────────────────────────────────────────────
        $scriptResult = Invoke-AgentScript `
            -AgentId $AssistantId `
            -ConversationId $conversationId `
            -PolicyContent $policyContent `
            -AgentType $AgentType `
            -MaxAttempts $MaxRetryAttempts

        if (-not $scriptResult) {
            Write-Warning "No script generated for $policyName after $MaxRetryAttempts attempts"
            return @{
                ResultMarkdown = "### ⚠️ No bash script generated for ``$policyName``"
                DebugMarkdown  = "## Policy: $policyName`n`n**Effect:** $AgentType`n`n### Generated Script`n`n(none — agent did not produce a script after $MaxRetryAttempts attempts)"
                Result         = 'ERROR'
                ContentHash    = $contentHash
            }
        }

        $scriptContent = $scriptResult.Content
        $scriptLanguage = $scriptResult.Language
        $scriptExt = if ($scriptLanguage -eq 'powershell') { 'ps1' } else { 'sh' }
        $scriptPath = "./temp_$Index.$scriptExt"
        Set-Content -Path $scriptPath -Value $scriptContent -Encoding utf8

        Write-Host "$scriptLanguage script extracted for $policyName"
        Write-Host $scriptContent

        $debugEntry = "## Policy: $policyName`n`n**Effect:** $AgentType`n`n"
        $debugEntry += "### Generated $scriptLanguage Script`n`n``````$scriptLanguage`n$scriptContent`n``````"

        # ── Execute script ──────────────────────────────────────────────────────
        Write-Host "Executing $scriptLanguage script for $policyName..."
        try {
            $execution = Invoke-TestScript -ScriptPath $scriptPath -ScriptLanguage $scriptLanguage `
                -BashMethod $BashMethod -JobId $JobId
            $exitCode = $execution.ExitCode
            $scriptOutput = $execution.Output
        }
        catch {
            $errMsg = $_.Exception.Message
            Write-Error "Failed to execute $scriptLanguage script: $errMsg"
            $debugEntry += "`n`n### Execution Error`n`n``````$errMsg``````"
            Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue
            return @{
                ResultMarkdown = "### ❌ Failed to execute $scriptLanguage script for ``$policyName``: $errMsg"
                DebugMarkdown  = $debugEntry
                Result         = 'ERROR'
                ContentHash    = $contentHash
            }
        }

        # Append truncated runtime output to debug (last 8 000 chars to avoid overflow)
        if ($scriptOutput) {
            $truncated = if ($scriptOutput.Length -gt 8000) {
                "[... truncated — showing last 8000 chars ...`n" + $scriptOutput.Substring($scriptOutput.Length - 8000)
            }
            else { $scriptOutput }
            $debugEntry += "`n`n### Script Runtime Output (stdout+stderr)`n`n``````$truncated``````"
        }
        $debugEntry += "`n`n### Exit Code: $exitCode"

        Remove-Item $scriptPath -Force -ErrorAction SilentlyContinue

        # ── Read test log ───────────────────────────────────────────────────────
        Write-Host "Checking for test results for $policyName"
        $log = Read-TestLog

        $resultStatus = 'UNKNOWN'
        $resultMarkdown = switch ($log.Error) {
            "not-found" {
                $debugEntry += "`n`n### logging.json`n`n(file not written — script aborted before cleanup trap)"
                $resultStatus = 'ERROR'
                $r = "### 🔴 $AgentTypeDisplay Policy Test Errored for ``$policyName`` — no result file`n"
                $r += "> **The test did not complete.** The bash script aborted before writing results.`n`n"
                if ($RunLinkLine) { $r += "$RunLinkLine`n" }
                $r
            }
            "empty" {
                $debugEntry += "`n`n### logging.json`n`n(file exists but is empty — jq compile errors or cleanup trap failure)`n`n### Exit Code: $exitCode"
                $resultStatus = 'ERROR'
                $r = "### 🔴 $AgentTypeDisplay Policy Test Errored for ``$policyName```n"
                $r += "> **The test did not complete.** The cleanup script ran but wrote no results. Check the workflow log for details.`n`n"
                if ($RunLinkLine) { $r += "$RunLinkLine`n" }
                $r
            }
            { $_ -and $_.StartsWith("parse-failed") } {
                Write-Host "Failed to parse logging.json for $policyName. Raw: $($log.RawJson)"
                $debugEntry += "`n`n### logging.json`n`n``````json`n$($log.RawJson)`n``````"
                $resultStatus = 'ERROR'
                "### ❌ Failed to parse logging.json for ``$policyName``: $($log.Error)"
            }
            default {
                Write-Host "Raw logging.json content:"
                Write-Host $log.RawJson
                $debugEntry += "`n`n### logging.json`n`n``````json`n$($log.RawJson)`n``````"

                if ($null -eq $log.Data) {
                    $resultStatus = 'ERROR'
                    $r = "### 🔴 $AgentTypeDisplay Policy Test Errored for ``$policyName`` — null response`n"
                    $r += "> **The test did not complete.** logging.json was empty or unparseable.`n`n"
                    if ($RunLinkLine) { $r += "$RunLinkLine`n" }
                    $r
                }
                else {
                    $trProp = $log.Data.PSObject.Properties | Where-Object { $_.Name -ieq 'testresult' } | Select-Object -First 1
                    $resultStatus = Get-EvidenceStatus ([string]($trProp.Value))
                    Format-PolicyResult `
                        -LogData $log.Data `
                        -PolicyName $policyName `
                        -AgentTypeDisplay $AgentTypeDisplay `
                        -AgentType $AgentType `
                        -RunLinkLine $RunLinkLine
                }
            }
        }

        return @{ ResultMarkdown = $resultMarkdown; DebugMarkdown = $debugEntry; Result = $resultStatus; ContentHash = $contentHash }

    }
    catch {
        Write-Error "Error processing $policyName : $($_.Exception.Message)"
        return @{
            ResultMarkdown = "### ❌ Error processing ``$policyName``: $($_.Exception.Message)"
            DebugMarkdown  = "## Policy: $policyName`n`n**Effect:** $AgentType`n`n### Error`n`n$($_.Exception.Message)"
            Result         = 'ERROR'
            ContentHash    = $contentHash
        }
    }
    finally {
        if ($conversationId) {
            Remove-MetroAIConversation -ConversationId $conversationId -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
}

# ── Initialisation ─────────────────────────────────────────────────────────────

$PoliciesJson = Get-Content -Path './allPolicyContents.json' -Raw
$AllPolicies = $PoliciesJson | ConvertFrom-Json

Write-Host "🔧 Azure CLI Policy Test Script - All Policy Types"
Write-Host "Agent Type: $AgentType"
Write-Host "Number of policies to process: $($AllPolicies.Count)"
Write-Host "Job ID for cleanup tracking: $JobId"

$bashEnv = Test-BashEnvironment
if (-not $bashEnv.Available) {
    Write-Error "❌ This script requires WSL or bash to execute Azure CLI scripts."
    exit 1
}

Set-MetroAIContext -Endpoint $Endpoint -ApiType Agent -SkipValidation

try {
    $agent = Get-MetroAIAgent -AgentId $AssistantId -ErrorAction Stop
    if ($agent) {
        Write-Host "Agent '$AssistantId' confirmed accessible."
    }
    else {
        Write-Warning "Agent '$AssistantId' not found — it may still be reachable via the Conversations API."
    }
}
catch {
    Write-Warning "Could not verify agent '$AssistantId' (GET returned: $($_.Exception.Message)). Proceeding."
}

$agentTypeDisplay = switch ($AgentType) {
    "deny" { "Deny" }
    "audit" { "Audit" }
    "dine" { "DINE" }
    "modify" { "Modify" }
    default { (Get-Culture).TextInfo.ToTitleCase($AgentType) }
}

$runLinkLine = if (-not [string]::IsNullOrEmpty($WorkflowRunUrl)) {
    "- **Workflow Run:** [View full log]($WorkflowRunUrl)"
}
else { "" }

# ── Main loop ──────────────────────────────────────────────────────────────────

$AllResults = @()
$AllDebugOutput = @()
$AllEvidence = @()
$processedFiles = 0
$errorCount = 0

foreach ($policy in $AllPolicies) {
    $processedFiles++
    $outcome = Invoke-PolicyTest `
        -Policy           $policy `
        -Index            $processedFiles `
        -AssistantId      $AssistantId `
        -AgentType        $AgentType `
        -AgentTypeDisplay $agentTypeDisplay `
        -JobId            $JobId `
        -BashMethod       $bashEnv.Method `
        -RunLinkLine      $runLinkLine `
        -MaxRetryAttempts $MaxRetryAttempts

    $AllResults += $outcome.ResultMarkdown
    $AllDebugOutput += $outcome.DebugMarkdown
    if ($outcome.Result -eq 'ERROR') { $errorCount++ }

    $policyNameForEvidence = if ($policy.name) { $policy.name } else { "Policy $processedFiles" }
    $AllEvidence += [ordered]@{
        timestamp   = (Get-Date).ToUniversalTime().ToString('o')
        policyName  = $policyNameForEvidence
        effect      = $AgentType
        result      = $outcome.Result
        contentHash = $outcome.ContentHash
        runUrl      = $WorkflowRunUrl
        agent       = "$agentTypeDisplay Policy Agent"
    }
}

# ── Write output artifacts ─────────────────────────────────────────────────────

$summaryHeader = "## Azure Policy Test Results (Azure CLI - $agentTypeDisplay Agent)`n`n"
$summaryHeader += "Summary: Processed $processedFiles $AgentType policy definition(s) using Azure CLI bash scripts`n`n"
($summaryHeader + ($AllResults -join "`n`n---`n`n")) | Out-File -FilePath $ResultPath -Encoding utf8

$debugHeader = "# Debug Output — $agentTypeDisplay Agent ($processedFiles policies)`n`n"
$debugHeader += "*Generated scripts, exit codes, and raw logging.json for each policy tested in this run.*`n`n---`n`n"
($debugHeader + ($AllDebugOutput -join "`n`n---`n`n")) | Out-File -FilePath $DebugPath -Encoding utf8

Write-Host "Results written to $ResultPath"

# Emit one Markdown evidence table per policy job for the evidence-log.md update step.
if ($AllEvidence.Count -gt 0) {
    $evidenceTable = [System.Text.StringBuilder]::new()
    [void]$evidenceTable.AppendLine("| Policy | Effect | Result | Last Tested (UTC) | PR | Commit | Content Hash | Evidence |")
    [void]$evidenceTable.AppendLine("|--------|--------|--------|-------------------|----|--------|--------------|----------|")
    foreach ($evidence in $AllEvidence) {
        $evidenceLink = if ($evidence.runUrl) { "[log]($($evidence.runUrl))" } else { "-" }
        [void]$evidenceTable.AppendLine("| $($evidence.policyName) | $($evidence.effect) | $($evidence.result) | $($evidence.timestamp) | - | - | $($evidence.contentHash) | $evidenceLink |")
    }

    Set-Content -Path $EvidencePath -Value $evidenceTable.ToString() -Encoding utf8
    Write-Host "Evidence written to $EvidencePath ($($AllEvidence.Count) record(s))"
}

# Fail the job when any policy errored (no script generated, execution failure, or no
# result file) rather than exiting 0 — an ERROR result means the policy was never
# actually tested and must not be reported as a passing job.
if ($errorCount -gt 0) {
    Write-Error "$errorCount of $processedFiles $AgentType polic$(if ($processedFiles -eq 1) { 'y' } else { 'ies' }) errored during testing"
    exit 1
}
