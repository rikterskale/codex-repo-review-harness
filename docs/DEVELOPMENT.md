# Development

## Local checks

Run targeted checks while changing the harness. The following checks are
available without a real Codex session:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/test_harness_structure.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Validate-Harness.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ci/Test-ReportContract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/test_security_regressions.ps1
```

To run every regression test, use the README's test-discovery command. CI runs
the tests on `windows-latest` and `ubuntu-latest` and also checks production
source coverage, release readiness, and PowerShell syntax.

## Documentation maintenance

When a documented harness-surface file changes, update the canonical novice
guide digests and validate them as described in `CONTRIBUTING.md`.

## Release evidence

`VERSION` must contain SemVer, and `CHANGELOG.md` must contain a matching
release entry. `scripts/ci/Validate-Release.ps1` enforces both conditions and
checks the guide digest.

## Boundaries

Do not add runtime dependencies without justification. Keep public entry-point
errors visible, avoid logging secrets, and preserve the local runner's
read-only target-review boundary.
