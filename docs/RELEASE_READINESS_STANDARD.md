# New-user release-readiness standard

A release is eligible only when the evidence below is current for the release
candidate. Source coverage is supporting evidence, never the release decision by
itself. Every automated row is a separately named, required CI gate on both
Windows and Ubuntu; a passing aggregate test run or coverage percentage cannot
substitute for it.

## Required release evidence

| Outcome | Required proof | Automated gate |
| --- | --- | --- |
| Proven installation | Clean temporary user environment validates the harness and installs the managed pack without elevated rights. | `test_new_user_journey.ps1` |
| First successful review | A separate Git target is reviewed with a deterministic Codex substitute; Markdown, JSON, and SHA-256 artifacts exist. | `test_new_user_journey.ps1` |
| Full feature set | Full, security, and PR-diff prompts; central target review; artifact contract; zero findings and structured findings are exercised. | `test_runner_failure.ps1`, `test_review_artifacts.ps1` |
| Target safety | Target Git status is unchanged before and after review. | `test_new_user_journey.ps1` |
| Guided troubleshooting | Every stable runner exit code has an exact corrective action and verification command in the novice guides. | `test_release_readiness.ps1` |
| Recovery | Tampered prompts are rejected; repeated installation preserves a backup; removal restores only manifest-owned files and preserves unrelated agents. | `test_recovery_paths.ps1` |
| Documentation | Windows and Linux novice guides, a release digest, update, uninstall, and rollback instructions match the current harness. | `test_guide_digest.ps1`, `Validate-Release.ps1` |
| Cross-platform support | The whole suite passes on Windows and Ubuntu. | GitHub Actions matrix |
| Independent review | The read-only GitHub review workflow completes successfully. | Required `analyze` check |

## Human release checklist

Before publishing, a maintainer must additionally perform one real-Codex smoke
test using an authorized non-sensitive repository: install/sign in, run a
read-only review, inspect the file paths and artifacts, and confirm the target
is unchanged. CI deliberately uses a synthetic Codex command and cannot prove
an individual account's entitlement, sign-in, billing, or service availability.

Do not release when a critical or high supported finding is unresolved, a
required GitHub check is absent, or any row in the table lacks current evidence.

## CI enforcement

The CI workflow must visibly run and require these gates: clean installation and
first review, complete feature validation, recovery and safe removal, and
troubleshooting plus release-documentation verification. `Test-ReleaseReadiness`
fails if any of their evidence scripts are removed from CI. The source-coverage
gate remains supplemental and must never be treated as approval to release.
