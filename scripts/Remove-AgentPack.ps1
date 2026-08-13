#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$DestinationRoot = (Join-Path $env:USERPROFILE '.codex'),
    [switch]$DryRun,
    [switch]$RestoreLatest
)

$ErrorActionPreference = 'Stop'
$HarnessRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
. (Join-Path $HarnessRoot 'scripts\ci\Review-Helpers.ps1')
function Fail([string]$Message) { throw "Managed agent-pack removal refused: $Message" }
$manifest = Get-Content -LiteralPath (Join-Path $HarnessRoot 'agents\manifest.json') -Raw | ConvertFrom-Json
if ($manifest.schema_version -ne 1 -or [string]::IsNullOrWhiteSpace($manifest.installation_root)) { Fail 'invalid manifest.' }
# This script deletes files, so it validates the manifest at least as strictly
# as the installer does. Previously it checked only schema_version and that
# installation_root was non-empty, then passed every derived path straight to
# Remove-Item, so an edited manifest could delete arbitrary files.
if (-not [IO.Path]::IsPathRooted($DestinationRoot)) { Fail 'DestinationRoot must be an absolute path.' }
try { Assert-ManagedRelativePath ([string]$manifest.installation_root) 'installation_root' } catch { Fail $_.Exception.Message }
try { $installRoot = Resolve-ContainedPath $DestinationRoot (Join-Path $DestinationRoot $manifest.installation_root) 'installation_root' } catch { Fail $_.Exception.Message }
if (-not (Test-Path -LiteralPath $installRoot)) { Write-Host "Managed pack is not installed: $installRoot"; exit 0 }
$files = foreach ($agent in @($manifest.agents)) {
  foreach ($relative in @($agent.source, $agent.codex_config)) {
    $trimmed = [string]$relative -replace '^agents[\\/]',''
    try {
      Assert-ManagedRelativePath $trimmed "agent path ($relative)"
      Resolve-ContainedPath $installRoot (Join-Path $installRoot $trimmed) "agent path ($relative)"
    } catch { Fail $_.Exception.Message }
  }
}
foreach ($file in $files) { if (Test-Path -LiteralPath $file) { Write-Host "REMOVE: $file" } }
$backupRoot = Join-Path $installRoot 'backups'
$latestBackup = if (Test-Path -LiteralPath $backupRoot) { Get-ChildItem -LiteralPath $backupRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1 } else { $null }
if ($RestoreLatest -and -not $latestBackup) { throw 'No managed-agent backup is available to restore.' }
if ($RestoreLatest) { Write-Host "RESTORE: $($latestBackup.FullName)" }
if ($DryRun) { Write-Host 'Dry run complete; no files were changed.'; exit 0 }
foreach ($file in $files) { if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force } }
if ($RestoreLatest) {
  Get-ChildItem -LiteralPath $latestBackup.FullName -Recurse -File | ForEach-Object {
    # Trims both separators: on Linux the leading character is '/', so trimming
    # only backslashes left the relative path rooted.
    $relative = $_.FullName.Substring($latestBackup.FullName.Length).TrimStart('\', '/')
    $destination = Resolve-ContainedPath $installRoot (Join-Path $installRoot $relative) "restored file ($relative)"
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $destination -Force
  }
}
$logDir = Join-Path $installRoot 'logs'; New-Item -ItemType Directory -Path $logDir -Force | Out-Null
[pscustomobject]@{ removed_at = (Get-Date).ToUniversalTime().ToString('o'); restored_backup = if ($latestBackup) { $latestBackup.FullName } else { '' }; files = $files } | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $logDir ("remove-" + (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '.json')) -Encoding UTF8
Write-Host 'Removed only manifest-owned managed-agent files.'
