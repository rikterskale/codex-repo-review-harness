# Documentation lifecycle review checklist

This repository-local checklist is based on the maintainer-provided
**Documentation Lifecycle Review Prompt v2.2**. Use it when planning or
auditing documentation work. It is a review procedure, not evidence that a
particular command, platform, or integration works.

## Evidence rules

- Treat implemented behavior, tests, configuration, and recorded release
  evidence as the repository's source of truth.
- Record each material claim as: claim, `path:line` evidence, confidence
  (`confirmed`, `partially confirmed`, or `unverified`), and validation basis
  (`locally verified`, `static-only`, or `requires external validation`).
- When evidence is missing, use exactly
  `[VERIFY: <specific missing information>]` and state what would resolve it.
- Do not call an environment, installation method, command, example, rendered
  page, or integration supported or live-verified without relevant evidence.
- Keep external validation separate from static repository inspection.

## Stage 0: reconnaissance

Complete this read-only stage before proposing edits.

1. Inventory repository shape, languages, build/test systems, entry points,
   public surfaces, configuration, workflows, and documentation tooling.
2. Map public commands, options, defaults, configuration, environment
   variables, schemas, errors, and exit behavior to `path:line` evidence.
3. Extract confirmed metadata and explicitly separate unknown metadata.
4. Create a documentation-scope manifest covering every user- or
   developer-facing artifact, its audience, source, maintenance status, and
   disposition.
5. Map each public surface and user journey to authoritative source and
   existing documentation; record gaps, duplication, and contradictions.
6. Inspect Git history only for historical claims that require it.
7. Assess foundations, installation, first use, reference, engineering, and
   operations coverage as applicable.
8. Assess each evidenced novice journey: prerequisites, installation,
   verification, first useful task, expected result, and recovery.
9. Assess navigation, internal links, accessibility, freshness, and the
   available documentation checks.
10. Propose only a bounded, evidence-backed change set.

End the reconnaissance report with exactly: `✅ Recon complete`.

## Stage 1: proposal and approval

Before editing, present a table for every proposed file:

| File | Action | Evidence (`path:line`) | Audience impact | Intended outcome | Acceptance criteria |
| --- | --- | --- | --- | --- | --- |

Distinguish mandatory accuracy fixes from recommended improvements. List every
remaining `[VERIFY]` item and all external-validation work. Obtain explicit
maintainer approval before changing any existing non-empty documentation file.

## Stage 2: approved writing

- Edit only approved documentation scope and preserve generated-file,
  licensing, and accessibility boundaries.
- Use progressive disclosure: a concise quick path, a guided path with
  verification and recovery, and concise reference material where applicable.
- Keep tutorials, how-tos, reference, and explanation distinct and linked.
- Give commands their shell, prerequisites, expected result, and safe recovery
  when those details are evidenced.
- After each approved file, record:
  `✅ <path> — <one-line summary> — [N VERIFY tags remaining]`.

## Stage 3: exhaustive read-only audit

Audit every documentation-scope-manifest item from first line to last.

1. Classify each item as factual claim, procedure, reference, example,
   navigation, visual, or historical claim.
2. Verify it against the mapped source and record `path:line` evidence.
3. Log inaccurate, incomplete, ambiguous, outdated, inconsistent,
   inaccessible, or unverifiable material.
4. Validate commands against entry points and test sources; validate
   configuration, versions, paths, schemas, and internal links against the
   repository.
5. Give every manifest item exactly one disposition: `fully verified`,
   `contains discrepancies`, `unverifiable`, or `excluded` with a reason.
6. Perform a second pass against the checklist and public-surface map. Propose
   corrections separately; do not edit during this audit.

## Completion record

For a completed lifecycle review, retain a concise report and verification
ledger containing the scope manifest, public-surface map, gap assessment,
novice-journey matrix, discrepancy log, unresolved `[VERIFY]` items,
external-validation work, and the disposition of every manifest item.

The review is complete only when reconnaissance, proposal and approval,
approved writing, and audit occurred in order; edited claims are confirmed or
carry the exact verification marker; and remaining limits are stated.
