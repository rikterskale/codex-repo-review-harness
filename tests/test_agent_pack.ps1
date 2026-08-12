#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$psExe = (Get-Process -Id $PID).Path
function Get-CanonicalSha256([string]$Path) {
    $text = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($Path))
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    $text = $text -replace "`r`n", "`n"
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($text); return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
$manifest = Get-Content -LiteralPath (Join-Path $root 'agents\manifest.json') -Raw | ConvertFrom-Json
if ($manifest.schema_version -ne 1 -or @($manifest.agents).Count -ne 8) { throw 'Expected eight versioned managed agents.' }
$names = @($manifest.agents | ForEach-Object { [string]$_.name })
if (($names | Select-Object -Unique).Count -ne 8 -or @($names | Where-Object { $_ -notmatch '^rikter_' }).Count) { throw 'Managed agent names are invalid.' }
foreach ($agent in @($manifest.agents)) {
    if ($agent.permission_mode -ne 'read-only') { throw "Agent is not read-only: $($agent.name)" }
    $source = Join-Path $root $agent.source
    $toml = Join-Path $root $agent.codex_config
    if (-not (Test-Path -LiteralPath $source) -or -not (Test-Path -LiteralPath $toml)) { throw "Missing manifest file for $($agent.name)" }
    if ((Get-CanonicalSha256 $source) -ne $agent.sha256) { throw "Checksum mismatch for $($agent.name)" }
    $prompt = Get-Content -LiteralPath $source -Raw
    if ($prompt -notmatch 'structured specialist-result contract' -or $prompt -match '(?i)\b(commit|push|merge)\b.*\b(do|must|should)\b') { throw "Unsafe or incomplete prompt: $($agent.name)" }
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-agent-pack-' + [guid]::NewGuid().ToString('N'))
try {
    & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\Install-AgentPack.ps1') -DestinationRoot $temp -DryRun
    if ($LASTEXITCODE -ne 0) { throw 'Installer dry run failed.' }
    & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\Remove-AgentPack.ps1') -DestinationRoot $temp -DryRun
    if ($LASTEXITCODE -ne 0) { throw 'Remover dry run failed.' }
} finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force } }
Write-Host 'PASS: managed agent pack is complete and read-only.'
