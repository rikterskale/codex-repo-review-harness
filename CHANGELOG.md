# Changelog

All notable changes to this project are documented here.

## [0.2.1] - 2026-08-13

### Documentation

- Refreshed the source-verified documentation set, including the CLI reference,
  installation, usage, troubleshooting, contributor, and architecture guides.
- Added the repository-local documentation lifecycle review checklist.
- Recorded post-release readiness evidence on 2026-08-13. A real Codex CLI
  v0.147.0 read-only review of this repository at harness commit `3d58e4d`
  completed and left the target Git status unchanged. This was a workstation
  smoke test, not new clean-machine evidence. GitHub also recorded a successful
  `analyze` job for the `v0.2.0` release commit `75da840`:
  https://github.com/rikterskale/codex-repo-review-harness/actions/runs/31753090434
  GitHub returned no open issues at the time of the check.

### Fixed

- A failed or timed-out review now compares the target Git status before it
  exits. A target change is reported as exit code `5`, which takes precedence
  over the original Codex failure or timeout (`9ae675d`).
- The temporary Codex final-message file is removed after every review outcome,
  including timeout (`9ae675d`).
- The release-readiness gate now derives deferred runner exit codes as well as
  literal `Fail` calls, so all documented stable codes remain audited
  (`b26a4c7`).

## [0.2.0] - 2026-08-13

RR-11 (real-Codex smoke test) satisfied on 2026-08-13: harness 0.2.0, reviewed
`codex-repo-review-harness` with Codex CLI v0.147.0 on Windows 11. The review
completed, wrote all three artifacts, produced evidence-backed findings against
real files, and left the target unchanged. It found `REV-SEC-001` and
`REV-DOC-006`, both fixed below.

Every defect the novice guides recorded against 0.1.0 is fixed in this release,
and the guides now say so rather than carrying an old version number. The three
user-facing ones — a dry run that refused to run without the tool it exists to
avoid, a validator that told Linux users to run a Windows command, and a report
that printed its title twice — are covered by
`tests/test_novice_defect_regressions.ps1`.

### Security

- **Manifest paths can no longer escape the managed agent-pack directory.**
  `Install-AgentPack.ps1` validated `agent.source` and `agent.codex_config` for
  rooted and `..` values but never `installation_root`, which decides where
  every other path lands. `Remove-AgentPack.ps1` validated nothing beyond the
  schema version and then passed its derived paths straight to `Remove-Item`, so
  an edited manifest could delete arbitrary files. Both scripts now reject
  rooted, drive-qualified, and traversing manifest values, and canonicalise every
  computed destination and require it to resolve under the managed-pack root
  (`REV-SEC-001`). Covered by `tests/test_agent_pack_traversal.ps1`, which also
  asserts a file outside the destination root survives each attempt.

  Found by the first real-Codex review of this repository — the same smoke test
  that RR-11 requires.

### Fixed

- **Guides no longer pin commit SHAs or cite source line numbers.** The front
  matter named one commit and the body another, and both guides cited
  `Run-Review.ps1` lines 79-80 for the read-only sandbox long after that code
  had moved. Freshness is tracked by `reviewed_digest`, so a commit SHA can only
  go stale or contradict it; citations now name parameters and behaviour instead
  of line numbers. `Test-ReleaseReadiness.ps1` rejects both from now on
  (`REV-DOC-006`).
- **The report is Codex's final message, not its console output.** The runner
  captured everything Codex printed and wrote it into the artifact as the
  review: the startup banner, the entire prompt echoed back including the
  untrusted config block, tool-call transcripts, sandbox error logs, and ANSI
  escapes. Reviews now come from `--output-last-message`, with `--color never`
  keeping escapes out of both streams, and a leading byte-order mark is
  tolerated (`REV-COR-007`).
- **Fixed the duplicate-title strip.** It removed the first title found anywhere
  in the captured text. Against a real transcript that was the copy inside the
  echoed prompt template, so it deleted a line out of the quoted prompt and left
  both real titles standing. It is now anchored to the start of the message.
- **The prompt is sent to Codex on stdin, not as an argument.** Windows
  PowerShell 5.1 does not escape embedded double quotes when it builds a native
  command line, so the quoted phrase in `prompts/system-review.md` split the
  prompt into fragments and Codex rejected them with
  `unexpected argument 'Code' found`. A quote in a user's own
  `extra_instructions` would have done the same. Sending the prompt on stdin
  also removes the ~32,000-character Windows command-line limit, which the
  assembled prompt was growing towards (`REV-COR-006`).
- **Real reviews work again.** The runner passed Codex no arguments at all, so
  every real review launched the interactive TUI inside a background job and
  died with `Error: stdin is not a terminal`. The job's first parameter was
  named `$Args`, a PowerShell automatic variable that cannot be bound, so it
  arrived empty and `@Args` splatted nothing. Broken since `Start-Job` was
  introduced; found by the first real-Codex smoke test (`REV-COR-005`).
  `tests/test_runner_failure.ps1` now uses a synthetic Codex that rejects a
  wrong invocation, and pins `exec --sandbox read-only` at the call site.
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
