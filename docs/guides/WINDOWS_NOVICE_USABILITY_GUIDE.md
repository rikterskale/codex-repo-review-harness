---
guide_id: windows-novice-usability
guide_schema_version: 1
platform: windows
canonical_path: docs/guides/WINDOWS_NOVICE_USABILITY_GUIDE.md
project_name: "Codex Repo Review Harness"
target_release: "0.2.0 (tagged v0.2.0)"
reviewed_digest: "163fafc3e352b37651581b5b13e884c2313da77e7bda6be4b0f114a11ef708f5"
support_status: native_supported
validation_status: partially_verified
validated_on: 2026-08-13
maintainer_source_of_truth: "README.md, AGENTS.md, config/review-config.yaml, scripts/Run-Review.ps1"
known_limitations:
  - "The repository verifies its local runner and tests; it does not document current external Codex installation, account, authentication, or service requirements."
---

# Windows novice guide

This is the concise, source-verified Windows guide for release 0.2.0, released
on 2026-08-13. The `reviewed_digest` records the harness surface this guide was
checked against.

## What the harness does

The local runner builds a file manifest for a Git repository, sends a review
prompt to Codex with a forced `read-only` sandbox, and compares the target Git
status before and after the run. A successful run writes `review.md`,
`review.json`, and `review.sha256` beneath `reports/` in the harness repository.

The runner does not apply, approve, or merge changes. Review only repositories
you are authorized to inspect, and do not place real credentials in prompts or
reports.

## Before you start

You need a local Git repository and Windows PowerShell 5.1 or PowerShell 7.
The runner requires Git on `PATH`; a real review also requires the `codex`
command on `PATH`.

Open PowerShell in the harness repository and validate the local installation:

```powershell
.\scripts\Validate-Harness.ps1
```

The validator checks required harness files, Git, Codex, the read-only
configuration, a base-branch setting, and `reports/`.

## First safe run

First, prepare the bounded prompt without invoking Codex:

```powershell
.\scripts\Run-Review.ps1 -DryRun
```

Then, when the required external Codex setup is available, run:

```powershell
.\scripts\Run-Review.ps1
```

For a guided local interface, run `scripts/Start-ReviewWizard.ps1`. It lets you
select the existing runner settings, previews the command, and requires you to
type `REVIEW` before it starts a real read-only review.

The default prompt is `prompts/system-review.md`. The runner writes successful
artifacts beneath:

```text
reports\<target-name>\<timestamp>-<run-id>\
```

## Common commands

```powershell
# Review another local Git repository.
.\scripts\Run-Review.ps1 -RepositoryPath C:\path\to\target-repository

# Use a bundled prompt.
.\scripts\Run-Review.ps1 -Prompt security-focus.md
.\scripts\Run-Review.ps1 -Prompt pr-diff-review.md

# Override the configured base branch for one run.
.\scripts\Run-Review.ps1 -BaseBranch develop

# Extend the timeout for one run.
.\scripts\Run-Review.ps1 -TimeoutSeconds 1800
```

See [CLI reference](../CLI_REFERENCE.md) for every option and default.

## Exit codes

| Code | Meaning | Troubleshooting |
| --- | --- | --- |
| `0` | Successful review or dry run | `WIN-TRB-001` |
| `2` | Usage or configuration problem | `WIN-TRB-002` |
| `3` | Missing prerequisite | `WIN-TRB-003` |
| `4` | Codex failure or no final message | `WIN-TRB-004` |
| `5` | Contract, secret-detection, consistency, or target-change failure | `WIN-TRB-005` |
| `6` | Timeout | `WIN-TRB-006` |
| `7` | Output-size limit | `WIN-TRB-007` |

## Troubleshooting

| ID | Symptom | Likely cause | Exact corrective steps | Expected result | Verification command |
| --- | --- | --- | --- | --- | --- |
| `WIN-TRB-001` | Exit `0` | The operation completed. | Open the printed `review.md` path after a real run, or use the dry-run output to confirm preparation. | Report paths or prepared-review message are shown. | `Get-ChildItem reports -Recurse -File` |
| `WIN-TRB-002` | Exit `2` | Invalid option value, configuration, prompt, or output directory. | Read the error; use a prompt beneath `prompts/`, use a positive timeout, use an output limit of at least 1024, and keep `report.output_dir` relative. | The runner starts or completes. | `.\scripts\Run-Review.ps1 -DryRun` |
| `WIN-TRB-003` | Exit `3` | Git, Codex, or a Git repository is unavailable. | Confirm Git first. For a real run, make the `codex` command available. Move into a Git repository or pass `-RepositoryPath` to one. | The prerequisite error is gone. | `git --version` |
| `WIN-TRB-004` | Exit `4` | Codex failed or returned no final message. | Preserve the runner error. Confirm the external Codex setup required by your environment, then retry. | A valid final message is received. | `.\scripts\Run-Review.ps1 -DryRun` |
| `WIN-TRB-005` | Exit `5` | The target changed, output failed the report contract, a secret was detected, findings were inconsistent, or the finding limit was exceeded. | Do not treat the run as a report. Inspect the error and `git status`; restore the target if it changed, then rerun with a valid prompt and safe scope. | The run completes with consistent artifacts. | `git status --porcelain` |
| `WIN-TRB-006` | Exit `6` | The review exceeded its timeout. | Increase `-TimeoutSeconds` or narrow `include_paths` in `config/review-config.yaml`. | The review completes before the limit. | `.\scripts\Run-Review.ps1 -DryRun -TimeoutSeconds 1800` |
| `WIN-TRB-007` | Exit `7` | The final message exceeded `-MaxOutputBytes`. | Narrow `include_paths` or choose a larger limit of at least 1024 bytes. | Output fits the configured limit. | `.\scripts\Run-Review.ps1 -DryRun -MaxOutputBytes 10485760` |

## Diagnostic logging

To preserve redacted runner diagnostics for a real run, pass a path that resolves
beneath the harness root. It may be absolute or relative:

```powershell
.\scripts\Run-Review.ps1 -DiagnosticLogPath reports\diagnostics\review.log
```

The log records target resolution, dry-run preparation, the redacted Codex
console transcript, failures, and successful artifact paths. Review it before
sharing it; redaction is a safeguard, not a substitute for secret management.

## Update, cleanup, and rollback

Before updating the harness, preserve any configuration changes you need from
`config/review-config.yaml` and any report artifacts you want to retain. Use
Git history to update or roll back the harness repository. The local runner
does not provide its own update command.

To clean up managed specialist files, use `scripts/Remove-AgentPack.ps1` with
`-DryRun` first. Its `-RestoreLatest` option restores the most recent managed
backup when one exists. See [Agent pack](../modules/agent-pack.md).

## Next steps

- Read [Usage](../USAGE.md) for review flows.
- Read [Safety model](../modules/safety-model.md) before changing scope.
- Use [Troubleshooting](../TROUBLESHOOTING.md) for the full source-derived
  failure reference.
