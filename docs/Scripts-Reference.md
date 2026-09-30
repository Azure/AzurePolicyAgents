# `scripts/` — Script Reference

This folder contains all CI/CD, deployment and build scripts used by the policy-agent, instructions-agent and deployment workflows and pipelines. The CI/CD helper scripts are documented in detail below.

---

## `get-changed-files.sh`

Detects which `policyDefinitions/*.json` files changed in the current push or pull request and emits them as workflow outputs.

```mermaid
flowchart TD
    START(["Workflow trigger\nPR or push"])
    START --> EVT{GITHUB_EVENT_NAME\n== pull_request?}
    EVT -->|yes| PR_DIFF["git diff --name-only\nPR_BASE_SHA..PR_HEAD_SHA"]
    EVT -->|no| PUSH_DIFF["git diff --name-only\nHEAD~1 HEAD"]
    PR_DIFF --> FILTER
    PUSH_DIFF --> FILTER
    FILTER["grep policyDefinitions/*.json\n→ JSON_FILES list"]
    FILTER --> OUT["Write to GITHUB_OUTPUT:\nall_changed_files\njson_files\njson_files_count"]
    OUT --> DONE(["validate-policies.ps1\nreceives json_files"])
```

**Inputs:** `$GITHUB_EVENT_NAME`, `$PR_BASE_SHA`, `$PR_HEAD_SHA`
**Outputs:** `json_files`, `json_files_count`

---

## `validate-policies.ps1`

Validates every changed policy JSON file for structural correctness, groups valid policies by effect type, and emits a per-policy job matrix so each policy is tested in its own parallel job. Exits `1` on any validation failure, blocking the PR.

```mermaid
flowchart TD
    START(["json_files\njson_files_count\nfrom workflow"])
    START --> PARSE["Split + deduplicate\nfile list"]
    PARSE --> LOOP

    subgraph LOOP ["For each policy file"]
        direction TB
        J["① Parse JSON — syntax check"]
        J --> STRUCT["② Validate required keys:\nproperties, policyRule.if, policyRule.then"]
        STRUCT --> TYPO["③ Detect 'parameterss' typo\nin raw JSON string"]
        TYPO --> PARAMS["④ Validate all [parameters('x')]\nreferences exist in properties.parameters\n(ARM template body excluded for DINE)"]
        PARAMS --> FX["⑤ Effect-specific rules:\nauditIfNotExists/deployIfNotExists → details.type required\nmodify → details.operations required"]
        FX --> GROUP["⑥ Resolve effect\n(direct value or parameter defaultValue)"]
        GROUP --> OK{Valid?}
        OK -->|yes| EVIDENCE{"Latest exact path + hash\nevidence is PASS?"}
        EVIDENCE -->|yes| SKIP["Record evidence skip"]
        EVIDENCE -->|no| VALID["Group by effect\nAppend matrix entry"]
        OK -->|no| ERR["Record error\nHasValidationErrors = true"]
    end

    VALID --> SUMMARY
    SKIP --> SUMMARY
    ERR --> SUMMARY
    SUMMARY{Any errors?}
    SUMMARY -->|yes| FAIL(["exit 1\nPR blocked"])
    SUMMARY -->|no| ENCODE["Base64-encode each effect group\nWrite outputs to GITHUB_OUTPUT:\npolicyMatrix\ndenyPoliciesBase64\nauditPoliciesBase64\ndinePoliciesBase64\nmodifyPoliciesBase64"]
    ENCODE --> DONE(["PolicyAgent fans out\none job per policy"])
```

**Inputs:** `-JsonFiles`, `-JsonFilesCount`, optional `-EvidenceFiles`, and optional `-ForceRetest`
**Outputs:** `policyMatrix`, `denyPoliciesBase64`, `auditPoliciesBase64`, `dinePoliciesBase64`, `modifyPoliciesBase64`, `skippedByEvidenceCount`, `skippedByEvidenceBase64` + counts

When evidence files are supplied, validation still runs for every policy. Agent testing is omitted
only when the latest record for the same policy path and canonical content hash is `PASS`.
`-ForceRetest $true` disables this filter.

`skippedByEvidenceBase64` is a base64 encoded JSON array describing each skipped policy
(`file`, `policyName`, `effect`, `agentType`, `contentHash`, `result`, `testedAt`, `runUrl`).
The `CommentResults` job decodes it to list skipped policies in the pull request comment,
because skipped policies produce no test artifact.

`policyMatrix` is a compact JSON array consumed by `fromJSON()` in the `PolicyAgent` job matrix. Each entry contains:

| Field | Description | Example |
| --- | --- | --- |
| `index` | Two digit, one based position in the matrix | `03` |
| `file` | Repository relative path to the policy definition | `policyDefinitions/allowedLocations.json` |
| `policyName` | `name` from the policy definition | `Allowed-Locations-Resources` |
| `effect` | Resolved effect value | `deployifnotexists` |
| `agentType` | Specialized agent that tests this effect | `dine` |
| `slug` | Unique job, artifact and agent naming token | `03-dine-diagnostic-vnet` |

The per-effect Base64 outputs are retained for the repository's Azure DevOps parity pipeline (`pipelines/policy-agent.yml`), which still tests one batch per effect for teams mirroring the GitHub Actions workflow in Azure DevOps.

---

## `manage-test-agent.ps1`

Manages the lifecycle of ephemeral Foundry test agents. Each `PolicyAgent` job clones its specialized base agent into a uniquely named agent, tests one policy with it, then deletes it.

| Action | Purpose |
| --- | --- |
| `Create` | Clones `-BaseAgentId` into `-AgentName`, copying model, instructions, MCP tool configuration and reasoning effort. Writes the created agent ID to `GITHUB_OUTPUT`. |
| `Delete` | Removes a single ephemeral agent by `-AgentId` or `-AgentName`. Non-fatal on failure. |
| `Sweep` | Deletes every agent whose name starts with `-NamePrefix`. Used by `FinalCleanup` as a fail-safe for cancelled or timed out jobs. |

Ephemeral agent names follow `pta-gh-{runId}-{runAttempt}-{policyIndex}-{agentType}`. The run attempt is included so a re-run cannot collide with an agent orphaned by a previous attempt.

---

## `test-policies-cli.ps1`

Agent-driven test runner. In GitHub Actions it is invoked once per policy against a dedicated ephemeral agent; the Azure DevOps pipeline still invokes it once per effect with a Base64-encoded list. For each policy it asks the agent to generate a bash test script, executes it, and formats the results.

```mermaid
flowchart TD
    START(["AgentType, Endpoint,\nAssistantId, JobId,\nBase64 policy list"])
    START --> INIT["Validate AgentType\nDetect bash env: WSL or native bash\nVerify agent accessible via Metro.AI"]
    INIT --> DECODE["Base64-decode policy list\nParse JSON array"]
    DECODE --> LOOP

    subgraph LOOP ["For each policy"]
        direction TB
        CONV["New-MetroAIConversation"]

        CONV --> T1["Turn 1 — analysis only\nInvoke-MetroAIConversation -AutoApprove\nKeeps response short / within 100s timeout"]

        T1 --> DINE{DINE policy?}
        DINE -->|no| T2["Turn 2: script generation\nInvoke-MetroAIConversation -AutoApprove"]
        DINE -->|yes| DT2["Turn 2: DINE script generation\nInvoke-MetroAIApiCall directly\n300-second timeout"]

        T2 --> EXT{Script found?\nfenced block, shebang,\nor raw body}
        DT2 --> EXT
        EXT -->|yes| EXEC
        EXT -->|no| RETRY

        subgraph RETRY ["Retry loop  (up to MaxRetryAttempts)"]
            direction TB
            NEWCONV["New-MetroAIConversation\nFresh conversation avoids HTTP 400\nfrom stuck MCP approval state"]
            NEWCONV --> RTURN["Single turn with full\npolicy content in prompt\nDINE uses direct 300-second call"]
            RTURN --> REXT{Script found?\nfenced, shebang,\nor raw}
        end

        REXT -->|yes| EXEC
        REXT -->|no, attempts exhausted| SKIP["Emit warning:\nno script generated"]

        EXEC["Write script to temp file\nbash -c with JOB_ID_PREFIX env var set"]
        EXEC --> LOG["Read logging.json\nwritten by script cleanup trap"]
        LOG --> FMT["Format-PolicyResult\n→ RESULT.md entry\n→ DEBUG.md entry"]
    end

    FMT --> OUT["Write step summary\nPost PR comment\nUpload RESULT.md + DEBUG.md artifacts"]
    SKIP --> OUT
    OUT --> DONE(["instructions-agent.ps1\nconsumes artifacts"])
```

**Key parameters:** `-Endpoint`, `-AssistantId`, `-AgentType`, `-JobId`, `-MaxRetryAttempts`

**Script extraction (`Get-ScriptFromText`):** The agent response is parsed for a runnable script in this order: an explicit `powershell`/`bash` fenced block, any fenced block with language inferred from content, a raw body starting at a `#!` shebang line, then an un-fenced body detected by PowerShell or bash signals. Agents commonly return the script body directly without a markdown fence, so shebang and raw-body detection prevent false "no script generated" results.

---

## `instructions-agent.ps1`

Post-test self-improvement script. After a PR test run completes, this script calls the `InstructionsAgent` to analyse results and propose patches to the agent instruction markdown files.

```mermaid
flowchart TD
    START(["Endpoint, AssistantId,\nArtifactsPath,\nAgentInstructionsPath,\nWorkflowLogPath"])
    START --> READ["Read inputs:\nagentInstructions/*.md  (one per agent type)\nRESULT.md + DEBUG.md from artifact downloads\nWorkflow run log (truncated to MaxLogChars)"]

    READ --> LOOP

    subgraph LOOP ["For each agent type: deny / audit / dine / modify"]
        direction TB
        CONV["New-MetroAIConversation"]
        CONV --> SIZE{Estimated prompt\n> 30,000 chars?}

        SIZE -->|no| T1S["Single turn:\nInstructions + Results + Debug + Log\nInvoke-MetroAIConversation"]
        SIZE -->|yes| T1M["Turn 1:\nInstructions + Results + Log\n— analysis only"]
        T1M --> T2M["Turn 2:\nDebug artifacts\n— propose patches"]

        T1S --> PARSE
        T2M --> PARSE

        PARSE["Extract JSON from fenced block\nor bare object in response"]
        PARSE --> PATCH{changes_required\n== true?}
        PATCH -->|no| NOOP["Log: no changes needed"]
        PATCH -->|yes| APPLY

        subgraph APPLY ["For each patch"]
            direction TB
            FIND["Locate old_content exactly\nin target .md file"]
            FIND --> SUB["Replace with new_content"]
            SUB --> WRITE["Write file back\nSet-Content -Encoding utf8"]
        end

        APPLY --> CLEANUP["Remove-MetroAIConversation"]
        NOOP --> CLEANUP
    end

    CLEANUP --> COMMIT["git add agentInstructions/*.md\ngit commit + push\n(only if any file changed)"]
    COMMIT --> DONE(["Updated instructions\ncommitted to repo"])
```

**Key parameters:** `-Endpoint`, `-AssistantId`, `-ArtifactsPath`, `-AgentInstructionsPath`, `-WorkflowLogPath`, `-MaxLogChars`

**Secret guard:** Before any proposed patch is written, `Get-SecretMatch` scans the patch `new_content` for credential-shaped values (hex strings of 32 or more characters, assigned `key`/`secret`/`password`/`token`/`connectionString` values, storage `AccountKey=...`, AWS `AKIA...` keys, and `eyJ...` JWTs). A match rejects that patch and records it in the maintenance summary; obvious placeholders containing `FAKE`, `PLACEHOLDER`, `REPLACE`, `EXAMPLE`, or `REDACTED` are allowed. This prevents the maintenance agent from committing a real or realistic-looking secret into `agentInstructions/*.md`.
