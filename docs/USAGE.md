# Usage

## Run the default review

```powershell
.\scripts\Run-Review.ps1
```

The default prompt is `prompts/system-review.md`. The runner creates a bounded
manifest of Git-tracked and unignored files, applies configured include/exclude
patterns, and refuses an empty scope.

## Review another local repository

```powershell
.\scripts\Run-Review.ps1 -RepositoryPath C:\path\to\target-repository
```

Artifacts remain under this harness's `reports/` directory. The target must be
inside a Git repository. Its status is compared before and after the review.

## Select a bundled prompt

```powershell
.\scripts\Run-Review.ps1 -Prompt security-focus.md
.\scripts\Run-Review.ps1 -Prompt pr-diff-review.md
```

The security prompt emphasizes secrets, injection, authorization, unsafe
deserialization, input validation, dependency patterns, and sensitive logging.
The PR-diff prompt asks for issues introduced or worsened by a change.

## Capture diagnostics

Use `-DiagnosticLogPath` to retain redacted runner diagnostics for a real run.
The path may be absolute or relative, but must resolve beneath the harness root:

```powershell
.\scripts\Run-Review.ps1 -DiagnosticLogPath reports\diagnostics\review.log
```

Review the log before sharing it; redaction is a safeguard, not a substitute for
secret management.

## Restrict the review scope

Edit `config/review-config.yaml` to set `include_paths` or `exclude_paths`.
Patterns are evaluated against paths found by Git; the default empty include
list means all candidate paths are included, subject to exclusions.

## Inspect results

On success, the runner prints three paths beneath:

```text
reports/<target-name>/<timestamp>-<run-id>/
```

They are `review.md`, `review.json`, and `review.sha256`. See
[Reports](modules/reports.md) for their contents and integrity data.
