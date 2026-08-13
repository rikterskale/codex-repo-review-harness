#Requires -Version 5.1
<#
  Traversal regressions for the managed agent pack.

  Found by the first real-Codex review of this repository (REV-SEC-001). The
  installer validated agent.source and agent.codex_config for rooted and `..`
  values but never validated manifest.installation_root, which decides where
  every other path lands. The remover validated nothing at all and then passed
  its derived paths straight to Remove-Item, so an edited manifest could delete
  arbitrary files.

  Each case below writes a hostile manifest into a throwaway copy of the tree
  and requires both scripts to refuse. The canary file sits outside the
  destination root and must still exist afterwards: a refusal that still
  performed the write or delete would pass an exit-code check alone.
#>
$ErrorActionPreference = 'Stop'
$psExe = (Get-Process -Id $PID).Path
$root = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-traversal-' + [guid]::NewGuid().ToString('N'))
$harness = Join-Path $temp 'harness'
$codexHome = Join-Path $temp 'codex-home'
$outside = Join-Path $temp 'outside'

function Invoke-PackScript([string]$Script, [string[]]$Arguments) {
  # These runs are expected to fail, and a failing child writes to stderr, which
  # Windows PowerShell 5.1 would raise as a terminating error before the exit
  # code could be read.
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $null = & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $harness $Script) @Arguments 2>&1
    return $LASTEXITCODE
  } finally { $ErrorActionPreference = $previous }
}

function Set-ManifestValue([scriptblock]$Mutate) {
  $path = Join-Path $harness 'agents\manifest.json'
  $manifest = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
  & $Mutate $manifest
  $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
}

New-Item -ItemType Directory -Path $harness, $codexHome, $outside -Force | Out-Null
try {
  Get-ChildItem $root -Force |
    Where-Object { $_.Name -notin @('.git', '.claude', 'reports', 'review-input', 'review-output', 'logs') } |
    Copy-Item -Destination $harness -Recurse -Force

  $canary = Join-Path $outside 'canary.txt'
  Set-Content -LiteralPath $canary -Value 'this file must survive' -Encoding UTF8
  $pristine = Get-Content -LiteralPath (Join-Path $harness 'agents\manifest.json') -Raw

  # A clean manifest must still install, or the checks below would pass simply
  # because nothing works any more.
  if ((Invoke-PackScript 'scripts\Install-AgentPack.ps1' @('-DestinationRoot', $codexHome)) -ne 0) {
    throw 'The unmodified manifest no longer installs; the containment checks are too strict.'
  }

  $cases = @(
    @{ Name = 'installation_root escaping upwards'
      Mutate = { param($m) $m.installation_root = '..\..\outside\managed' } },
    @{ Name = 'installation_root as an absolute path'
      Mutate = { param($m) $m.installation_root = (Join-Path $outside 'managed') } },
    @{ Name = 'installation_root drive-qualified'
      Mutate = { param($m) $m.installation_root = 'C:managed' } },
    @{ Name = 'agent source escaping upwards'
      Mutate = { param($m) $m.agents[0].source = 'agents/../../../outside/canary.txt' } },
    @{ Name = 'agent codex_config escaping upwards'
      Mutate = { param($m) $m.agents[0].codex_config = 'agents/../../../outside/canary.txt' } },
    @{ Name = 'agent codex_config absolute'
      Mutate = { param($m) $m.agents[0].codex_config = $canary } }
  )

  foreach ($case in $cases) {
    Set-Content -LiteralPath (Join-Path $harness 'agents\manifest.json') -Value $pristine -Encoding UTF8
    Set-ManifestValue $case.Mutate

    $installCode = Invoke-PackScript 'scripts\Install-AgentPack.ps1' @('-DestinationRoot', $codexHome)
    if ($installCode -eq 0) { throw "The installer accepted a manifest with $($case.Name)." }

    $removeCode = Invoke-PackScript 'scripts\Remove-AgentPack.ps1' @('-DestinationRoot', $codexHome)
    if ($removeCode -eq 0) { throw "The remover accepted a manifest with $($case.Name)." }

    if (-not (Test-Path -LiteralPath $canary)) { throw "A manifest with $($case.Name) deleted a file outside the destination root." }
    if ((Get-Content -LiteralPath $canary -Raw).Trim() -ne 'this file must survive') { throw "A manifest with $($case.Name) overwrote a file outside the destination root." }
    if (Test-Path -LiteralPath (Join-Path $outside 'managed')) { throw "A manifest with $($case.Name) created a directory outside the destination root." }
  }

  # And a dry run must refuse too: it prints the actions it would take, so it
  # must not print a destination the real run would be blocked from writing.
  Set-Content -LiteralPath (Join-Path $harness 'agents\manifest.json') -Value $pristine -Encoding UTF8
  Set-ManifestValue { param($m) $m.installation_root = '..\..\outside\managed' }
  if ((Invoke-PackScript 'scripts\Install-AgentPack.ps1' @('-DestinationRoot', $codexHome, '-DryRun')) -eq 0) {
    throw 'A dry run advertised an installation outside the destination root.'
  }

  Write-Host 'PASS: manifest paths cannot escape the managed agent-pack root in either script.'
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
