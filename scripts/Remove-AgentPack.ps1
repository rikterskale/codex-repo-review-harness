#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$DestinationRoot = (Join-Path $env:USERPROFILE '.codex'),
    [switch]$DryRun,
    [switch]$RestoreLatest
)

$ErrorActionPreference = 'Stop'
$HarnessRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$manifest = Get-Content -LiteralPath (Join-Path $HarnessRoot 'agents\manifest.json') -Raw | ConvertFrom-Json
if ($manifest.schema_version -ne 1 -or [string]::IsNullOrWhiteSpace($manifest.installation_root)) { throw 'Managed agent-pack removal refused: invalid manifest.' }
$installRoot = Join-Path $DestinationRoot $manifest.installation_root
if (-not (Test-Path -LiteralPath $installRoot)) { Write-Host "Managed pack is not installed: $installRoot"; exit 0 }
$files = foreach ($agent in @($manifest.agents)) { foreach ($relative in @($agent.source, $agent.codex_config)) { Join-Path $installRoot ($relative -replace '^agents[\\/]','') } }
foreach ($file in $files) { if (Test-Path -LiteralPath $file) { Write-Host "REMOVE: $file" } }
$backupRoot = Join-Path $installRoot 'backups'
$latestBackup = if (Test-Path -LiteralPath $backupRoot) { Get-ChildItem -LiteralPath $backupRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1 } else { $null }
if ($RestoreLatest -and -not $latestBackup) { throw 'No managed-agent backup is available to restore.' }
if ($RestoreLatest) { Write-Host "RESTORE: $($latestBackup.FullName)" }
if ($DryRun) { Write-Host 'Dry run complete; no files were changed.'; exit 0 }
foreach ($file in $files) { if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force } }
if ($RestoreLatest) { Get-ChildItem -LiteralPath $latestBackup.FullName -Recurse -File | ForEach-Object { $relative = $_.FullName.Substring($latestBackup.FullName.Length).TrimStart('\\'); $destination = Join-Path $installRoot $relative; New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null; Copy-Item -LiteralPath $_.FullName -Destination $destination -Force } }
$logDir = Join-Path $installRoot 'logs'; New-Item -ItemType Directory -Path $logDir -Force | Out-Null
[pscustomobject]@{ removed_at = (Get-Date).ToUniversalTime().ToString('o'); restored_backup = if ($latestBackup) { $latestBackup.FullName } else { '' }; files = $files } | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $logDir ("remove-" + (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '.json')) -Encoding UTF8
Write-Host 'Removed only manifest-owned managed-agent files.'
