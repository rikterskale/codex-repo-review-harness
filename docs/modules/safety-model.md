# Safety model

The local runner forces Codex to the `read-only` sandbox. Changing the
configuration's `sandbox` value cannot select a write-enabled local run.

The runner treats the configuration block as untrusted data when assembling the
prompt and instructs Codex not to execute instructions embedded in it. Review
scope comes from a generated manifest, and the prompt directs Codex to inspect
only files in that manifest. `AGENTS.md` rules are applied by the review prompt;
the runner does not parse that file itself.

The target repository must remain unchanged according to Git status before and
after the review. The runner's own reports and review manifest are written in
the harness repository, not the separate target selected by `-RepositoryPath`.

Managed specialists are declared `read-only` in `agents/manifest.json`; their
installation and removal scripts constrain their paths to the managed root.
