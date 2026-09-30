# JobId Tagging — How Policy Test Resources Are Tracked and Cleaned Up

This document explains how the `JobId` tag is generated, applied to Azure resources, and used by the `FinalCleanup` job to remove all test resources created during a workflow run.

---

## Overview

Every resource created by a policy test script is tagged with a `JobId` value. This tag has a predictable format so that the `FinalCleanup` job can find and delete all resources belonging to a specific GitHub Actions workflow run, regardless of which policy effect was tested or how many policies were processed.

---

## Tag Format

### CI / GitHub Actions runs

```
gh-{runId}-{agentType}-{policyIndex}-{8-char-hex-suffix}
```

| Segment | Source | Example |
|---|---|---|
| `gh` | Static prefix — identifies GitHub Actions origin | `gh` |
| `{runId}` | `github.run_id` context variable | `12345678901` |
| `{agentType}` | Specialized agent that tested the policy (`deny`, `audit`, `dine`, `modify`) | `dine` |
| `{policyIndex}` | Two digit index of the policy in the per-policy test matrix | `03` |
| `{8-char-hex-suffix}` | Per-script unique suffix generated inside the test script | `a1b2c3d4` |

**Full example tags produced during a CI run:**

```
gh-12345678901-deny-02-a1b2c3d4
gh-12345678901-audit-06-f9e8d7c6
gh-12345678901-dine-03-01ab23cd
gh-12345678901-modify-01-99887766
```

> Each policy is tested in its own parallel job with its own ephemeral agent, so if 3 deny policies are tested in one run there will be 3 distinct JobId values, each carrying a different policy index.

### Local / manual runs (no CI environment)

When `JOB_ID_PREFIX` is not set, scripts fall back to `local` as the prefix:

```
local-{8-char-hex-suffix}
```

**Example:** `local-b4c5d6e7`

> Resources tagged `local-*` are **not** matched by `FinalCleanup` (which only searches `gh-{runId}-*`). Local test resources must be cleaned up manually.

---

## How the JobId Flows Through the System

```
PolicyAgent.yml
  └─ Sets: JOB_ID = "gh-{run_id}-{agentType}-{policyIndex}"
       └─ Calls: test-policies-cli.ps1 -JobId $jobId
            └─ Sets: $env:JOB_ID_PREFIX = $jobId
                 └─ Agent generates script → script reads $env:JOB_ID_PREFIX
                      └─ Script generates: $JobId = "$JobIdPrefix-{8-char-suffix}"
                           ├─ Tags resource group:     @{CreatedBy='GitHubActions'; JobId=$JobId}
                           ├─ Tags test resources:     @{CreatedBy='GitHubActions'; JobId=$JobId}
                           └─ Writes logging.json:     { "JobId": "...", "TestResult": "..." }
```

### Step 1 — Workflow sets the prefix (`PolicyAgent.yml`)

```yaml
JOB_ID: gh-${{ github.run_id }}-${{ matrix.policy.agentType }}-${{ matrix.policy.index }}
```

This value is passed to `test-policies-cli.ps1` via the `-JobId` parameter.

### Step 2 — Test harness forwards prefix to generated scripts (`test-policies-cli.ps1`)

```powershell
# Pass JobId to the script via environment variable
$env:JOB_ID_PREFIX = $JobId

# PowerShell scripts:
& pwsh -NonInteractive -File $scriptPath

# Bash scripts:
& bash -c "export JOB_ID_PREFIX='$JobId' && $scriptPath"
```

> **Why env var and not a script parameter?** The test harness calls generated scripts without arguments (`-File $scriptPath` only). Environment variables are the only reliable cross-language mechanism.

### Step 3 — Generated script reads the prefix and appends a unique suffix

**PowerShell scripts (deny, audit, dine):**

```powershell
# Read JobId prefix from environment variable set by test harness
$JobIdPrefix = if ($env:JOB_ID_PREFIX) { $env:JOB_ID_PREFIX } else { 'local' }

# Append 8-char hex suffix from a new GUID to make this test's JobId unique
$JobId = "$JobIdPrefix-$([guid]::NewGuid().ToString().Substring(0,8))"
```

**Bash scripts (modify):**

```bash
# Read JobId prefix from environment variable set by test harness
job_id_prefix="${JOB_ID_PREFIX:-local}"

# Append first segment of uuidgen (8 lowercase hex chars) as unique suffix
job_id="$job_id_prefix-$(uuidgen | cut -d'-' -f1)"
```

Both methods produce the same format: `{prefix}-{8-char-hex-suffix}`.

### Step 4 — Script applies the tag to all resources

```powershell
# Resource groups
New-AzResourceGroup -Name $rgName -Location $location `
    -Tag @{CreatedBy='GitHubActions'; JobId=$JobId}

# Individual resources (storage accounts, VMs, etc.)
New-AzStorageAccount -ResourceGroupName $rgName -Name $storageName `
    -Tag @{CreatedBy='GitHubActions'; JobId=$JobId} ...
```

> Policy assignments cannot be tagged (`-Tag` is not a valid parameter for `New-AzPolicyAssignment`). Only resource groups and resources receive the tag.

### Step 5 — Script writes JobId to `logging.json`

```json
{
  "JobId": "gh-12345678901-dine-03-01ab23cd",
  "TestResult": "PASS: DINE policy successfully deployed missing resource",
  "PolicyDeployed": true,
  "PolicyAssigned": true,
  "StartTime": "2026-04-17T10:00:00.0000000Z",
  "EndTime": "2026-04-17T10:06:12.3456789Z",
  "Error": null
}
```

> The JSON key must be `JobId` (capital J, capital I). All four agent types use this exact casing. `test-policies-cli.ps1` reads this field via `$response.JobId`.

---

## How FinalCleanup Uses JobId (`PolicyAgent.yml`)

The `FinalCleanup` job runs after all policy tests complete (even on failure) and deletes any resource groups still tagged with a `JobId` belonging to the current run.

```powershell
$runId = "${{ github.run_id }}"

# Build prefix pattern that covers every policy job in this run
# Matches: gh-{runId}-{agentType}-{policyIndex}-*
$jobIdPattern = "gh-$runId-"

$allResourceGroups = Get-AzResourceGroup -ErrorAction SilentlyContinue

$resourceGroups = $allResourceGroups | Where-Object {
    if ($_ -and $_.Tags -and $_.Tags['JobId']) {
        $jobId = $_.Tags['JobId']
        $jobId.StartsWith($jobIdPattern)   # prefix match covers every policy job
    }
}

foreach ($rg in $resourceGroups) {
    Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force -AsJob
}
```

The prefix match `gh-{runId}-` (no agent type or index suffix, no trailing wildcard needed because `.StartsWith()` is used) catches every policy job in one pass.

---

## Example — End-to-End for Run ID 12345678901

| Stage | Value |
|---|---|
| Workflow `JOB_ID` | `gh-12345678901-dine-03` |
| `$env:JOB_ID_PREFIX` in script | `gh-12345678901-dine-03` |
| Generated `$JobId` in script | `gh-12345678901-dine-03-01ab23cd` |
| Resource group tag | `JobId = gh-12345678901-dine-03-01ab23cd` |
| `logging.json` `JobId` field | `gh-12345678901-dine-03-01ab23cd` |
| FinalCleanup search pattern | `gh-12345678901-` (prefix match) |
| FinalCleanup match result | ✅ `"gh-12345678901-dine-03-01ab23cd".StartsWith("gh-12345678901-")` → `true` |

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| FinalCleanup finds 0 resource groups | Script used `param([string]$JobIdPrefix = "local")` instead of `$env:JOB_ID_PREFIX` | Agent instruction was updated — re-generate the failing script |
| Resources tagged `local-*` not cleaned | Expected — `local-*` is only for local runs, not matched by FinalCleanup | Delete manually or re-run with proper CI env vars |
| `$response.JobId` returns `$null` | `logging.json` uses wrong casing (`jobId` instead of `JobId`) | Modify agent instruction was updated to enforce `JobId` key casing |
| Multiple resource groups for same effect | Normal, each policy job uses its own index and 8-char suffix | All are matched by the prefix pattern |
