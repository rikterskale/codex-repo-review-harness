# Examples

## Prepare a review without invoking Codex

```powershell
.\scripts\Run-Review.ps1 -DryRun
```

## Review the harness itself

```powershell
.\scripts\Run-Review.ps1
```

## Review another local Git repository

```powershell
.\scripts\Run-Review.ps1 -RepositoryPath C:\path\to\target-repository
```

## Use the security-focused prompt

```powershell
.\scripts\Run-Review.ps1 -Prompt security-focus.md
```

## Use the change-focused prompt

```powershell
.\scripts\Run-Review.ps1 -Prompt pr-diff-review.md
```

## Preview managed-pack installation

```powershell
.\scripts\Install-AgentPack.ps1 -DryRun
```

## Validate the installed managed pack

```powershell
.\scripts\Validate-Integrations.ps1
```
