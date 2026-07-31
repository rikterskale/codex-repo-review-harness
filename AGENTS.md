# AGENTS.md – Instructions for Codex

This file is read by Codex before every task. Keep it short and actionable.

## Project overview
This repository uses the **Codex Repo Review Harness**.
All reviews must stay **read-only by default**. Never modify source files unless a human explicitly asks for a write-enabled session.

## Working agreements
- Prefer small, focused changes.
- Run existing tests before claiming work is done (when write mode is allowed).
- Document public API changes.

## Code Review Rules

### Secrets and credentials
- Never commit real secrets, API keys, tokens, or private keys.
- Flag any hard-coded credential as **critical**.
- Prefer environment variables or a secrets manager.

### Error handling
- Public entry points must not swallow errors silently.
- Prefer structured errors over bare strings when the language supports it.

### Testing
- New logic should have corresponding tests.
- Avoid tests that only assert the mock was called; prefer behavior assertions.

### Dependencies
- Do not add new runtime dependencies without justification in the PR description.
- Prefer the standard library or already-present packages.

### File size and complexity
- Functions longer than ~80 lines or files longer than ~500 lines should be flagged for potential splitting (medium severity unless they are generated).

### Logging
- Do not log secrets, passwords, or full payment payloads.
- Prefer structured logging where the project already uses it.

## Review harness notes
When asked to perform a repository review, load the prompts under `prompts/` and the settings in `config/review-config.yaml`.
Always confirm the sandbox is read-only before starting.
