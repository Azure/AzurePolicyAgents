<#
.SYNOPSIS
    Post-test self-improvement: proposes and applies patches to agent instruction files.

.DESCRIPTION
    After a policy test run completes, calls the InstructionsAgent once per agent type (deny, audit,
    dine, modify) with that agent's current instructions, RESULT.md/DEBUG.md test artifacts, and a
    workflow log snippet. If the agent responds with changes_required, applies the returned patches
    to agentInstructions/*.md by exact old_content match. Falls back to a two-turn conversation when
    the estimated prompt would be too large for a single turn. See docs/Scripts-Reference.md for the
    full flow.

.PARAMETER Endpoint
    Azure AI Foundry project endpoint.

.PARAMETER AssistantId
    Identifier of the InstructionsAgent to call.

.PARAMETER ArtifactsPath
    Directory containing downloaded RESULT.md / DEBUG.md test artifacts.

.PARAMETER AgentInstructionsPath
    Directory containing the agentInstructions/*.md files that may be patched.

.PARAMETER WorkflowLogPath
    Path to a captured workflow run log, included as extra context.

.PARAMETER RunId
    Workflow run identifier, used only for the maintenance summary text.

.PARAMETER MaxLogChars
    Maximum characters of the workflow log to include in the prompt (avoids token overflows).
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Endpoint,

    [Parameter(Mandatory = $true)]
    [string]$AssistantId,

    [Parameter(Mandatory = $false)]
    [string]$ArtifactsPath = "./maintenance-results",

    [Parameter(Mandatory = $false)]
    [string]$AgentInstructionsPath = "./agentInstructions",

    [Parameter(Mandatory = $false)]
    [string]$WorkflowLogPath = "./run-logs.txt",

    [Parameter(Mandatory = $false)]
    [string]$RunId = "",

    # Maximum characters of workflow log to include in the prompt (avoids token overflows)
    [Parameter(Mandatory = $false)]
    [int]$MaxLogChars = 40000
)

# ── Helper functions ───────────────────────────────────────────────────────────

# Reads all agent instruction .md files from disk.
# Returns a hashtable keyed by agent type (e.g. "audit" → file contents).
function Read-InstructionFiles {
    param(
        [string]$Path,
        [string[]]$AgentTypes
    )
    $result = @{}
    foreach ($type in $AgentTypes) {
        $filePath = Join-Path $Path "${type}PolicyAgent.md"
        if (Test-Path $filePath) {
            $result[$type] = Get-Content $filePath -Raw
            Write-Host "Read instructions for $type agent ($((Get-Item $filePath).Length) bytes)"
        }
        else {
            Write-Warning "Instruction file not found: $filePath"
            $result[$type] = "(file not found)"
        }
    }
    return $result
}

# Reads RESULT.md and DEBUG.md artifacts from the download path.
# Artifact directories are named test-results-{index}-{agentType}-{policy-slug}.
# Multiple policies of the same effect are concatenated under that effect.
# Returns a hashtable:  @{ Results = @{ type→text }; Debug = @{ type→text } }
function Read-ArtifactFiles {
    param(
        [string]$ArtifactsPath,
        [string[]]$AgentTypes,
        [int]$MaxDebugChars = 20000
    )
    $results = @{}
    $debugs = @{}

    foreach ($type in $AgentTypes) {
        $results[$type] = "(no results found for $type)"
        $debugs[$type] = "(no debug found for $type)"
    }

    if (-not (Test-Path $ArtifactsPath)) {
        Write-Warning "Artifacts path not found: $ArtifactsPath"
        return @{ Results = $results; Debug = $debugs }
    }

    # Resolves the agent type from the artifact directory name produced by the workflow.
    function Get-ArtifactAgentType {
        param([System.IO.FileInfo]$File, [string[]]$KnownTypes)
        $dir = $File.Directory
        while ($dir) {
            if ($dir.Name -match '^test-results-\d+-(?<type>[a-z]+)-') {
                $candidate = $Matches['type']
                if ($KnownTypes -contains $candidate) { return $candidate }
            }
            $dir = $dir.Parent
        }
        return ($KnownTypes | Where-Object { $File.FullName -match $_ } | Select-Object -First 1)
    }

    $resultFiles = Get-ChildItem -Path $ArtifactsPath -Recurse -Filter "RESULT.md" | Sort-Object FullName
    $debugFiles = Get-ChildItem -Path $ArtifactsPath -Recurse -Filter "DEBUG.md"  | Sort-Object FullName

    $resultBuckets = @{}
    $debugBuckets = @{}

    foreach ($file in $resultFiles) {
        $matchedType = Get-ArtifactAgentType -File $file -KnownTypes $AgentTypes
        if ($matchedType) {
            if (-not $resultBuckets.ContainsKey($matchedType)) { $resultBuckets[$matchedType] = @() }
            $resultBuckets[$matchedType] += (Get-Content $file.FullName -Raw)
        }
    }

    foreach ($file in $debugFiles) {
        $matchedType = Get-ArtifactAgentType -File $file -KnownTypes $AgentTypes
        if ($matchedType) {
            if (-not $debugBuckets.ContainsKey($matchedType)) { $debugBuckets[$matchedType] = @() }
            $debugBuckets[$matchedType] += (Get-Content $file.FullName -Raw)
        }
    }

    foreach ($type in $resultBuckets.Keys) {
        $results[$type] = ($resultBuckets[$type] -join "`n`n---`n`n")
    }

    foreach ($type in $debugBuckets.Keys) {
        $raw = ($debugBuckets[$type] -join "`n`n---`n`n")
        $debugs[$type] = if ($raw.Length -gt $MaxDebugChars) {
            $raw.Substring(0, $MaxDebugChars) + "`n...[debug truncated at $MaxDebugChars chars]"
        }
        else { $raw }
    }

    Write-Host "Read $($resultFiles.Count) RESULT.md and $($debugFiles.Count) DEBUG.md artifact(s)"
    return @{ Results = $results; Debug = $debugs }
}

# Reads the workflow run log file and truncates it to a safe size.
# Returns the log text as a string.
function Read-WorkflowLog {
    param(
        [string]$LogPath,
        [int]$MaxChars
    )
    if (-not (Test-Path $LogPath)) {
        Write-Warning "Workflow log not found: $LogPath"
        return "(workflow log not available)"
    }
    $raw = Get-Content $LogPath -Raw
    $text = if ($raw.Length -gt $MaxChars) {
        $raw.Substring(0, $MaxChars) + "`n...[log truncated at $MaxChars chars]"
    }
    else { $raw }
    Write-Host "Workflow log included: $($text.Length) chars (raw: $($raw.Length))"
    return $text
}

# Calls the InstructionsAgent for a single agent type using a one- or two-turn conversation.
# Two turns are used when the estimated single-turn prompt would exceed $MaxSingleTurnChars,
# keeping each individual message within the 100s HttpClient.Timeout window.
# Returns the final response text from the agent, or $null on failure.
function Invoke-AgentMaintenance {
    param(
        [string]$AssistantId,
        [string]$ConversationId,
        [string]$AgentType,
        [string]$InstructionsText,
        [string]$ResultText,
        [string]$DebugText,
        [string]$LogSnippet,
        [int]$MaxSingleTurnChars = 30000
    )

    $singleTurnSize = $InstructionsText.Length + $ResultText.Length +
    $DebugText.Length + $LogSnippet.Length + 500
    $useTwoTurns = $singleTurnSize -gt $MaxSingleTurnChars

    Write-Host "Estimated prompt size for $AgentType : $singleTurnSize chars$(
        if ($useTwoTurns) { ' — using two-turn conversation' })" -ForegroundColor Gray

    if ($useTwoTurns) {
        $turn1Prompt = @"
## Current ${AgentType}PolicyAgent.md Instructions
$InstructionsText

---

## Test Results for $AgentType Agent
$ResultText

---

## Workflow Log Snippet
$LogSnippet

---

Analyze the instructions and test results above for the $AgentType policy agent only.
Identify what failed and what aspects of the instructions may need improvement.
Do NOT propose patches yet — just provide your analysis. The debug output will follow in the next message.
"@
        Write-Host "Turn 1 prompt for $AgentType : $($turn1Prompt.Length) chars" -ForegroundColor Gray
        $turn1 = Invoke-MetroAIConversation -AgentId $AssistantId -ConversationId $ConversationId -UserInput $turn1Prompt -AutoApprove
        Write-Host "Turn 1 response for $AgentType ($($turn1.AssistantText.Length) chars)"

        $turn2Prompt = @"
## Debug Output for $AgentType Agent (Generated Scripts + logging.json)
$DebugText

---

Using your analysis from the previous message and the debug evidence above, now propose your patches in the required JSON format. If no changes are needed, confirm that.
"@
        Write-Host "Turn 2 prompt for $AgentType : $($turn2Prompt.Length) chars" -ForegroundColor Gray
        $turn2 = Invoke-MetroAIConversation -AgentId $AssistantId -ConversationId $ConversationId -UserInput $turn2Prompt -AutoApprove
        return $turn2.AssistantText
    }
    else {
        $prompt = @"
## Current ${AgentType}PolicyAgent.md Instructions
$InstructionsText

---

## Test Results for $AgentType Agent
$ResultText

---

## Debug Output for $AgentType Agent (Generated Scripts + logging.json)
$DebugText

---

## Workflow Log Snippet
$LogSnippet

---

Analyze the above data for the $AgentType policy agent only. If the instructions need improvement based on the evidence, respond with your patches in the required JSON format. If no changes are needed, confirm that.
"@
        Write-Host "Single-turn prompt for $AgentType : $($prompt.Length) chars" -ForegroundColor Gray
        $turn = Invoke-MetroAIConversation -AgentId $AssistantId -ConversationId $ConversationId -UserInput $prompt -AutoApprove
        return $turn.AssistantText
    }
}

# Scans proposed patch content for credential-like values before it is written to disk.
# Returns the name of the first matched rule, or $null when the content is clean.
# Obvious placeholders (FAKE, PLACEHOLDER, REPLACE, EXAMPLE, REDACTED, DUMMY, xxxx) are allowed.
function Get-SecretMatch {
    param([string]$Content)

    if ([string]::IsNullOrWhiteSpace($Content)) { return $null }

    $placeholderPattern = '(?i)(FAKE|PLACEHOLDER|REPLACE|EXAMPLE|REDACTED|DUMMY|SAMPLE|NOT[_-]?A[_-]?REAL|x{4,})'

    $rules = @(
        @{ Name = 'hex-secret-32-plus'; Pattern = '(?<![0-9a-fA-F])[0-9a-fA-F]{32,}(?![0-9a-fA-F])' }
        @{ Name = 'assigned-credential'; Pattern = '(?i)(api[_-]?key|secret|password|pwd|passwd|token|client[_-]?secret|access[_-]?key|connection[_-]?string|sas[_-]?token)\s*["'']?\s*[:=]\s*["'']?[^\s"'']{12,}' }
        @{ Name = 'azure-storage-key'; Pattern = '(?i)AccountKey\s*=\s*[A-Za-z0-9+/]{40,}={0,2}' }
        @{ Name = 'jwt-token'; Pattern = 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}' }
        @{ Name = 'aws-access-key'; Pattern = '(?<![A-Z0-9])AKIA[0-9A-Z]{16}(?![A-Z0-9])' }
    )

    foreach ($rule in $rules) {
        $m = [regex]::Match($Content, $rule.Pattern)
        if ($m.Success) {
            $window = $Content.Substring([Math]::Max(0, $m.Index - 40), [Math]::Min($Content.Length - [Math]::Max(0, $m.Index - 40), $m.Length + 80))
            if ($window -notmatch $placeholderPattern) {
                return $rule.Name
            }
        }
    }

    return $null
}

# Parses a JSON patch response from the agent and applies each patch to the instruction files.
# Returns @{ Changed = bool; SummaryLines = string[]; AnalysisLine = string }
function Invoke-PatchResponse {
    param(
        [string]$ResponseText,
        [string]$AgentType,
        [string]$InstructionsPath
    )

    $summaryLines = @()
    $analysisLine = ""
    $changed = $false

    # Extract JSON from fenced block or bare object
    $jsonMatch = [regex]::Match($ResponseText, '(?s)```json\s*\n(.*?)\n```')
    if (-not $jsonMatch.Success) {
        $jsonMatch = [regex]::Match($ResponseText, '(?s)(\{.*"changes_required".*\})')
    }

    if (-not $jsonMatch.Success) {
        Write-Warning "No JSON code block found in $AgentType agent response"
        $summaryLines += "- ⚠️ **${AgentType}PolicyAgent.md**: Agent did not return parseable JSON"
        $analysisLine = "**${AgentType}**: $ResponseText"
        return @{ Changed = $changed; SummaryLines = $summaryLines; AnalysisLine = $analysisLine }
    }

    try {
        $patchData = $jsonMatch.Groups[1].Value | ConvertFrom-Json
        $analysisLine = "**${AgentType}**: $($patchData.analysis)"

        if (-not ($patchData.changes_required -and $patchData.patches.Count -gt 0)) {
            Write-Host "No changes required for $AgentType agent." -ForegroundColor Green
            $summaryLines += "- ℹ️ **${AgentType}PolicyAgent.md**: No changes required"
            return @{ Changed = $changed; SummaryLines = $summaryLines; AnalysisLine = $analysisLine }
        }

        Write-Host "$($patchData.patches.Count) patch(es) proposed for $AgentType" -ForegroundColor Yellow

        foreach ($patch in $patchData.patches) {
            $targetFile = Join-Path $InstructionsPath $patch.file

            if (-not (Test-Path $targetFile)) {
                Write-Warning "Patch target not found: $targetFile — skipping"
                $summaryLines += "- ⚠️ **$($patch.file)**: Target file not found — skipped"
                continue
            }

            $secretRule = Get-SecretMatch -Content $patch.new_content
            if ($secretRule) {
                Write-Warning "Rejected patch to $($patch.file): new_content matched secret rule '$secretRule'. Reason: $($patch.reason)"
                $summaryLines += "- 🔒 **$($patch.file)**: Patch rejected by secret guard (rule: $secretRule). Use an obvious non-secret placeholder."
                continue
            }

            $current = Get-Content $targetFile -Raw
            $normCurrent = $current -replace "`r`n", "`n"
            $normOld = $patch.old_content -replace "`r`n", "`n"

            if ($normCurrent.Contains($normOld)) {
                $newContent = $normCurrent.Replace($normOld, ($patch.new_content -replace "`r`n", "`n"))

                if ($newContent -ne $normCurrent) {
                    Set-Content $targetFile -Value $newContent -Encoding utf8 -NoNewline
                    Write-Host "✅ Patched $($patch.file): $($patch.reason)" -ForegroundColor Green
                    $summaryLines += "- ✅ **$($patch.file)**: $($patch.reason)"
                    $changed = $true
                }
                else {
                    Write-Host "ℹ️ No-op patch for $($patch.file): replacement already present" -ForegroundColor DarkYellow
                    $summaryLines += "- ℹ️ **$($patch.file)**: No-op patch skipped — replacement already present"
                }
            }
            else {
                Write-Warning "Could not apply patch to $($patch.file) — old_content not found exactly. Reason: $($patch.reason)"
                $summaryLines += "- ⚠️ **$($patch.file)**: Patch not applied (old_content mismatch) — $($patch.reason)"
            }
        }
    }
    catch {
        Write-Warning "Failed to parse patch JSON for ${AgentType}: $($_.Exception.Message)"
        $summaryLines += "- ❌ **${AgentType}PolicyAgent.md**: Failed to parse response — $($_.Exception.Message)"
    }

    return @{ Changed = $changed; SummaryLines = $summaryLines; AnalysisLine = $analysisLine }
}

# Orchestrates a full maintenance cycle for one agent type:
# creates a conversation, calls the agent, applies patches, and cleans up.
# Returns @{ Changed = bool; SummaryLines = string[]; AnalysisLine = string }
function Invoke-AgentTypeMaintenance {
    param(
        [string]$AssistantId,
        [string]$AgentType,
        [string]$InstructionsText,
        [string]$ResultText,
        [string]$DebugText,
        [string]$LogSnippet,
        [string]$InstructionsPath,
        [int]$MaxSingleTurnChars
    )

    Write-Host "`n--- Analysing $AgentType agent ---" -ForegroundColor Cyan

    $conversationId = $null
    try {
        $conversation = New-MetroAIConversation
        $conversationId = $conversation.id
        Write-Host "Conversation created for $AgentType : $conversationId"

        $responseText = Invoke-AgentMaintenance `
            -AssistantId       $AssistantId `
            -ConversationId    $conversationId `
            -AgentType         $AgentType `
            -InstructionsText  $InstructionsText `
            -ResultText        $ResultText `
            -DebugText         $DebugText `
            -LogSnippet        $LogSnippet `
            -MaxSingleTurnChars $MaxSingleTurnChars

        Write-Host "Response received for $AgentType ($($responseText.Length) chars)"

        return Invoke-PatchResponse `
            -ResponseText    $responseText `
            -AgentType       $AgentType `
            -InstructionsPath $InstructionsPath

    }
    catch {
        Write-Warning "Agent call failed for ${AgentType}: $($_.Exception.Message)"
        return @{
            Changed      = $false
            SummaryLines = @("- ❌ **${AgentType}PolicyAgent.md**: Agent call failed — $($_.Exception.Message)")
            AnalysisLine = "**${AgentType}**: Call failed — $($_.Exception.Message)"
        }
    }
    finally {
        if ($conversationId) {
            Remove-MetroAIConversation -ConversationId $conversationId -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
}

# ── Initialisation ─────────────────────────────────────────────────────────────

Write-Host "=== Policy Agent Instructions Maintenance ===" -ForegroundColor Green
Write-Host "Endpoint: $Endpoint"
Write-Host "AssistantId: $AssistantId"
Write-Host "ArtifactsPath: $ArtifactsPath"
Write-Host "AgentInstructionsPath: $AgentInstructionsPath"

Write-Host "Installing Metro.AI PowerShell module..." -ForegroundColor Cyan
Install-PSResource -Name Metro.AI -TrustRepository -Scope CurrentUser -ErrorAction SilentlyContinue
Install-Module Metro.AI -Force -AllowClobber -ErrorAction SilentlyContinue

Set-MetroAIContext -Endpoint $Endpoint -ApiType Agent -SkipValidation

$agentTypes = @("audit", "deny", "dine", "modify")
$instructionsContent = Read-InstructionFiles -Path $AgentInstructionsPath -AgentTypes $agentTypes
$artifacts = Read-ArtifactFiles   -ArtifactsPath $ArtifactsPath -AgentTypes $agentTypes
$workflowLogText = Read-WorkflowLog     -LogPath $WorkflowLogPath -MaxChars $MaxLogChars

# Brief log snippet included in each agent call (full log is too large)
$logSnippet = if ($workflowLogText.Length -gt 3000) {
    $workflowLogText.Substring(0, 3000) + "`n...[log snippet truncated]"
}
else { $workflowLogText }

# ── Per-agent maintenance loop ─────────────────────────────────────────────────

$changesMade = $false
$allPatchSummary = @()
$allAnalysisLines = @()
$maxSingleTurnChars = 30000

foreach ($type in $agentTypes) {
    $outcome = Invoke-AgentTypeMaintenance `
        -AssistantId        $AssistantId `
        -AgentType          $type `
        -InstructionsText   $instructionsContent[$type] `
        -ResultText         $artifacts.Results[$type] `
        -DebugText          $artifacts.Debug[$type] `
        -LogSnippet         $logSnippet `
        -InstructionsPath   $AgentInstructionsPath `
        -MaxSingleTurnChars $maxSingleTurnChars

    if ($outcome.Changed) { $changesMade = $true }
    $allPatchSummary += $outcome.SummaryLines
    $allAnalysisLines += $outcome.AnalysisLine
}

# ── Write maintenance summary ──────────────────────────────────────────────────

$analysisSummary = if ($allAnalysisLines.Count -gt 0) { $allAnalysisLines -join "`n`n" } else { "No analysis returned." }
$runRef = if ($RunId) { "run #$RunId" } else { "this run" }

@"
## 🤖 Agent Instructions Maintenance Report

Triggered by $runRef.

### Analysis
$analysisSummary

### Patches Applied
$($allPatchSummary -join "`n")
"@ | Out-File -FilePath "./maintenance-summary.md" -Encoding utf8

Write-Host "Summary written to maintenance-summary.md"

# ── Set CI output (changes-made) ──────────────────────────────────────────────

$changesStr = if ($changesMade) { "true" } else { "false" }
if ($env:TF_BUILD -eq 'True') {
    Write-Host "##vso[task.setvariable variable=changesMade;isOutput=true]$changesStr"
}
elseif ($env:GITHUB_ACTIONS -eq 'true') {
    "changes-made=$changesStr" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
}
Write-Host "changes-made=$changesStr"
