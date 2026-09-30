<#
.SYNOPSIS
    Validates policy definition JSON files and groups them into a per-effect test matrix.

.DESCRIPTION
    Checks every changed policyDefinitions/*.json file for structural correctness (required keys,
    the 'parameterss' typo, undefined parameter references, effect-specific 'details' requirements),
    resolves each policy's effect and specialised agent type, and emits a per-policy job matrix so
    PolicyAgent can test each policy in its own parallel job. Exits 1 on any validation failure,
    blocking the pull request. See docs/Scripts-Reference.md for the full flow and output schema.

.PARAMETER JsonFiles
    Space- or comma-separated list of policyDefinitions/*.json paths to validate.

.PARAMETER JsonFilesCount
    Count of files in JsonFiles. "0" (or an empty JsonFiles) short-circuits with no validation.

.PARAMETER EvidenceFiles
    Paths to durable evidence-log.md files. When supplied, a policy whose exact content hash has a
    latest PASS record is still validated but skipped from agent testing.

.PARAMETER ForceRetest
    When $true, disables evidence-based test skipping so every valid policy is always tested.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$JsonFiles,

    [Parameter(Mandatory = $true)]
    [string]$JsonFilesCount,

    [Parameter()]
    [string[]]$EvidenceFiles = @(),

    [Parameter()]
    [bool]$ForceRetest = $false
)

# ── CI-agnostic helpers ───────────────────────────────────────────────────────
function Set-CIOutput {
    param([string]$Name, [string]$Value)
    if ($env:TF_BUILD -eq 'True') {
        # Azure DevOps: emit logging command so the value survives across jobs/stages
        Write-Host "##vso[task.setvariable variable=$Name;isOutput=true]$Value"
    }
    elseif ($env:GITHUB_ACTIONS -eq 'true') {
        "$Name=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
    }
}

function Write-CIStepSummary {
    param([string]$Content)
    if ($env:GITHUB_ACTIONS -eq 'true' -and $env:GITHUB_STEP_SUMMARY) {
        $Content | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
    }
}

Write-Host "=== Azure Policy Validation and Grouping ===" -ForegroundColor Green
Write-Host "JSON files to validate: $JsonFiles"
Write-Host "Number of JSON files: $JsonFilesCount"

if ([string]::IsNullOrWhiteSpace($JsonFiles) -or $JsonFilesCount -eq "0") {
    Write-Warning "No JSON files found in the 'policyDefinitions' directory"
    Set-CIOutput "processedFilesCount" "0"
    exit 0
}

# Handle both comma and space separated file lists
$JsonFilesList = if ($JsonFiles -match ",") {
    # Comma-separated (from workflow_dispatch)
    $JsonFiles -split "," | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}
else {
    # Space-separated (from pull request)
    $JsonFiles -split " " | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}
# Deduplicate — prevents the same file being tested twice if it appears more than once
$JsonFilesList = $JsonFilesList | Select-Object -Unique

Write-Host "Processing $($JsonFilesList.Count) policy files for validation:"
$JsonFilesList | ForEach-Object { Write-Host "  - $_" }

# GitHub Actions caps a matrix at 256 jobs. One job is generated per valid policy.
$MaxMatrixJobs = 256

# Builds a filesystem and artifact safe slug that is unique per policy in the run.
function Get-PolicySlug {
    param([int]$Index, [string]$AgentType, [string]$PolicyName)

    $sanitised = ($PolicyName.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
    if ([string]::IsNullOrWhiteSpace($sanitised)) { $sanitised = 'policy' }

    $slug = '{0:d2}-{1}-{2}' -f $Index, $AgentType, $sanitised
    if ($slug.Length -gt 60) { $slug = $slug.Substring(0, 60).TrimEnd('-') }
    return $slug
}

function Get-PolicyContentHash {
    param([object]$Policy)

    $canonical = $Policy | ConvertTo-Json -Depth 20 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($canonical)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
    }
    finally {
        $sha.Dispose()
    }
    return 'sha256:' + (([System.BitConverter]::ToString($hash)) -replace '-', '').ToLower()
}

function Get-EvidenceKey {
    param([string]$PolicyFile, [string]$ContentHash)

    $normalisedPath = ($PolicyFile -replace '\\', '/').Trim()
    return "$normalisedPath|$($ContentHash.ToLower())"
}

function Get-PolicyContentHashFromCommit {
    param([string]$CommitSha, [string]$PolicyFile)

    if ([string]::IsNullOrWhiteSpace($CommitSha) -or
        [string]::IsNullOrWhiteSpace($PolicyFile) -or
        $CommitSha -eq '-') {
        return ''
    }

    try {
        $content = git show "$CommitSha`:$PolicyFile" 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($content)) {
            return ''
        }

        return Get-PolicyContentHash -Policy ($content | ConvertFrom-Json -ErrorAction Stop)
    }
    catch {
        Write-Warning "Could not calculate the evidence hash for '$PolicyFile' at '$CommitSha': $($_.Exception.Message)"
        return ''
    }
}

function Get-LatestEvidence {
    param([string[]]$Paths)

    $latest = @{}
    foreach ($path in @($Paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        if (-not (Test-Path $path)) {
            Write-Host "Evidence file not found, continuing: $path"
            continue
        }

        $records = @()
        foreach ($line in Get-Content -Path $path) {
            if ($line -notmatch '^\|.+\|$' -or
                $line -match '^\|\s*-+' -or
                $line -match '^\|\s*Policy\s*\|') {
                continue
            }

            $columns = $line.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
            if ($columns.Count -lt 7) { continue }

            $policyName = $columns[0]
            $policyFile = ''
            if ($policyName -match '^\[(?<name>.+)\]\((?<path>.+)\)$') {
                $policyName = $Matches.name
                $policyFile = $Matches.path
            }

            $hasContentHash = $columns.Count -ge 8
            $commitSha = $columns[5]
            $contentHash = if ($hasContentHash) {
                $columns[6]
            }
            else {
                Get-PolicyContentHashFromCommit -CommitSha $commitSha -PolicyFile $policyFile
            }
            $runUrlColumn = if ($hasContentHash) { 7 } else { 6 }
            $runUrl = ''
            if ($columns[$runUrlColumn] -match '^\[log\]\((?<url>.+)\)$') {
                $runUrl = $Matches.url
            }

            $records += [pscustomobject]@{
                policyName  = $policyName
                policyFile  = $policyFile
                effect      = $columns[1]
                result      = $columns[2]
                timestamp   = $columns[3]
                contentHash = $contentHash
                runUrl      = $runUrl
            }
        }

        foreach ($record in $records) {
            if ([string]::IsNullOrWhiteSpace([string]$record.policyFile) -or
                [string]::IsNullOrWhiteSpace([string]$record.contentHash)) {
                continue
            }

            $key = Get-EvidenceKey -PolicyFile ([string]$record.policyFile) -ContentHash ([string]$record.contentHash)
            $timestamp = [datetimeoffset]::MinValue
            if ($record.timestamp) {
                # ConvertFrom-Json coerces ISO strings to DateTime, so casting to string loses the zone.
                if ($record.timestamp -is [datetime]) {
                    $timestamp = [datetimeoffset]$record.timestamp
                }
                else {
                    [datetimeoffset]::TryParse([string]$record.timestamp, [ref]$timestamp) | Out-Null
                }
            }

            if (-not $latest.ContainsKey($key) -or $timestamp -ge $latest[$key].Timestamp) {
                $latest[$key] = @{
                    Record    = $record
                    Timestamp = $timestamp
                }
            }
        }
    }
    return $latest
}

$LatestEvidence = if ($ForceRetest) {
    Write-Host "Force retest enabled. Evidence-based test skipping is disabled."
    @{}
}
else {
    Get-LatestEvidence -Paths $EvidenceFiles
}

# Group policies by effect type
$DenyPolicies = @()
$AuditPolicies = @()
$DinePolicies = @()
$ModifyPolicies = @()
$ValidationResults = @()
$EvidenceSkippedPolicies = @()
$HasValidationErrors = $false

# One entry per valid policy, consumed as the PolicyAgent job matrix so every policy is
# tested in its own job by its own ephemeral agent.
$PolicyMatrix = @()

foreach ($JsonFile in $JsonFilesList) {
    Write-Host "`n📋 Validating policy file: $JsonFile" -ForegroundColor Cyan

    try {
        # 1. Test JSON syntax
        Write-Host "  ➤ Checking JSON syntax..." -ForegroundColor Yellow
        $PolicyContent = Get-Content -Path $JsonFile -Raw
        $PolicyJson = $PolicyContent | ConvertFrom-Json -ErrorAction Stop
        Write-Host "  ✅ JSON syntax is valid" -ForegroundColor Green

        # 2. Validate basic policy structure
        Write-Host "  ➤ Validating policy structure..." -ForegroundColor Yellow
        
        if (-not $PolicyJson.properties) {
            throw "Policy missing 'properties' section"
        }
        
        if (-not $PolicyJson.properties.policyRule) {
            throw "Policy missing 'policyRule' section"
        }
        
        if (-not $PolicyJson.properties.policyRule.if) {
            throw "Policy missing 'policyRule.if' condition"
        }
        
        if (-not $PolicyJson.properties.policyRule.then) {
            throw "Policy missing 'policyRule.then' effect"
        }

        # Validate parameters key is correctly spelled
        # PowerShell's ConvertFrom-Json silently accepts any key, so check the raw JSON
        if ($PolicyContent -match '"parameterss"') {
            throw "Policy has a typo in the top-level key: 'parameterss' should be 'parameters'"
        }
        
        Write-Host "  ✅ Policy structure is valid" -ForegroundColor Green

        # 3. Extract and validate effect type
        Write-Host "  ➤ Extracting policy effect..." -ForegroundColor Yellow
        $Effect = $null
        
        # Try to get effect from then.effect (can be direct value or parameter reference)
        if ($PolicyJson.properties.policyRule.then.effect) {
            $EffectValue = $PolicyJson.properties.policyRule.then.effect
            
            # If it's a parameter reference like "[parameters('effect')]"
            if ($EffectValue -match '\[parameters\([''"](\w+)[''"]\)\]') {
                $ParameterName = $Matches[1]
                Write-Host "  📋 Effect is parameterized: $ParameterName" -ForegroundColor Blue
                
                # Get default value from parameter definition
                if ($PolicyJson.properties.parameters -and $PolicyJson.properties.parameters.$ParameterName -and $PolicyJson.properties.parameters.$ParameterName.defaultValue) {
                    $Effect = $PolicyJson.properties.parameters.$ParameterName.defaultValue
                    Write-Host "  📋 Using default value: $Effect" -ForegroundColor Blue
                }
                else {
                    # If no default, try to infer from allowed values or use first allowed value
                    if ($PolicyJson.properties.parameters.$ParameterName.allowedValues) {
                        $Effect = $PolicyJson.properties.parameters.$ParameterName.allowedValues[0]
                        Write-Host "  📋 Using first allowed value: $Effect" -ForegroundColor Blue
                    }
                    else {
                        throw "Cannot determine effect type - parameter '$ParameterName' has no default or allowed values"
                    }
                }
            }
            else {
                # Direct effect value
                $Effect = $EffectValue
            }
        }
        else {
            throw "Cannot find effect in policy rule"
        }
        
        if ([string]::IsNullOrWhiteSpace($Effect)) {
            $Effect = "deny"
            Write-Warning "  ⚠️  No effect found, defaulting to 'deny'"
        }
        
        $Effect = $Effect.ToLower()
        Write-Host "  ✅ Policy effect: $Effect" -ForegroundColor Green

        # 4. Validate that all parameters referenced in policyRule exist in properties.parameters
        Write-Host "  ➤ Validating parameter references..." -ForegroundColor Yellow
        # Scope the check to the policyRule section only (not the whole file), and exclude
        # the ARM deployment template body. DINE policies embed an ARM template under
        # then.details.deployment.properties.template which has its own [parameters('x')]
        # scope — those are ARM template parameters, not policy parameters, and must not
        # be validated against properties.parameters.
        $policyRuleClone = $PolicyJson.properties.policyRule | ConvertTo-Json -Depth 100 | ConvertFrom-Json
        if ($policyRuleClone.then.details.deployment) {
            $policyRuleClone.then.details.deployment.properties.template = $null
        }
        $policyRuleContent = $policyRuleClone | ConvertTo-Json -Depth 100
        $referencedParams = [regex]::Matches($policyRuleContent, "\[parameters\('([^']+)'\)\]") |
        ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        if ($referencedParams.Count -gt 0) {
            $definedParams = if ($PolicyJson.properties.parameters) {
                $PolicyJson.properties.parameters.PSObject.Properties.Name
            }
            else { @() }
            foreach ($ref in $referencedParams) {
                if ($ref -notin $definedParams) {
                    throw "policyRule references parameter '$ref' which is not defined in properties.parameters."
                }
            }
        }
        Write-Host "  ✅ All parameter references are valid" -ForegroundColor Green

        # 5. Validate effect-specific requirements
        Write-Host "  ➤ Validating effect-specific requirements..." -ForegroundColor Yellow
        
        switch ($Effect) {
            { $_ -in @("auditifnotexists", "deployifnotexists") } {
                if (-not $PolicyJson.properties.policyRule.then.details) {
                    throw "Effect '$Effect' requires 'details' section"
                }
                if (-not $PolicyJson.properties.policyRule.then.details.type) {
                    throw "Effect '$Effect' requires 'details.type' property"
                }
                Write-Host "  ✅ Effect-specific validation passed" -ForegroundColor Green
            }
            "modify" {
                if (-not $PolicyJson.properties.policyRule.then.details) {
                    throw "Effect 'modify' requires 'details' section"
                }
                if (-not $PolicyJson.properties.policyRule.then.details.operations) {
                    throw "Effect 'modify' requires 'details.operations' array"
                }
                Write-Host "  ✅ Effect-specific validation passed" -ForegroundColor Green
            }
            default {
                Write-Host "  ✅ No additional validation required for effect '$Effect'" -ForegroundColor Green
            }
        }

        # 6. Resolve the specialized agent type
        $AgentType = $null
        switch ($Effect) {
            "deny" {
                $AgentType = "deny"
            }
            { $_ -in @("audit", "auditifnotexists") } {
                $AgentType = "audit"
            }
            { $_ -in @("deployifnotexists", "dine") } {
                $AgentType = "dine"
            }
            "modify" {
                $AgentType = "modify"
            }
            default {
                Write-Warning "  ⚠️  Unknown effect '$Effect', routing to DENY group"
                $AgentType = "deny"
            }
        }

        # 7. Skip agent testing only when the latest evidence for this exact policy content passed.
        $PolicyName = if ($PolicyJson.name) { [string]$PolicyJson.name } else { [System.IO.Path]::GetFileNameWithoutExtension($JsonFile) }
        $NormalisedJsonFile = $JsonFile -replace '\\', '/'
        $ContentHash = Get-PolicyContentHash -Policy $PolicyJson
        $EvidenceKey = Get-EvidenceKey -PolicyFile $NormalisedJsonFile -ContentHash $ContentHash
        $EvidenceEntry = if ($LatestEvidence.ContainsKey($EvidenceKey)) { $LatestEvidence[$EvidenceKey] } else { $null }
        $EvidenceMatch = if ($EvidenceEntry) { $EvidenceEntry.Record } else { $null }

        if ($EvidenceMatch -and ([string]$EvidenceMatch.result).ToUpper() -eq 'PASS') {
            # ConvertFrom-Json turns ISO timestamps into DateTime, so re-serialise explicitly.
            $TestedAt = if ($EvidenceEntry.Timestamp -gt [datetimeoffset]::MinValue) {
                $EvidenceEntry.Timestamp.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            }
            else {
                ''
            }
            $EvidenceSkippedPolicies += [ordered]@{
                file        = $NormalisedJsonFile
                policyName  = $PolicyName
                effect      = $Effect
                agentType   = $AgentType
                contentHash = $ContentHash
                result      = [string]$EvidenceMatch.result
                testedAt    = $TestedAt
                runUrl      = [string]$EvidenceMatch.runUrl
            }
            $ValidationResults += "✅ $JsonFile - Valid; agent test skipped (matching PASS evidence)"
            Write-Host "  Matching PASS evidence found. Skipping agent test." -ForegroundColor Green
            if ($EvidenceMatch.runUrl) {
                Write-Host "  Evidence: $($EvidenceMatch.runUrl)"
            }
            continue
        }

        # 8. Group the policy and add a matrix entry for agent testing.
        Write-Host "  ➤ Grouping policy by effect type..." -ForegroundColor Yellow
        switch ($AgentType) {
            "deny" {
                $DenyPolicies += $PolicyContent
                Write-Host "  📁 Added to DENY policies group" -ForegroundColor Magenta
            }
            "audit" {
                $AuditPolicies += $PolicyContent
                Write-Host "  📁 Added to AUDIT policies group" -ForegroundColor Blue
            }
            "dine" {
                $DinePolicies += $PolicyContent
                Write-Host "  📁 Added to DINE policies group" -ForegroundColor Yellow
            }
            "modify" {
                $ModifyPolicies += $PolicyContent
                Write-Host "  📁 Added to MODIFY policies group" -ForegroundColor Cyan
            }
        }

        $MatrixIndex = $PolicyMatrix.Count + 1
        $PolicyMatrix += [ordered]@{
            index      = '{0:d2}' -f $MatrixIndex
            file       = $NormalisedJsonFile
            policyName = $PolicyName
            effect     = $Effect
            agentType  = $AgentType
            slug       = Get-PolicySlug -Index $MatrixIndex -AgentType $AgentType -PolicyName $PolicyName
        }

        $ValidationResults += "✅ $JsonFile - Valid (effect: $Effect)"
        Write-Host "  ✅ Validation completed successfully" -ForegroundColor Green

    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "  ❌ Validation failed: $errorMessage"
        $ValidationResults += "❌ $JsonFile - Invalid: $errorMessage"
        $HasValidationErrors = $true
        
        Write-Host "  ⚠️  Skipping invalid policy - will not be tested by agents" -ForegroundColor Yellow
    }
}

# Display validation summary
Write-Host "`n=== Validation Summary ===" -ForegroundColor Green
$ValidationResults | ForEach-Object { 
    if ($_ -match "✅") {
        Write-Host $_ -ForegroundColor Green
    }
    else {
        Write-Host $_ -ForegroundColor Red
    }
}

# Report validation status — fail the workflow if any policy is invalid
if ($HasValidationErrors) {
    Write-Host "`n❌ One or more policies failed validation. Fix the errors above before re-running." -ForegroundColor Red
    Write-Host "Invalid policies will NOT be tested." -ForegroundColor Red
    # Fail the workflow step so the PR is blocked
    exit 1
}
else {
    Write-Host "`n✅ All policies passed validation!" -ForegroundColor Green
}

# Convert each effect type group to JSON and Base64
$DenyPoliciesJson = "[$($DenyPolicies -join ',')]"
$AuditPoliciesJson = "[$($AuditPolicies -join ',')]"
$DinePoliciesJson = "[$($DinePolicies -join ',')]"
$ModifyPoliciesJson = "[$($ModifyPolicies -join ',')]"

$DenyPoliciesBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($DenyPoliciesJson))
$AuditPoliciesBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($AuditPoliciesJson))
$DinePoliciesBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($DinePoliciesJson))
$ModifyPoliciesBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($ModifyPoliciesJson))

# Output policy distribution
Write-Host "`n📊 Valid Policies Ready for Agent Testing:" -ForegroundColor Green
Write-Host "  🚫 Deny: $($DenyPolicies.Count)" -ForegroundColor Magenta
Write-Host "  📊 Audit: $($AuditPolicies.Count)" -ForegroundColor Blue
Write-Host "  🚀 DeployIfNotExists: $($DinePolicies.Count)" -ForegroundColor Yellow
Write-Host "  🔧 Modify: $($ModifyPolicies.Count)" -ForegroundColor Cyan

# Output policy distribution to step summary
Write-CIStepSummary "`n📊 Valid Policies Ready for Agent Testing:"
Write-CIStepSummary "  🚫 Deny: $($DenyPolicies.Count)"
Write-CIStepSummary "  📊 Audit: $($AuditPolicies.Count)"
Write-CIStepSummary "  🚀 DeployIfNotExists: $($DinePolicies.Count)"
Write-CIStepSummary "  🔧 Modify: $($ModifyPolicies.Count)"

$ValidPoliciesCount = $DenyPolicies.Count + $AuditPolicies.Count + $DinePolicies.Count + $ModifyPolicies.Count
$TotalFilesProcessed = $JsonFilesList.Count
$EvidenceSkippedCount = $EvidenceSkippedPolicies.Count
$InvalidPoliciesCount = $TotalFilesProcessed - $ValidPoliciesCount - $EvidenceSkippedCount

if ($EvidenceSkippedCount -gt 0) {
    Write-Host "  Matching PASS evidence: $EvidenceSkippedCount" -ForegroundColor Green
    Write-CIStepSummary "  Matching PASS evidence: $EvidenceSkippedCount"
    foreach ($skipped in $EvidenceSkippedPolicies) {
        $evidenceLink = if ($skipped.runUrl) { " ([evidence]($($skipped.runUrl)))" } else { "" }
        Write-CIStepSummary "  - ``$($skipped.file)``$evidenceLink"
    }
}

if ($InvalidPoliciesCount -gt 0) {
    Write-Host "  ❌ Skipped (invalid): $InvalidPoliciesCount" -ForegroundColor Red
    Write-Host "`n📝 Summary: $ValidPoliciesCount of $TotalFilesProcessed policies will be tested" -ForegroundColor Cyan
}
else {
    Write-Host "`n📝 Summary: $ValidPoliciesCount policies will be tested; $EvidenceSkippedCount have matching PASS evidence" -ForegroundColor Cyan
}

# Write outputs for workflow
Set-CIOutput "denyPoliciesBase64" $DenyPoliciesBase64
Set-CIOutput "auditPoliciesBase64" $AuditPoliciesBase64
Set-CIOutput "dinePoliciesBase64" $DinePoliciesBase64
Set-CIOutput "modifyPoliciesBase64" $ModifyPoliciesBase64

Set-CIOutput "denyPoliciesCount" "$($DenyPolicies.Count)"
Set-CIOutput "auditPoliciesCount" "$($AuditPolicies.Count)"
Set-CIOutput "dinePoliciesCount" "$($DinePolicies.Count)"
Set-CIOutput "modifyPoliciesCount" "$($ModifyPolicies.Count)"
Set-CIOutput "skippedByEvidenceCount" "$EvidenceSkippedCount"

# Base64 so the structured skip list survives GITHUB_OUTPUT without quoting concerns.
$EvidenceSkippedJson = if ($EvidenceSkippedCount -gt 0) {
    ConvertTo-Json -InputObject @($EvidenceSkippedPolicies) -Depth 5 -Compress
}
else {
    "[]"
}
Set-CIOutput "skippedByEvidenceBase64" ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($EvidenceSkippedJson)))

# Per-policy matrix: one parallel test job, and one ephemeral agent, per policy.
if ($PolicyMatrix.Count -gt $MaxMatrixJobs) {
    Write-Host "`n❌ $($PolicyMatrix.Count) policies exceed the $MaxMatrixJobs job matrix limit. Split the change across multiple pull requests." -ForegroundColor Red
    exit 1
}

$PolicyMatrixJson = if ($PolicyMatrix.Count -gt 0) {
    ConvertTo-Json -InputObject @($PolicyMatrix) -Depth 5 -Compress
}
else {
    "[]"
}
Set-CIOutput "policyMatrix" $PolicyMatrixJson

Write-Host "`n🧩 Per-policy test matrix ($($PolicyMatrix.Count) job(s)):" -ForegroundColor Green
$PolicyMatrix | ForEach-Object { Write-Host "  - $($_.slug) -> $($_.file) (effect: $($_.effect))" }

$TotalPolicies = $ValidPoliciesCount
Set-CIOutput "processedFilesCount" "$TotalPolicies"

if ($TotalPolicies -gt 0) {
    Write-Host "`n🎯 Validation complete! Ready for AI agent testing." -ForegroundColor Green
    Write-Host "Valid policies will be tested: $TotalPolicies" -ForegroundColor White
}
elseif ($EvidenceSkippedCount -gt 0) {
    Write-Host "`nValidation complete. All changed policies have matching PASS evidence." -ForegroundColor Green
    Write-Host "No AI agent tests are required." -ForegroundColor Green
}
else {
    Write-Host "`n⚠️  No valid policies found for testing." -ForegroundColor Yellow
    Write-Host "All policies failed validation. Please fix the errors and try again." -ForegroundColor Yellow
}