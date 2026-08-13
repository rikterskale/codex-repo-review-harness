# Architecture

The harness is a PowerShell-first repository review system.

```mermaid
flowchart LR
  C[config/review-config.yaml] --> R[scripts/Run-Review.ps1]
  P[prompts/*.md] --> R
  A[AGENTS.md] --> R
  R --> M[review-input/review-manifest.txt]
  R --> X[Codex exec: read-only]
  X --> R
  R --> O[reports/<target>/<run>/review.{md,json,sha256}]
```

`scripts/ci/Review-Helpers.ps1` provides configuration parsing, manifest
selection, report validation, finding parsing, filtering, consistency checks,
and guide-digest helpers. Tests under `tests/` exercise the runner, artifacts,
configuration parsing, agent-pack behavior, and release-readiness checks.

GitHub workflow files provide a separate CI validation workflow, a read-only
review-analysis workflow, and a publishing workflow for review comments.
