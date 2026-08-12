# Rikter managed specialist pack

This is a locally governed, read-only pack inspired by the pinned
[`msitarzewski/agency-agents`](https://github.com/msitarzewski/agency-agents)
revision recorded in `config/integrations.lock.json`. It is not an upstream
distribution and contains no upstream prompt text verbatim. Local adaptations
remove write authority and predetermined findings, require structured evidence,
and defer to repository policy.

Install only with `scripts/Install-AgentPack.ps1`; validate with
`scripts/Validate-Integrations.ps1`. The manifest is the ownership boundary for
installation and removal.
