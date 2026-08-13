# Windows beginner guide

This short guide is an orientation for running the Codex Repo Review Harness on
Windows. For the step-by-step guide, troubleshooting matrix, and validation
record, use the [Windows novice guide](guides/WINDOWS_NOVICE_USABILITY_GUIDE.md).

## What this repository does

The harness assembles a bounded list of repository files, sends a review prompt
to Codex with the `read-only` sandbox, and verifies that the reviewed Git
repository's status did not change. A successful local run writes a Markdown
report, a JSON report, and a SHA-256 manifest beneath `reports/`. It also writes
the bounded file list to `review-input/review-manifest.txt`.

The local runner does not approve changes or execute them. A report is advice
for a human to assess.

## Before you start

- Use Windows PowerShell 5.1 or PowerShell 7.
- Install Git and the Codex CLI, then open a new PowerShell window so their
  commands are available.
- Work inside a Git repository you are authorized to review.
- Keep the harness files in their own trusted repository when reviewing another
  local repository with `-RepositoryPath`.

Use your approved platform process to make the external `codex` command available.
This repository does not establish current Codex account, authentication, or
service requirements.

## First review

From the harness root, validate the installation:

```powershell
.\scripts\Validate-Harness.ps1
```

Then run the default review:

```powershell
.\scripts\Run-Review.ps1
```

The runner requires Git and, except for `-DryRun`, the `codex` command. It uses
`system-review.md` by default, applies the configured `base_branch` unless you
pass `-BaseBranch`, and forces the Codex sandbox to `read-only`.

On success, PowerShell prints the precise paths of:

```text
reports\<target-name>\<timestamp>-<run-id>\review.md
reports\<target-name>\<timestamp>-<run-id>\review.json
reports\<target-name>\<timestamp>-<run-id>\review.sha256
```

Open the Markdown report with the path printed by the runner. The `.sha256`
file contains hashes for the Markdown and JSON artifacts.

## Useful options

```powershell
# Prepare the bounded prompt without invoking Codex.
.\scripts\Run-Review.ps1 -DryRun

# Review another local Git repository while retaining artifacts in this harness.
.\scripts\Run-Review.ps1 -RepositoryPath C:\path\to\target-repository

# Use one of the bundled alternative prompts.
.\scripts\Run-Review.ps1 -Prompt security-focus.md
.\scripts\Run-Review.ps1 -Prompt pr-diff-review.md

# Override the configured base branch for one run.
.\scripts\Run-Review.ps1 -BaseBranch develop
```

`-TimeoutSeconds` defaults to `900`; `-MaxOutputBytes` defaults to `5242880`.
Both values are checked by the runner: the timeout must be positive, and the
output limit must be at least `1024` bytes.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Successful review or dry run |
| `2` | Usage or configuration problem |
| `3` | Missing prerequisite, including Git or (for a real run) Codex |
| `4` | Codex failed or produced no final message |
| `5` | Report contract, consistency, secret-detection, or target-change failure |
| `6` | Review timed out |
| `7` | Final message exceeded `-MaxOutputBytes` |

For exact corrective steps, use the troubleshooting matrix in the canonical
[Windows novice guide](guides/WINDOWS_NOVICE_USABILITY_GUIDE.md).

## Safety notes

Do not change `sandbox: read-only` in `config/review-config.yaml` as a way to
make this runner write-enabled: `Run-Review.ps1` warns and still forces
`read-only`. Review only repositories you are authorized to inspect, and do not
place secrets in prompts or reports.

## Next steps

- Adjust scope, severity, and report limits in `config/review-config.yaml`.
- Add repository-specific review rules under `## Code Review Rules` in
  `AGENTS.md`.
- Read the [README](../README.md) for testing, CI, report-contract, and managed
  integration documentation.
