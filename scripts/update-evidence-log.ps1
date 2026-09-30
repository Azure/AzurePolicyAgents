<#
.SYNOPSIS
    Updates the durable Markdown policy test evidence log.

.DESCRIPTION
    Consumes evidence.md files produced by test-policies-cli.ps1 (one per effect, downloaded as
    workflow artifacts), enriches each record with pull request context and the source policy file,
    then updates docs/test-evidence/evidence-log.md with the latest result per policy.
    See docs/Test-Evidence.md for the table schema.

.PARAMETER ArtifactsPath
    Directory containing downloaded artifacts. evidence.md files are discovered recursively.

.PARAMETER EvidenceDir
    Directory holding the durable evidence log files. Defaults to docs/test-evidence.

.PARAMETER PolicyDefinitionsPath
    Directory of policy definition JSON files, used to resolve each record's source file by policy name.

.PARAMETER PrNumber
    Pull request number that triggered the run. Optional.

.PARAMETER CommitSha
    Head commit SHA of the run. Optional.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactsPath,

    [Parameter()]
    [string]$EvidenceDir = "docs/test-evidence",

    [Parameter()]
    [string]$PolicyDefinitionsPath = "policyDefinitions",

    [Parameter()]
    [string]$PrNumber = "",

    [Parameter()]
    [string]$CommitSha = ""
)

$ErrorActionPreference = 'Stop'

$mdPath = Join-Path $EvidenceDir "evidence-log.md"

if (-not (Test-Path $EvidenceDir)) {
    New-Item -Path $EvidenceDir -ItemType Directory -Force | Out-Null
}

function ConvertFrom-EvidenceMarkdown {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return @() }

    $records = @()
    foreach ($line in Get-Content -Path $Path) {
        if ($line -notmatch '^\|.+\|$' -or
            $line -match '^\|\s*-+' -or
            $line -match '^\|\s*Policy\s*\|') {
            continue
        }

        $columns = $line.Trim('|').Split('|') | ForEach-Object { $_.Trim() }
        if ($columns.Count -lt 8) { continue }

        $policyName = $columns[0]
        $policyFile = $null
        if ($policyName -match '^\[(?<name>.+)\]\((?<path>.+)\)$') {
            $policyName = $Matches.name
            $policyFile = $Matches.path
        }

        $prNumber = if ($columns[4] -match '^#(?<number>\d+)$') { $Matches.number } else { $null }
        $runUrl = if ($columns[7] -match '^\[log\]\((?<url>.+)\)$') { $Matches.url } else { $null }

        $records += [ordered]@{
            timestamp   = $columns[3]
            policyName  = $policyName
            policyFile  = $policyFile
            effect      = $columns[1]
            result      = $columns[2]
            contentHash = $columns[6]
            prNumber    = $prNumber
            commitSha   = if ($columns[5] -ne '-') { $columns[5] } else { $null }
            runUrl      = $runUrl
            agent       = $null
        }
    }

    return @($records)
}

# Build a policy-name -> relative-file-path map to resolve each record's source file.
$nameToFile = @{}
if (Test-Path $PolicyDefinitionsPath) {
    Get-ChildItem -Path $PolicyDefinitionsPath -Filter *.json -File | ForEach-Object {
        try {
            $def = Get-Content $_.FullName -Raw | ConvertFrom-Json
            if ($def.name) {
                $rel = "$PolicyDefinitionsPath/$($_.Name)" -replace '\\', '/'
                $nameToFile[[string]$def.name] = $rel
            }
        }
        catch {
            Write-Warning "Could not parse $($_.Name): $($_.Exception.Message)"
        }
    }
}

# Discover and enrich new evidence records from this run's artifacts.
$newRecords = @()
$evidenceFiles = Get-ChildItem -Path $ArtifactsPath -Filter "evidence.md" -File -Recurse -ErrorAction SilentlyContinue
foreach ($file in $evidenceFiles) {
    foreach ($rec in ConvertFrom-EvidenceMarkdown -Path $file.FullName) {
        $policyFile = if ($rec.policyName -and $nameToFile.ContainsKey([string]$rec.policyName)) {
            $nameToFile[[string]$rec.policyName]
        }
        else { $rec.policyFile }

        $newRecords += [ordered]@{
            timestamp   = $rec.timestamp
            policyName  = $rec.policyName
            policyFile  = $policyFile
            effect      = $rec.effect
            result      = $rec.result
            contentHash = $rec.contentHash
            prNumber    = if ($PrNumber) { $PrNumber } else { $null }
            commitSha   = if ($CommitSha) { $CommitSha } else { $null }
            runUrl      = $rec.runUrl
            agent       = $rec.agent
        }
    }
}

if ($newRecords.Count -eq 0) {
    Write-Host "No evidence records found under $ArtifactsPath. Nothing to update."
    exit 0
}

$allRecords = @()
$allRecords += ConvertFrom-EvidenceMarkdown -Path $mdPath
$allRecords += $newRecords

$latest = @{}
foreach ($rec in $allRecords) {
    $key = "$($rec.policyName)|$($rec.effect)"
    if (-not $latest.ContainsKey($key) -or [datetime]$rec.timestamp -gt [datetime]$latest[$key].timestamp) {
        $latest[$key] = $rec
    }
}

# Regenerate the human-readable table, latest result per policy.
$rows = @($latest.Values) | Sort-Object policyName, effect
$total = @($rows).Count
$passing = ($rows | Where-Object { $_.result -eq 'PASS' }).Count

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("# Policy Test Evidence Log")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Generated from workflow evidence artifacts. Do not edit by hand. See [Test-Evidence.md](../Test-Evidence.md) for the table schema.")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Last updated: $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')) UTC")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("Policies with evidence: $total | Latest result passing: $passing")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("| Policy | Effect | Result | Last Tested (UTC) | PR | Commit | Content Hash | Evidence |")
[void]$sb.AppendLine("|--------|--------|--------|-------------------|----|--------|--------------|----------|")

foreach ($r in $rows) {
    $policyCell = if ($r.policyFile) { "[$($r.policyName)]($($r.policyFile))" } else { $r.policyName }
    $tested = try { ([datetimeoffset]$r.timestamp).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') } catch { $r.timestamp }
    $prCell = if ($r.prNumber) { "#$($r.prNumber)" } else { "-" }
    $commitCell = if ($r.commitSha) { $r.commitSha.Substring(0, [Math]::Min(7, $r.commitSha.Length)) } else { "-" }
    $hashCell = if ($r.contentHash) { $r.contentHash } else { "-" }
    $evidence = if ($r.runUrl) { "[log]($($r.runUrl))" } else { "-" }
    [void]$sb.AppendLine("| $policyCell | $($r.effect) | $($r.result) | $tested | $prCell | $commitCell | $hashCell | $evidence |")
}

Set-Content -Path $mdPath -Value $sb.ToString() -Encoding utf8
Write-Host "Regenerated $mdPath ($total polic$(if ($total -eq 1) {'y'} else {'ies'}))"
