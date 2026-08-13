# Frequently asked questions

## Can this local runner be made write-enabled through configuration?

No. `Run-Review.ps1` forces `read-only` even if the configuration specifies a
different sandbox value.

## Where are local reports written?

Below `<report.output_dir>/<target-name>/<timestamp>-<run-id>/` in the harness
repository. The default output directory is `reports`.

## What does `-DryRun` do?

It resolves the target, reads configuration and prompt files, builds the review
manifest and assembled prompt, then exits without invoking Codex.

## Does a report mean a change is approved?

No. The runner produces review artifacts; it does not apply, approve, or merge
changes.

## Can I review a separate local repository?

Yes. Pass its path using `-RepositoryPath`. It must be inside a Git repository,
and the runner compares its Git status before and after the review.

## How do I remove the managed agent pack?

Run `scripts/Remove-AgentPack.ps1`. Use `-DryRun` to preview the manifest-owned
files and `-RestoreLatest` only when a managed backup is available.
