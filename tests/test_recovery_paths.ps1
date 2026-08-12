#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$psExe = (Get-Process -Id $PID).Path
$root = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-recovery-' + [guid]::NewGuid().ToString('N'))
$copy = Join-Path $temp 'harness'
$codexHome = Join-Path $temp 'codex-home'
try {
  New-Item -ItemType Directory -Path $copy -Force | Out-Null
  Get-ChildItem -LiteralPath $root -Force | Where-Object { $_.Name -notin @('.git', '.claude', 'reports', 'review-input', 'review-output') } | Copy-Item -Destination $copy -Recurse -Force
  $tampered = Join-Path $copy 'agents\source\rikter-repo-explorer.md'
  Add-Content -LiteralPath $tampered -Value 'tampered prompt'
  $previous = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  try { & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $copy 'scripts\Install-AgentPack.ps1') -DestinationRoot $codexHome -DryRun 2>$null; $tamperCode = $LASTEXITCODE } finally { $ErrorActionPreference = $previous }
  if ($tamperCode -eq 0) { throw 'Installer accepted a tampered manifest-owned prompt.' }
  Copy-Item -LiteralPath (Join-Path $root 'agents\source\rikter-repo-explorer.md') -Destination $tampered -Force
  & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $copy 'scripts\Install-AgentPack.ps1') -DestinationRoot $codexHome
  if ($LASTEXITCODE -ne 0) { throw 'Initial managed-pack installation failed.' }
  $owned = Join-Path $codexHome 'managed-agent-pack\source\rikter-repo-explorer.md'
  Set-Content -LiteralPath $owned -Value 'pre-existing managed customization' -Encoding UTF8
  $unrelated = Join-Path $codexHome 'unrelated-agent.txt'; Set-Content -LiteralPath $unrelated -Value 'preserve me' -Encoding UTF8
  & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $copy 'scripts\Install-AgentPack.ps1') -DestinationRoot $codexHome
  if ($LASTEXITCODE -ne 0) { throw 'Repeat managed-pack installation failed.' }
  & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $copy 'scripts\Remove-AgentPack.ps1') -DestinationRoot $codexHome -RestoreLatest
  if ($LASTEXITCODE -ne 0) { throw 'Managed-pack restoration failed.' }
  if ((Get-Content -LiteralPath $owned -Raw).Trim() -ne 'pre-existing managed customization') { throw 'Latest managed backup was not restored.' }
  if ((Get-Content -LiteralPath $unrelated -Raw).Trim() -ne 'preserve me') { throw 'Removal changed an unrelated user agent.' }
  Write-Host 'PASS: tamper rejection, backup restoration, and unrelated-agent preservation succeeded.'
} finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
