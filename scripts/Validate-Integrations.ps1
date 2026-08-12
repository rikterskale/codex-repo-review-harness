#Requires -Version 5.1
[CmdletBinding()]
param([string]$DestinationRoot = (Join-Path $env:USERPROFILE '.codex'))

$ErrorActionPreference = 'Stop'
$HarnessRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$failed = 0
function Check([string]$Name, [bool]$Condition, [string]$Hint) { if ($Condition) { Write-Host "[PASS] $Name" } else { Write-Host "[FAIL] $Name - $Hint"; $script:failed++ } }
function Get-CanonicalSha256([string]$Path) {
    $text = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($Path))
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    $text = $text -replace "`r`n", "`n"
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($text); return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
$lockPath = Join-Path $HarnessRoot 'config\integrations.lock.json'
$manifestPath = Join-Path $HarnessRoot 'agents\manifest.json'
try { $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json; $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json } catch { throw "Cannot validate integrations: $($_.Exception.Message)" }
Check 'Codex is installed' ($null -ne (Get-Command codex -ErrorAction SilentlyContinue)) 'Install Codex before using managed agents.'
Check 'Integration lock has pinned updates disabled' (($lock.superpowers.automatic_updates_allowed -eq $false) -and ($lock.agency_agents.automatic_updates_allowed -eq $false)) 'Set automatic_updates_allowed to false.'
Check 'Harness sandbox is read-only' (($lock.review_harness.sandbox -eq 'read-only') -and ((Get-Content -LiteralPath (Join-Path $HarnessRoot 'config\review-config.yaml') -Raw) -match '(?m)^sandbox:\s*read-only')) 'Restore read-only sandbox settings.'
$names = @($manifest.agents | ForEach-Object { [string]$_.name })
Check 'Managed names are unique and prefixed' (($names.Count -eq 8) -and (($names | Select-Object -Unique).Count -eq $names.Count) -and (@($names | Where-Object { $_ -notmatch '^rikter_[a-z0-9_]+$' }).Count -eq 0)) 'Use eight unique rikter_ names.'
Check 'All specialists are read-only' (@($manifest.agents | Where-Object { $_.permission_mode -ne 'read-only' }).Count -eq 0) 'Set every permission_mode to read-only.'
Check 'Attribution is present' ((Test-Path -LiteralPath (Join-Path $HarnessRoot 'agents\README.md')) -and ((Get-Content -LiteralPath (Join-Path $HarnessRoot 'agents\README.md') -Raw) -match 'agency-agents')) 'Restore attribution notice.'
$installRoot = Join-Path $DestinationRoot $manifest.installation_root
Check 'Managed agent directory exists' (Test-Path -LiteralPath $installRoot) "Run scripts\\Install-AgentPack.ps1 or pass -DestinationRoot."
$writable = $false
if (Test-Path -LiteralPath $DestinationRoot) { try { $writable = $true; [IO.Directory]::GetFiles($DestinationRoot) | Out-Null } catch { $writable = $false } }
Check 'Personal Codex directory is accessible' $writable "Ensure the current user can access $DestinationRoot."
foreach ($agent in @($manifest.agents)) {
    $source = Join-Path $HarnessRoot $agent.source
    $expected = [string]$agent.sha256
    $actual = if (Test-Path -LiteralPath $source) { Get-CanonicalSha256 $source } else { '' }
    Check "Checksum: $($agent.name)" ($actual -eq $expected) 'Restore the reviewed source or regenerate the manifest through an update PR.'
    if (Test-Path -LiteralPath $installRoot) { foreach ($relative in @($agent.source, $agent.codex_config)) { Check "Installed: $relative" (Test-Path -LiteralPath (Join-Path $installRoot ($relative -replace '^agents[\\/]',''))) 'Run the installer.' } }
}
if ($failed) { exit 1 }; Write-Host 'All governed integration checks passed.'
