# Troubleshooting

## `Git is not installed or not on PATH.` — exit `3`

Install Git through your approved platform process, open a new shell, and run
`git --version`. The runner also returns exit `3` when its target is not inside
a Git repository.

## `Codex CLI is not installed or not on PATH.` — exit `3`

Install or expose the `codex` command, then open a new shell and run
`codex --version`. A dry run does not require Codex.

## `Prompt file not found` — exit `2`

Pass a filename that exists beneath `prompts/`; escaping paths are rejected. For example:

```powershell
.\scripts\Run-Review.ps1 -Prompt system-review.md
```

## Timeout — exit `6`

The default is 900 seconds. Increase it for one run with a positive value:

```powershell
.\scripts\Run-Review.ps1 -TimeoutSeconds 1800
```

## Output-size limit — exit `7`

The default limit is 5,242,880 bytes. Narrow `include_paths` in the
configuration or set a larger `-MaxOutputBytes` value of at least 1024.

## Contract or target-change failure — exit `5`

This code covers malformed output, inconsistent findings, detected secrets in
the generated report, too many findings, and a changed target Git status.
Preserve the error message, inspect `git status --porcelain` in the target, and
do not treat a failed run as a report.

## Capture runner diagnostics

Pass `-DiagnosticLogPath` to write redacted runner diagnostics. The path may be
absolute or relative, but it must resolve beneath the harness root:

```powershell
.\scripts\Run-Review.ps1 -DiagnosticLogPath reports\diagnostics\review.log
```

The log records target resolution, dry-run preparation, the redacted Codex
console transcript, failures, and successful artifact paths. Review it before
sharing it; redaction is a safeguard, not a substitute for secret management.

## Agent-pack installation or removal is refused

Use `-DryRun` first. The scripts reject malformed manifests, unsafe paths,
checksum mismatches, and non-absolute destination roots. Run
`scripts/Validate-Integrations.ps1` after installation.
