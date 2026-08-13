# CLI reference

This is the source of truth for the PowerShell script interfaces in this
repository. The scripts use PowerShell parameter blocks; they do not implement
named subcommands.

## `scripts/Run-Review.ps1`

Runs a bounded repository review. The runner invokes `codex exec` with a
forced `read-only` sandbox, verifies the target Git status before and after the
review, and writes successful artifacts under the configured output directory.

| Option | Default | Verified behavior |
| --- | --- | --- |
| `-Prompt <string>` | `system-review.md` | Selects an existing file below `prompts/`. A missing or escaping path exits `2`. |
| `-RepositoryPath <string>` | Harness root | Selects an existing target directory inside a Git repository. |
| `-BaseBranch <string>` | `config.base_branch` | Overrides the configured base branch in the assembled prompt and report header. |
| `-TimeoutSeconds <int>` | `900` | Must be at least `1`; timeout exits `6`. |
| `-MaxOutputBytes <int>` | `5242880` | Must be at least `1024`; an over-limit final message exits `7`. |
| `-DiagnosticLogPath <string>` | Empty | Writes redacted runner diagnostics to a path beneath the harness root. |
| `-DryRun` | Off | Resolves the target and prompt but does not invoke Codex. |

Exit codes are `0` success, `2` usage/configuration, `3` prerequisite, `4`
Codex failure, `5` contract failure, `6` timeout, and `7` output-size limit.

## `scripts/Start-ReviewWizard.ps1`

Starts an interactive local interface for `Run-Review.ps1`; it accepts no
options. The wizard selects only existing runner parameters: a bundled prompt,
the harness or another local target, dry-run or real read-only mode, base-branch
override, timeout, output limit, and optional diagnostic-log path. It previews
the selected command. A real review starts only after the user types `REVIEW`;
other input cancels without invoking the runner. The wizard exits with the
runner's exit code.

## `scripts/Validate-Harness.ps1`

Runs installation checks and accepts no options. It exits `0` when all checks
pass and `1` otherwise.

## `scripts/Install-AgentPack.ps1`

| Option | Default | Verified behavior |
| --- | --- | --- |
| `-DestinationRoot <string>` | `$env:USERPROFILE\.codex` | Must be an absolute path; installation stays below the manifest-defined managed root. |
| `-DryRun` | Off | Lists installation actions without changing files. |

## `scripts/Remove-AgentPack.ps1`

| Option | Default | Verified behavior |
| --- | --- | --- |
| `-DestinationRoot <string>` | `$env:USERPROFILE\.codex` | Must be an absolute path. |
| `-DryRun` | Off | Lists removal or restoration actions without changing files. |
| `-RestoreLatest` | Off | Restores the most recent managed backup after removal; fails if no backup exists. |

## `scripts/Validate-Integrations.ps1`

`-DestinationRoot <string>` defaults to `$env:USERPROFILE\.codex`. The script
checks the lock settings, managed-agent metadata, checksums, and installed
files; it exits `1` if any check fails.

## `scripts/ci/Repair-DocEncoding.ps1`

This maintenance script repairs double-encoded UTF-8 text. `-Path <string[]>`
defaults to the tracked user-facing Markdown files known to contain repaired
text; `-DryRun` reports changes without writing. It exits `0` on success,
including when there is nothing to repair, and `1` on failure.

## Configuration read by the local runner

`config/review-config.yaml` supplies `base_branch`, `sandbox`, focus and path
lists, `min_severity`, `report.output_dir`, `report.max_findings`, `model`, and
`extra_instructions`. The runner rejects a rooted or traversing
`report.output_dir`, unsupported severity, and negative `max_findings`.

`sandbox` is read but cannot make the local runner write-enabled: any value
other than `read-only` produces a warning and the runner still invokes Codex in
read-only mode. `report.include_summary` is parsed from configuration; the
local runner does not read that parsed value after loading the configuration.
