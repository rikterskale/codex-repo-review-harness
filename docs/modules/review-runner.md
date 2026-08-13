# Review runner

`scripts/Run-Review.ps1` is the local review entry point. It reads
`config/review-config.yaml`, selects a contained prompt file from `prompts/`, and creates
`review-input/review-manifest.txt` from the configured target's Git-visible
files.

For real runs, the script starts `codex exec` with `--sandbox read-only`,
`--color never`, and an output-last-message file. It sends the assembled prompt
on standard input. It does not accept a sandbox option.

Before and after the Codex invocation, it compares `git status --porcelain` for
the target repository. A difference fails the run with exit code `5`.

See [CLI reference](../CLI_REFERENCE.md) for parameters and exit codes.
