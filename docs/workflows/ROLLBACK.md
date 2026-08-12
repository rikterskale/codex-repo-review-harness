# Rollback

Preview managed-agent removal with `scripts/Remove-AgentPack.ps1 -DryRun`.
Removal affects only files owned by `agents/manifest.json`; use `-RestoreLatest`
to restore the latest backup. Revert a failed integration pull request through
GitHub rather than rewriting history, and preserve reports and evidence.
