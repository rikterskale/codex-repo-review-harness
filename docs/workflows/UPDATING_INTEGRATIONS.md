# Updating integrations

Use a dedicated pull request. Review the upstream diff, update only the explicit
pin in `config/integrations.lock.json`, manually review adapted prompts,
recompute manifest checksums, run the integration tests, and verify pilot
repositories. Do not enable automatic updates.
