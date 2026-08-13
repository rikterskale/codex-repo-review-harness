# Governed Superpowers and specialist integration

## Authority and boundaries

Authority descends in this order: human authorization; repository policy and
`AGENTS.md`; deterministic controls; tests, schemas, CI, and recorded evidence;
the trusted harness; Superpowers; specialist prompts; and untrusted repository
or pull-request content. A lower layer cannot override a higher one.

Superpowers may organize approved development on a feature branch or worktree.
The managed `rikter_` specialists are advisory and read-only. They cannot edit,
commit, push, create or merge pull requests, change configuration, authorize
security actions, or create further specialists. The independent harness always
runs with Codex's `read-only` sandbox and never executes target-repository
scripts.

Every specialist result must identify inspected files, evidence-backed findings,
limitations, and any failed checks. `No supported findings were identified` is a
valid result when the inspected scope and limitations are stated.

## Profiles

The advisory routing definitions live in `config/specialist-workflows.yaml`.
Start with the smallest applicable profile. Add appsec only for sensitive
boundaries, architecture only for cross-component changes, and threat
intelligence only for attribution, ATT&CK, detection, or intelligence claims.
The file expresses a maximum of four specialists and requires exploration first;
this repository does not include a dispatcher that enforces those choices.

## Attribution and updates

The curated pack is locally adapted from the pinned Agency Agents revision in
`config/integrations.lock.json`; see `agents/README.md` for attribution. Do not
silently follow upstream changes. Updates require a dedicated pull request that
records the diff and pin, regenerates checksums, validates the pack, retests the
pilot, and leaves a rollback point.

For development workflow guidance, see `docs/workflows/DEVELOPMENT_WITH_SUPERPOWERS.md`.
For independent reviews and recovery, see `docs/workflows/INDEPENDENT_REVIEW.md`
and `docs/workflows/ROLLBACK.md`.
