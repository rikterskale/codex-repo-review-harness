#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$DestinationRoot = (Join-Path $env:USERPROFILE '.codex'),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$HarnessRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$manifestPath = Join-Path $HarnessRoot 'agents\manifest.json'

function Fail([string]$Message) { throw "Managed agent-pack installation refused: $Message" }
function Get-Manifest() {
    if (-not (Test-Path -LiteralPath $manifestPath)) { Fail "missing manifest: $manifestPath" }
    try { $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json } catch { Fail "invalid manifest: $($_.Exception.Message)" }
    if ($manifest.schema_version -ne 1 -or [string]::IsNullOrWhiteSpace($manifest.installation_root) -or @($manifest.agents).Count -eq 0) { Fail 'manifest is incomplete.' }
    $names = @($manifest.agents | ForEach-Object { [string]$_.name })
    if (($names | Select-Object -Unique).Count -ne $names.Count -or @($names | Where-Object { $_ -notmatch '^rikter_[a-z0-9_]+$' }).Count) { Fail 'agent names are not unique managed names.' }
    foreach ($agent in @($manifest.agents)) {
        if ($agent.permission_mode -ne 'read-only' -or -not $agent.source -or -not $agent.codex_config -or $agent.sha256 -notmatch '^[a-f0-9]{64}$') { Fail "invalid entry: $($agent.name)" }
        foreach ($relative in @($agent.source, $agent.codex_config)) {
            if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)') { Fail "unsafe manifest path: $relative" }
            if (-not (Test-Path -LiteralPath (Join-Path $HarnessRoot $relative))) { Fail "missing manifest file: $relative" }
        }
        $actual = (Get-FileHash -LiteralPath (Join-Path $HarnessRoot $agent.source) -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $agent.sha256) { Fail "checksum mismatch: $($agent.source)" }
    }
    return $manifest
}

$manifest = Get-Manifest
if ([string]::IsNullOrWhiteSpace($DestinationRoot) -or -not [IO.Path]::IsPathRooted($DestinationRoot)) { Fail 'DestinationRoot must be an absolute path.' }
$installRoot = Join-Path $DestinationRoot $manifest.installation_root
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$backupRoot = Join-Path $installRoot (Join-Path 'backups' $stamp)
$actions = @()
foreach ($agent in @($manifest.agents)) {
    foreach ($relative in @($agent.source, $agent.codex_config)) {
        $source = Join-Path $HarnessRoot $relative
        $destination = Join-Path $installRoot ($relative -replace '^agents[\\/]','')
        $actions += [pscustomobject]@{ Source = $source; Destination = $destination; Backup = (Join-Path $backupRoot ($relative -replace '^agents[\\/]','')) }
    }
}
foreach ($action in $actions) { Write-Host "INSTALL: $($action.Source) -> $($action.Destination)" }
if ($DryRun) { Write-Host 'Dry run complete; no files were changed.'; exit 0 }

foreach ($action in $actions) {
    $dir = Split-Path -Parent $action.Destination
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path -LiteralPath $action.Destination) {
        $backupDir = Split-Path -Parent $action.Backup
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        Copy-Item -LiteralPath $action.Destination -Destination $action.Backup -Force
    }
    Copy-Item -LiteralPath $action.Source -Destination $action.Destination -Force
}
$logDir = Join-Path $installRoot 'logs'; New-Item -ItemType Directory -Path $logDir -Force | Out-Null
[pscustomobject]@{ installed_at = (Get-Date).ToUniversalTime().ToString('o'); manifest = $manifestPath; backup = $backupRoot; files = @($actions | ForEach-Object { $_.Destination }) } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $logDir "install-$stamp.json") -Encoding UTF8
Write-Host "Installed managed agent pack to $installRoot"
