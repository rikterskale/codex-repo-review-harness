#Requires -Version 5.1
<#!
.SYNOPSIS
  Enforces the automated portion of the new-user release-readiness standard.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$required = @(
  'docs/RELEASE_READINESS_STANDARD.md',
  'tests/test_new_user_journey.ps1',
  'tests/test_recovery_paths.ps1',
  'tests/test_runner_failure.ps1',
  'tests/test_review_artifacts.ps1',
  'tests/test_security_regressions.ps1',
  'tests/test_clean_room.ps1',
  'tests/test_guide_digest.ps1',
  'scripts/ci/Test-SourceCoverage.ps1',
  'scripts/ci/Validate-Release.ps1'
)
foreach ($relative in $required) { if (-not (Test-Path -LiteralPath (Join-Path $root $relative))) { throw "Release-readiness evidence is missing: $relative" } }
$standard = Get-Content -LiteralPath (Join-Path $root 'docs/RELEASE_READINESS_STANDARD.md') -Raw
foreach ($heading in @('Proven installation', 'Guided troubleshooting', 'Recovery', 'Human release checklist')) {
  if ($standard -notmatch [regex]::Escape($heading)) { throw "Release-readiness standard omits: $heading" }
}
foreach ($guide in @('WINDOWS_NOVICE_USABILITY_GUIDE.md', 'LINUX_NOVICE_USABILITY_GUIDE.md')) {
  $text = Get-Content -LiteralPath (Join-Path $root "docs/guides/$guide") -Raw
  foreach ($code in 2..7) { if ($text -notmatch ("exit code[^0-9]{0,4}" + $code)) { throw "$guide does not document runner exit code $code." } }
}
if ($env:GITHUB_STEP_SUMMARY) { Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value "## Release readiness`n`nAutomated installation, feature, recovery, documentation, and source-surface gates are present. A human real-Codex smoke test remains required before release." }
Write-Host 'PASS: automated new-user release-readiness evidence is complete.'
