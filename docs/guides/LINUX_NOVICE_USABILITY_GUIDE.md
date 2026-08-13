---
guide_id: linux-novice-usability
guide_schema_version: 1
platform: linux
canonical_path: docs/guides/LINUX_NOVICE_USABILITY_GUIDE.md
project_name: "Codex Repo Review Harness"
target_release: "0.2.0 (tagged v0.2.0)"
reviewed_digest: "87313b1e4c50f5aa80de427739c648926c93c7efa91292619661fe448e9600e3"
support_status: native_supported_with_external_codex_setup
validation_status: partially_verified
validated_on: 2026-08-13
maintainer_source_of_truth: "README.md, AGENTS.md, config/review-config.yaml, scripts/Run-Review.ps1, .github/workflows/ci.yml"
known_limitations:
  - "The project CI verifies Ubuntu only. Debian and Kali are not CI-tested by this project."
---

# Linux novice guide

This is the concise, source-verified Linux guide for release 0.2.0, released
on 2026-08-13. The `reviewed_digest` records the harness surface this guide was
checked against.

## Linux support boundary

The CI workflow runs the harness checks on `ubuntu-latest` with PowerShell 7.
This repository's CI evidence remains Ubuntu-only; Debian and Kali are not
CI-tested by this project.

## What the harness does

The local runner builds a file manifest for a Git repository, sends a review
prompt to Codex with a forced `read-only` sandbox, and compares the target Git
status before and after the run. A successful run writes `review.md`,
`review.json`, and `review.sha256` beneath `reports/` in the harness repository.

The runner does not apply, approve, or merge changes. Review only repositories
you are authorized to inspect, and do not place real credentials in prompts or
reports.

## Verify the local harness

Run the PowerShell scripts with PowerShell 7 (`pwsh`):

```bash
pwsh -NoProfile -File scripts/Validate-Harness.ps1
pwsh -NoProfile -File scripts/Run-Review.ps1 -DryRun
```

The dry run requires Git but does not invoke Codex. It resolves the target,
configuration, prompt, and review manifest, then prints preparation details.

## Install Git and Codex on Debian, Ubuntu, or Kali

Install Git with the distribution package manager:

```bash
sudo apt install git
```

OpenAI's [Codex CLI documentation](https://developers.openai.com/codex/cli/)
documents its standalone installer for Linux:

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

Open a project directory and run `codex`. On the first run, select **Sign in
with ChatGPT** or another sign-in method offered by the CLI. This project does
not verify account eligibility or service availability. Its CI evidence remains
Ubuntu-only; Debian and Kali are not CI-tested by this project.

Confirm the commands are available before starting a real harness review:

```bash
git --version
codex --version
```

## When Codex is already available

If your environment already provides the external `codex` command, the runner
uses the same interface as on Windows:

```bash
pwsh -NoProfile -File scripts/Run-Review.ps1
pwsh -NoProfile -File scripts/Run-Review.ps1 -RepositoryPath /path/to/target-repository
pwsh -NoProfile -File scripts/Run-Review.ps1 -Prompt security-focus.md
```

For a guided local interface, run:

```bash
pwsh -NoProfile -File scripts/Start-ReviewWizard.ps1
```

It selects existing runner settings, previews the command, and requires you to
type `REVIEW` before a real read-only review starts.

Successful artifacts are written under:

```text
reports/<target-name>/<timestamp>-<run-id>/
```

## Exit codes

| Code | Meaning | Troubleshooting |
| --- | --- | --- |
| `0` | Successful review or dry run | `LNX-TRB-001` |
| `2` | Usage or configuration problem | `LNX-TRB-002` |
| `3` | Missing prerequisite | `LNX-TRB-003` |
| `4` | Codex failure or no final message | `LNX-TRB-004` |
| `5` | Contract, secret-detection, consistency, or target-change failure | `LNX-TRB-005` |
| `6` | Timeout | `LNX-TRB-006` |
| `7` | Output-size limit | `LNX-TRB-009` |

## Troubleshooting

| ID | Symptom | Likely cause | Exact corrective steps | Expected result | Verification command |
| --- | --- | --- | --- | --- | --- |
| `LNX-TRB-001` | Exit `0` | The operation completed. | Open the printed `review.md` path after a real run, or use dry-run output to confirm preparation. | Report paths or prepared-review message are shown. | `find reports -type f` |
| `LNX-TRB-002` | Exit `2` | Invalid option value, configuration, prompt, or output directory. | Read the error; restore a prompt beneath `prompts/`, use a positive timeout, use an output limit of at least 1024, and keep `report.output_dir` relative. | The runner starts or completes. | `pwsh -NoProfile -File scripts/Run-Review.ps1 -DryRun` |
| `LNX-TRB-003` | Exit `3` | Git, Codex, or a Git repository is unavailable. | Confirm Git first. For a real run, make the `codex` command available. Use a Git repository or pass `-RepositoryPath` to one. | The prerequisite error is gone. | `git --version` |
| `LNX-TRB-004` | Exit `4` | Codex failed or returned no final message. | Preserve the runner error. Confirm the external Codex setup required by your environment, then retry. | A valid final message is received. | `pwsh -NoProfile -File scripts/Run-Review.ps1 -DryRun` |
| `LNX-TRB-005` | Exit `5` | The target changed, output failed the report contract, a secret was detected, findings were inconsistent, or the finding limit was exceeded. | Do not treat the run as a report. Inspect the error and `git status`; restore the target if it changed, then rerun with a valid prompt and safe scope. | The run completes with consistent artifacts. | `git status --porcelain` |
| `LNX-TRB-006` | Exit `6` | The review exceeded its timeout. | Increase `-TimeoutSeconds` or narrow `include_paths` in `config/review-config.yaml`. | The review completes before the limit. | `pwsh -NoProfile -File scripts/Run-Review.ps1 -DryRun -TimeoutSeconds 1800` |
| `LNX-TRB-009` | Exit `7` | The final message exceeded `-MaxOutputBytes`. | Narrow `include_paths` or choose a larger limit of at least 1024 bytes. | Output fits the configured limit. | `pwsh -NoProfile -File scripts/Run-Review.ps1 -DryRun -MaxOutputBytes 10485760` |

## Update, cleanup, and rollback

Before updating the harness, preserve any configuration changes you need from
`config/review-config.yaml` and any report artifacts you want to retain. Use
Git history to update or roll back the harness repository. The local runner
does not provide its own update command.

To clean up managed specialist files, use `scripts/Remove-AgentPack.ps1` with
`-DryRun` first. Its `-RestoreLatest` option restores the most recent managed
backup when one exists. See [Agent pack](../modules/agent-pack.md).

## Diagnostic logging

Pass `-DiagnosticLogPath` to preserve redacted runner diagnostics. The path may
be absolute or relative, but it must resolve beneath the harness root.

```bash
pwsh -NoProfile -File scripts/Run-Review.ps1 \
  -DiagnosticLogPath reports/diagnostics/review.log
```

The log records target resolution, dry-run preparation, the redacted Codex
console transcript, failure messages, and successful artifact paths. Do not
share a log until you have reviewed it; redaction is a safeguard, not a
substitute for secret management.

## Next steps

- Read [Usage](../USAGE.md) for review flows.
- Read [Safety model](../modules/safety-model.md) before changing scope.
- Use [Troubleshooting](../TROUBLESHOOTING.md) for the full source-derived
  failure reference.
