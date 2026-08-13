# Installation

## Requirements

The local review runner requires:

- Windows PowerShell 5.1 or a compatible PowerShell runtime;
- Git available on `PATH`; and
- the `codex` command available on `PATH` for a real review.

`-DryRun` does not invoke Codex, but it still requires Git because the runner
resolves the target repository and builds its review manifest.

`[VERIFY: the current Codex CLI installation, authentication, account, and
service requirements for your environment.]`

## Verify the harness

From the repository root, run:

```powershell
.\scripts\Validate-Harness.ps1
```

The validator checks for required harness files, Git, Codex, a read-only
configuration, a base branch setting, and the `reports/` directory. It exits
`0` when all checks pass and `1` when any check fails.

## Verify without Codex

To confirm that the target and configuration can be resolved without invoking
Codex, run:

```powershell
.\scripts\Run-Review.ps1 -DryRun
```

The dry run prints the prepared prompt length, timeout, and output limit. It
does not write the final report artifacts.

## Managed specialist pack

The optional managed agent pack installs under an absolute destination root;
the default is `$env:USERPROFILE\.codex`.

```powershell
.\scripts\Install-AgentPack.ps1 -DryRun
.\scripts\Install-AgentPack.ps1
.\scripts\Validate-Integrations.ps1
```

See [Agent pack](modules/agent-pack.md) for ownership, backup, and removal
behavior.
