# Policy Test Evidence Log

This directory holds a durable, version-controlled record of every policy test run, so the
repository is self-documenting: which policies were tested, when, with what result, and a link to
the workflow log that proves it.

## Files

| File | Purpose |
|------|---------|
| `evidence-log.md` | Generated evidence table showing the latest result per policy. Do not edit by hand. |

The workflow can emit raw JSONL evidence during a run, but the repository keeps the canonical record in the Markdown log above. Raw JSONL output is transient and not treated as the checked-in source of truth.

## How it is produced

1. `test-policies-cli.ps1` writes one temporary Markdown evidence table per policy during a test run,
   alongside the existing `RESULT.md` and `DEBUG.md`.
2. Each per-effect result is uploaded as part of the `test-results-<effect>` workflow artifact.
3. The `RecordEvidence` job in `PolicyAgent.yml` downloads the artifacts, runs
   `update-evidence-log.ps1`, and commits the updated Markdown log to the triggering pull request branch, so
   the evidence lands with the same PR that changed the policy.

The commit touches only `docs/test-evidence/`, which the workflow path filter excludes, so appending
evidence never re-triggers a test run.

## Table schema

Each row in `evidence-log.md` contains:

| Field | Description |
|-------|-------------|
| `Policy` | The `name` field of the policy definition, linked to the source file when resolved. |
| `Effect` | Policy effect under test: `deny`, `audit`, `dine`, or `modify`. |
| `Result` | Normalised outcome: `PASS`, `FAIL`, `ERROR`, or `UNKNOWN`. |
| `Last Tested (UTC)` | UTC ISO-8601 time the policy test completed. |
| `PR` | Pull request number that triggered the run. May be blank. |
| `Commit` | Short head commit SHA of the run. May be blank. |
| `Content Hash` | SHA-256 of the canonical policy content. Enables skip-retesting of unchanged policies. |
| `Evidence` | Direct link to the workflow job log. |

## Result values

| Value | Meaning |
|-------|---------|
| `PASS` | The policy behaved as expected. |
| `FAIL` | The policy test completed with a non-passing verdict. |
| `ERROR` | The test did not complete (no script generated, execution error, or missing results). |
| `UNKNOWN` | The test completed but no pass or fail verdict could be determined. |

The `evidence-log.md` table shows only the latest record per policy and effect.

For legacy Markdown rows without a `Content Hash` column, the workflow derives the hash from the
recorded policy file at the row's commit. This preserves evidence matching while keeping Markdown
as the only persisted format.

## Test selection

Pull request runs validate every changed policy, then skip agent testing only when the latest
evidence for the same `policyFile` and canonical `contentHash` is `PASS`. Evidence is read from both
the pull request branch and the default branch. A changed policy hash, or a latest result of `FAIL`,
`ERROR`, or `UNKNOWN`, always queues a new test.

Manual workflow runs bypass evidence-based skipping and retest all selected policies.

## Reporting

The pull request comment lists tested policies and skipped policies separately. Skipped policies
appear in a "Skipped (existing test evidence)" table showing the effect, the timestamp of the
evidence relied on, and a link to the run that produced it. When every changed policy is skipped,
the comment is still posted so the run is never mistaken for a missing or stale result.
