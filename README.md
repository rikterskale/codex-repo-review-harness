# Codex Repo Review Harness

**Tested, read-only-by-default repository review harness for OpenAI Codex CLI.**

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

1. Reviews are always read-only unless you deliberately change the setting.
2. The same prompts and severity rules are used every time.
3. Non-experts can follow exact click-by-click steps on Windows.
4. Results are saved as durable Markdown reports inside the repository.

## Quick start (experienced users)

```powershell
# 1. Install Codex (Windows)
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"

# 2. Clone or copy this harness into your repository root
# 3. Validate
.\scripts\Validate-Harness.ps1

# 4. Run a read-only review
.\scripts\Run-Review.ps1
```

Reports appear under `reports/`.

## Absolute beginners

Open the file:

**[docs/WINDOWS_BEGINNER_GUIDE.md](docs/WINDOWS_BEGINNER_GUIDE.md)**

It starts from installing Git and walks through every single step.

## Safety model

| Setting | Value | Meaning |
|---------|-------|---------|
| Default sandbox | `read-only` | Codex cannot create, edit, or delete source files |
| Report location | `reports/` | Only place the harness writes |
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
│   └── WINDOWS_BEGINNER_GUIDE.md # The detailed beginner guide
└── .github/workflows/
    └── codex-review.yml          # Optional CI template
```

## Testing the harness itself

```powershell
powershell -File tests/test_harness_structure.ps1
.\scripts\Validate-Harness.ps1
pwsh -NoProfile -File scripts/ci/Test-ReportContract.ps1
pwsh -NoProfile -File tests/test_security_regressions.ps1
```

These checks do not require an active Codex authentication and verify that the files and safety defaults are correct.

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

## Report contract and exit codes

Reports follow `schemas/review-report.schema.json`. The local runner writes
Markdown, JSON, and SHA-256 files to the configured nested `report.output_dir`.
The JSON artifact contains parsed findings and uses `passed` when no findings
are present or `findings` when findings are present. Its deterministic exit
codes are: `0` success, `2` usage/configuration, `3` prerequisite, `4` Codex
failure, `5` contract failure, `6` timeout, and `7` output-size limit.

## Customization

1. Edit `config/review-config.yaml` for base branch and focus areas.
2. Add or tighten rules under `## Code Review Rules` in `AGENTS.md`.
3. Create new prompt files in `prompts/` and pass them with `-Prompt yourfile.md`.

## Relation to official Codex features

This harness deliberately builds on the current Codex workflow (as of mid-2026):

- Official Windows installer
- `codex exec` non-interactive mode
- Sandbox modes (`read-only` preferred)
- `AGENTS.md` + `## Code Review Rules` for custom guidance
- Compatibility with future official GitHub Actions / cloud review

It does **not** replace Codex; it packages a safe, repeatable way to use it for repository reviews.

## License

Apache-2.0 (same spirit as the official Codex CLI). Use freely.

---

**Start here if you are new to computers or the command line:**  
→ [docs/WINDOWS_BEGINNER_GUIDE.md](docs/WINDOWS_BEGINNER_GUIDE.md)
