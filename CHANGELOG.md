# Changelog

All notable changes to this project are documented here.

## [Unreleased]

- Pinned the CI review sandbox to `read-only` through the Codex action's
  `sandbox` input. Selecting it through `codex-args` was silently overridden by
  the action's `workspace-write` default.
- Added a credential preflight so a missing `OPENAI_API_KEY` secret fails with a
  message naming it, rather than an unrelated error raised inside the action
  several steps later.

## [0.1.0] - 2026-07-31

- Initial review harness release.
- Added split, least-privilege Codex review workflows and report contracts.
