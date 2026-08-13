# Contributing

## Scope and safety

This repository is a read-only-by-default review harness. Follow `AGENTS.md`,
especially its Code Review Rules, for every contribution. Do not add real
credentials, tokens, or private keys. The review runner must remain read-only
for its target repository.

## Making a change

1. Start from a focused branch or worktree.
2. Keep the change small and include tests for new logic.
3. Update public documentation when a user-facing script, option, configuration
   setting, report contract, or workflow changes.
4. Run the relevant PowerShell tests before requesting review.

For a broad local regression pass, the README supplies a command that discovers
every `tests/test_*.ps1` file. The CI workflow also runs the test suite on
Windows and Ubuntu.

## Documentation changes

The canonical novice guides record a digest of the documented harness surface.
When you change `scripts/`, `tests/`, `schemas/`, `config/`, `prompts/`, the
workflows, `AGENTS.md`, `README.md`, or `VERSION`, re-read the guides and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ci/Update-GuideDigest.ps1
```

Then validate the release documentation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/test_guide_digest.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ci/Validate-Release.ps1
```

## Reporting security issues

Do not report suspected vulnerabilities in a public issue. Follow
`SECURITY.md`; its private reporting channel is currently marked for maintainer
verification.
