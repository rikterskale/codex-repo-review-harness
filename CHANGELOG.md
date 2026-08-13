# Changelog

All notable changes to this project are documented here.

## [Unreleased]

## [0.2.0] - 2026-08-13

Every defect the novice guides recorded against 0.1.0 is fixed in this release,
and the guides now say so rather than carrying an old version number. The three
user-facing ones — a dry run that refused to run without the tool it exists to
avoid, a validator that told Linux users to run a Windows command, and a report
that printed its title twice — are covered by
`tests/test_novice_defect_regressions.ps1`.

### Fixed

- `-DryRun` no longer requires the Codex CLI. The prerequisite ran before the
  dry-run branch, so the one switch that exists to check a setup *before*
  installing Codex could not run without it (`REV-UX-001`). Git is still
  required, because a dry run resolves the repository and builds the manifest.
- `Validate-Harness.ps1` reads the platform at runtime and prints Git and Codex
  hints that apply to it. On Linux it printed a Windows PowerShell installer the
  reader could not act on; it now points at OpenAI's own instructions rather
  than inventing a command (`REV-DOC-005`).
- The report title is written once. The harness header and the model's report
  each supplied it, so every artifact opened with two identical H1 lines. The
  model's copy is stripped after the contract checks, leaving the header that
  carries the timestamp, base branch, and sandbox mode (`REV-DOC-004`).
- The runner sets the working directory explicitly inside its background job, so
  Codex reviews the intended repository rather than the shell's default. Windows
  PowerShell 5.1 does not give background jobs the caller's directory, which
  made reviews analyse the user's Documents folder (`REV-COR-001`). Code-derived:
  the tests substitute a synthetic Codex that ignores its working directory, so
  no test covers this.
- The secret detector no longer matches the harness's own redaction placeholder,
  which discarded any report that quoted a credential (`REV-COR-002`).
- The Markdown and JSON reports are filtered to the same finding set and checked
  against each other before either is written, instead of the JSON silently
  holding fewer findings than the Markdown (`REV-COR-004`).

### Changed

- Replaced the prose release-readiness table with twelve numbered requirements,
  each stating an exact pass condition and the gate that decides it, in
  `docs/RELEASE_READINESS_STANDARD.md`.
- Made `Test-ReleaseReadiness.ps1` parse `ci.yml` into steps instead of matching
  substrings. A gate that is deleted, demoted to a comment, made
  `continue-on-error`, made conditional, or dropped from one half of the OS
  matrix now fails the readiness check.
- Derived the documented runner exit codes from `Run-Review.ps1` itself, and
  required each one to reach a troubleshooting row with both a corrective action
  and a verification command in both novice guides. A new `Fail` path now fails
  CI until it is documented.
- Added the clean-room installation gate as its own named CI step, and named
  every readiness step after the requirement it proves.
- Rewrote `test_release_readiness.ps1` as a mutation test: it breaks each
  requirement in a copy of the tree and requires the gate to reject it.
- Added an on-demand `workflow_dispatch` trigger to the Codex review workflow so
  a commit that reached `main` without a pull request can still be reviewed. It
  takes a `ref` and a range `base`, collects the diff with `git diff` instead of
  `gh pr diff`, and publishes to the job summary because no pull request exists
  to comment on. Dispatch inputs reach the script through `env:` and are
  constrained to plain revisions: interpolating them into a `run:` body would
  let a value shaped like a shell command or a git flag execute as one.
  `Validate-WorkflowPolicy.ps1` now enforces all of that, and
  `test_workflow_preflight.ps1` breaks each rule to prove it is enforced.
- Dropped the branch-protection clause from RR-10. Branch protection is
  unavailable on this repository, so requiring `analyze` as a status check was a
  rule nobody could satisfy. RR-10 now asserts only that the job exists, and
  RR-12 records that a human reading the commit's checks is the only thing
  catching a red `analyze`.
- Corrected the Linux guide, which still claimed three test scripts fail on
  Linux with `The term 'powershell' is not recognized` and that the review runner
  had never run there. Both stopped being true; findings `REV-TEST-002` and
  `REV-CI-001` are closed and `REV-COMPAT-001` narrowed to the Codex CLI.
- Pinned the CI review sandbox to `read-only` through the Codex action's
  `sandbox` input. Selecting it through `codex-args` was silently overridden by
  the action's `workspace-write` default.
- Added a credential preflight so a missing `OPENAI_API_KEY` secret fails with a
  message naming it, rather than an unrelated error raised inside the action
  several steps later.

## [0.1.0] - 2026-07-31

- Initial review harness release.
- Added split, least-privilege Codex review workflows and report contracts.
