# Codex Repo Review Harness

**Tested, read-only-by-default repository review harness for the `codex` command.**

This project gives you:

- Clear **configuration** (`config/review-config.yaml`)
- Ready-to-use **prompts** for full, security, and PR-style reviews
- Permanent **Code Review Rules** via `AGENTS.md`
- **Validation** and **runner** scripts (Windows PowerShell first)
- Timestamped **reports** that never touch your source code
- A complete **beginner-friendly Windows guide** (start from zero computer knowledge)
- Cross-platform CI validation and a split, least-privilege PR review pipeline

## Why this exists

Codex already has excellent built-in review capabilities (`/review`, `codex exec`, sandbox modes, AGENTS.md rules).  
What this harness adds is a **repeatable, documented, safe-by-default workflow** so that:

1. Local reviews are forced to the `read-only` sandbox, including when the
   configuration requests another sandbox.
2. The same prompts and severity rules are used every time.
3. Non-experts can follow exact click-by-click steps on Windows.
4. Results are saved as durable Markdown reports inside the repository.

## Quick start (experienced users)

```powershell
# 1. Obtain this harness from the repository URL below.
git clone https://github.com/rikterskale/codex-repo-review-harness.git
Set-Location codex-repo-review-harness

# 2. Install Git and make the external `codex` command available through your
#    approved platform process.
# 3. Validate
.\scripts\Validate-Harness.ps1

# 4. Run a read-only review
.\scripts\Run-Review.ps1
```

Reports appear under `reports/`. To review a separate local Git repository while
keeping artifacts in this trusted harness, pass `-RepositoryPath`:

```powershell
.\scripts\Run-Review.ps1 -RepositoryPath C:\path\to\target-repository
```

The target's Git status is compared before and after the read-only review; a
change fails the run. The optional governed specialist pack, integration pins,
and install/remove tooling are documented in
[the integration guide](docs/SUPERPOWERS_AGENCY_INTEGRATION.md).

Before publishing or adopting the harness, use the enforceable
[new-user release-readiness standard](docs/RELEASE_READINESS_STANDARD.md). It
requires clean installation, first-review, recovery, documentation, and
cross-platform evidence in addition to source coverage.

## Absolute beginners

Open the file:

**Platform guides:** [Windows novice guide](docs/guides/WINDOWS_NOVICE_USABILITY_GUIDE.md) · [Linux novice guide](docs/guides/LINUX_NOVICE_USABILITY_GUIDE.md)

The older [Windows beginner guide](docs/WINDOWS_BEGINNER_GUIDE.md) remains available as a short orientation guide.

It starts from installing Git and walks through every single step.

## Safety model

| Setting | Value | Meaning |
|---------|-------|---------|
| Default sandbox | `read-only` | Codex cannot create, edit, or delete source files |
| Generated artifacts | `reports/<target>/<timestamp>-<run-id>/` | Successful local reviews write `review.md`, `review.json`, and `review.sha256` here |
| Review manifest | `review-input/review-manifest.txt` | The local runner writes the bounded file list here before invoking Codex |
| Config enforcement | Script forces read-only | Even if you edit the YAML, the runner overrides to safe mode |

## Repository layout

```
├── AGENTS.md                     # Permanent instructions + Code Review Rules
├── config/
│   └── review-config.yaml        # Base branch, focus areas, severity, etc.
├── prompts/
│   ├── system-review.md          # Full structured review
│   ├── security-focus.md         # Security-first pass
│   └── pr-diff-review.md         # Change-focused review
├── scripts/
│   ├── Run-Review.ps1            # Main Windows entry point
│   └── Validate-Harness.ps1      # Health check
├── reports/                      # Generated reports land here
├── templates/
│   └── report-skeleton.md
├── tests/
│   └── test_harness_structure.ps1
├── docs/
│   ├── guides/
│   │   ├── WINDOWS_NOVICE_USABILITY_GUIDE.md
│   │   └── LINUX_NOVICE_USABILITY_GUIDE.md
│   └── WINDOWS_BEGINNER_GUIDE.md # Short orientation guide
└── .github/workflows/
    └── codex-review.yml          # Optional CI template
```

## Testing the harness itself

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/test_harness_structure.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Validate-Harness.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ci/Test-ReportContract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/test_security_regressions.ps1
```

These checks do not require an active Codex authentication and verify that the files and safety defaults are correct.

Every script in this repository declares `#Requires -Version 5.1` and runs on the
**Windows PowerShell 5.1** that ships with Windows 10 and 11. PowerShell 7
(`pwsh`) is **optional**: it is not installed by default on Windows, and no
command in this README needs it. If you do have it, substitute `pwsh -NoProfile`
for `powershell -NoProfile -ExecutionPolicy Bypass` anywhere below — PowerShell 7
handles non-ASCII characters in reports more reliably. The GitHub Actions
workflows use `pwsh` because the hosted runners already provide it.

To run the full self-test suite:

```powershell
Get-ChildItem tests\test_*.ps1 | ForEach-Object {
  powershell -NoProfile -ExecutionPolicy Bypass -File $_.FullName
  "{0,-40} exit={1}" -f $_.Name, $LASTEXITCODE
}
```

## Guide freshness

The canonical novice guides in `docs/guides/` record a `reviewed_digest`: a hash
of the harness surface they make claims about, namely `scripts/`, `tests/`,
`schemas/`, `config/`, `prompts/`, the workflows, `AGENTS.md`, `README.md`, and
`VERSION`. Tests and schemas are included because the guides cite them by name
and by line number. If you change any of those, `Validate-Release.ps1` fails
until the guides are re-read against the change and the digest is re-recorded:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ci/Update-GuideDigest.ps1
```

The guides are deliberately excluded from their own digest, so a guide edit and
its new digest belong in the same commit. Templates and the changelog do not
move the digest: the guides mention them only inside directory listings, so a
change inside one cannot falsify a claim.

## GitHub Actions

The repository has two separate review workflows. `Codex Read-Only Review` runs
trusted base-branch code with read-only GitHub permissions and treats the PR diff
as untrusted data. `Publish Codex Review` is triggered by `workflow_run` and is
the only workflow allowed to write a PR conversation comment. All actions are
pinned to immutable commit SHAs, jobs have timeouts and cancellation, and review
artifacts include Markdown, JSON, and SHA-256 manifests.

The analysis workflow requires an `OPENAI_API_KEY` repository secret. Do not
enable it until the repository owner has reviewed the trust boundary and has
configured the secret. Fork pull requests are analyzed by the trusted base
workflow; PR source code is never checked out or executed by that workflow.

A credential preflight runs before the workflow invokes Codex. It receives only
whether `OPENAI_API_KEY` is set, never its value. The workflow sets the Codex
action's `sandbox` input to `read-only` and does not set a sandbox through
`codex-args`.

## Report contract and exit codes

Reports follow `schemas/review-report.schema.json`. The local runner writes
Markdown, JSON, and SHA-256 files to
`<report.output_dir>/<target-name>/<timestamp>-<run-id>/`. It also writes the
review manifest to `review-input/review-manifest.txt` before the review starts.
The JSON artifact contains parsed findings and uses `passed` when no findings
are present or `findings` when findings are present. Its deterministic exit
codes are: `0` success, `2` usage/configuration, `3` prerequisite, `4` Codex
failure, `5` contract failure, `6` timeout, and `7` output-size limit.

## Customization

1. Edit `config/review-config.yaml` for base branch and focus areas.
2. Add or tighten rules under `## Code Review Rules` in `AGENTS.md`.
3. Create new prompt files in `prompts/` and pass them with `-Prompt yourfile.md`.

## Scope

This repository documents its own PowerShell runner, prompts, configuration,
tests, and workflow files. External installation, authentication, account, and
service requirements are outside this repository's source of truth.

## License

Apache-2.0. Use freely.

---

**Start here if you are new to computers or the command line:**  
→ [Windows novice guide](docs/guides/WINDOWS_NOVICE_USABILITY_GUIDE.md) · [Linux novice guide](docs/guides/LINUX_NOVICE_USABILITY_GUIDE.md)
