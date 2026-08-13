# New-user release-readiness standard

A release is eligible only when every requirement below holds for the release
candidate. Each requirement states an **exact pass condition** — something that
is either true or false about this tree — and names the gate that decides it.

Source coverage is supporting evidence and never the release decision. A release
candidate with 100% coverage and a failing requirement below is not releasable.

`scripts/ci/Test-ReleaseReadiness.ps1` enforces every requirement marked
*Automated*. It reads `.github/workflows/ci.yml` structurally, so a gate that is
deleted, renamed away from its evidence script, made `continue-on-error`, or made
conditional fails the readiness check itself.

## RR-01 — Proven installation (Automated)

**Pass condition.** A temporary directory that has never held the harness runs
`Validate-Harness.ps1`, `Install-AgentPack.ps1`, and `Validate-Integrations.ps1`
to exit 0 with no elevated rights and no pre-existing Codex home.

**Gate.** `tests/test_new_user_journey.ps1`, run as its own CI step.

## RR-02 — First successful review (Automated)

**Pass condition.** A Git repository *other than* the harness is reviewed end to
end against a deterministic Codex substitute, exits 0, and leaves exactly one
`review.md`, one `review.json`, and one `review.sha256` under `reports/`.

**Gate.** `tests/test_new_user_journey.ps1`.

## RR-03 — Target safety (Automated)

**Pass condition.** `git status --porcelain` of the reviewed repository is
byte-identical before and after the review.

**Gate.** `tests/test_new_user_journey.ps1`.

## RR-04 — Clean-room installation and upgrade (Automated)

**Pass condition.** A copy of the tree with no `.git`, no `reports/`, and no
review state passes structural validation and release validation.

**Gate.** `tests/test_clean_room.ps1`, run as its own CI step.

## RR-05 — Full user-facing feature set (Automated)

**Pass condition.** Every feature a new user can reach is exercised: the full,
security, and PR-diff prompts; a review of a central target; the artifact
contract; the zero-findings and structured-findings paths; and each runner
failure mode.

**Gate.** `tests/test_runner_failure.ps1`, `tests/test_review_artifacts.ps1`,
and `tests/test_security_regressions.ps1`, run as their own CI step.

## RR-06 — Tested recovery paths (Automated)

**Pass condition.** A tampered manifest-owned prompt is rejected before
installation; a repeated installation preserves a restorable backup;
`Remove-AgentPack.ps1 -RestoreLatest` restores that backup and leaves every file
the manifest does not own untouched.

**Gate.** `tests/test_recovery_paths.ps1`, run as its own CI step.

## RR-07 — Guided troubleshooting for every failure the user can hit (Automated)

**Pass condition.** For every stable exit code the runner can return — the set is
read out of `scripts/Run-Review.ps1`, not hard-coded — both novice guides:

1. list the code in an exit-code table,
2. point that row at one or more troubleshooting rows by ID, and
3. give each of those rows a non-empty corrective action **and** a non-empty
   verification command the user can run to confirm the fix worked.

Adding a new `Fail <code>` to the runner therefore fails CI until both guides
document it.

**Gate.** `scripts/ci/Test-ReleaseReadiness.ps1`.

## RR-08 — Documentation that resolves against this tree (Automated)

**Pass condition.** Both novice guides carry a `validation_status`, name the
current `VERSION` and its dated `CHANGELOG.md` entry, and record a
`reviewed_digest` equal to the digest of the harness surface they describe. Every
repository path either guide cites in backticks exists. Update, uninstall, and
rollback instructions are present.

**Gate.** `tests/test_guide_digest.ps1`, `scripts/ci/Validate-Release.ps1`, and
`scripts/ci/Test-ReleaseReadiness.ps1`.

## RR-09 — Cross-platform evidence (Automated)

**Pass condition.** The CI matrix for the validation job contains both
`windows-latest` and `ubuntu-latest`, and every gate above runs on both. Evidence
from one platform never stands in for the other.

**Gate.** `scripts/ci/Test-ReleaseReadiness.ps1` asserts the matrix; GitHub
Actions produces the evidence.

## RR-10 — Independent review workflow (Automated)

**Pass condition.** `.github/workflows/codex-review.yml` defines the read-only
`analyze` job.

**Gate.** `scripts/ci/Test-ReleaseReadiness.ps1`.

**Deliberate gap.** This requirement does *not* ask for `analyze` to be a
required status check. Branch protection is unavailable on this repository
today, so requiring it would be a rule nobody could satisfy. The cost is real
and worth stating plainly: nothing blocks a merge while `analyze` is red, and a
direct push to `main` triggers no review at all. RR-12 is what catches that, and
it is a human reading the commit's checks, not a rule enforcing them. Restore
the branch-protection clause here as soon as protection becomes available.

**Reviewing a commit that skipped the pull-request path.** `analyze` also runs
on demand, so a change already on `main` can still be reviewed:

```bash
gh workflow run codex-review.yml -f ref=main -f base=HEAD~1
```

The result lands in the run's job summary and the `codex-review` artifact —
there is no pull request to comment on. This is a tool, not a guarantee: it runs
only when someone remembers, which is why the gap above stands as written.

## RR-11 — Real-Codex smoke test (Human, not automatable)

**Pass condition.** A maintainer installs the harness on a clean machine, signs
in to a real Codex account, runs one read-only review of an authorized
non-sensitive repository, opens the generated report, and confirms the target is
unchanged.

CI uses a synthetic Codex command on purpose. It cannot prove an account's
entitlement, sign-in, billing, or the service being reachable, so this
requirement stays human. Record the date, harness version, and repository used.

## RR-12 — No unresolved blocking findings (Human)

**Pass condition.** No supported critical or high finding is open, and the
`analyze` check is present and green on the release commit.

Open the release commit on GitHub and look at its checks. Because RR-10 no
longer requires `analyze` as a status check, a red or missing `analyze` will not
have stopped anything on its own — this reading is the only thing that catches
it.

## Coverage is supplemental

`scripts/ci/Test-SourceCoverage.ps1` runs at 100% and stays a required step, but
it answers "is every production source file exercised", not "can a new user
succeed". It must never be presented as release approval, and readiness
enforcement fails if the requirement gates above are removed while coverage
remains.

## Release decision

Release only when RR-01 through RR-10 are green on the release commit for both
platforms, and RR-11 and RR-12 are recorded by a maintainer. Any single failing
requirement blocks the release; there is no aggregate score that overrides one.
