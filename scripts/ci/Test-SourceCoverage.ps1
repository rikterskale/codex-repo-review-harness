#Requires -Version 5.1
<#!
.SYNOPSIS
  Enforces full source-surface coverage for CI.

.DESCRIPTION
  This is a deterministic coverage inventory, not a line-coverage estimate.
  Every production PowerShell script must have at least one executable regression
  test. The CI workflow discovers and runs every test_*.ps1 file separately;
  this gate prevents new source scripts from silently escaping that suite.
#>
param([ValidateRange(0, 100)][int]$MinimumCoverage = 100)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$coverage = @{
  'scripts/Install-AgentPack.ps1' = @('tests/test_agent_pack.ps1')
  'scripts/Remove-AgentPack.ps1' = @('tests/test_agent_pack.ps1')
  'scripts/Run-Review.ps1' = @('tests/test_runner_failure.ps1')
  'scripts/Validate-Harness.ps1' = @('tests/test_harness_structure.ps1')
  'scripts/Validate-Integrations.ps1' = @('tests/test_agent_pack.ps1', 'tests/test_integration_lock.ps1')
  'scripts/ci/New-ReviewArtifacts.ps1' = @('tests/test_review_artifacts.ps1')
  'scripts/ci/Prepare-ReviewInput.ps1' = @('tests/test_review_artifacts.ps1')
  'scripts/ci/Publish-ReviewComment.ps1' = @('tests/test_review_artifacts.ps1')
  'scripts/ci/Repair-DocEncoding.ps1' = @('tests/test_batch2_regressions.ps1')
  'scripts/ci/Review-Helpers.ps1' = @('tests/test_review_helpers.ps1')
  'scripts/ci/Test-GeneratedArtifacts.ps1' = @('tests/test_review_artifacts.ps1')
  'scripts/ci/Test-PowerShellSyntax.ps1' = @('tests/test_harness_structure.ps1')
  'scripts/ci/Test-ReportContract.ps1' = @('tests/test_review_artifacts.ps1')
  'scripts/ci/Test-ReleaseReadiness.ps1' = @('tests/test_release_readiness.ps1')
  'scripts/ci/Update-GuideDigest.ps1' = @('tests/test_guide_digest.ps1')
  'scripts/ci/Validate-Release.ps1' = @('tests/test_clean_room.ps1')
  'scripts/ci/Validate-WorkflowPolicy.ps1' = @('tests/test_workflow_preflight.ps1')
  'scripts/ci/Verify-ReviewArtifacts.ps1' = @('tests/test_review_artifacts.ps1')
}

$sources = @(Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -Recurse -File -Filter '*.ps1' | ForEach-Object { $_.FullName.Substring($root.Length).TrimStart([char]'\', [char]'/' ).Replace('\', '/') } | Sort-Object)
$covered = @()
$missing = @()
foreach ($source in $sources) {
  $tests = @($coverage[$source])
  $valid = $tests.Count -gt 0 -and @($tests | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_)) }).Count -eq 0
  if ($valid) { $covered += $source } else { $missing += $source }
}
$percent = if ($sources.Count) { [math]::Round(($covered.Count * 100.0) / $sources.Count, 2) } else { 0 }
$summary = @("# Source coverage", '', "- Covered source scripts: $($covered.Count)/$($sources.Count) ($percent%)", "- Required threshold: $MinimumCoverage%", '', '| Source script | Executable regression test(s) |', '| --- | --- |')
foreach ($source in $sources) { $summary += "| `$source` | $(@($coverage[$source]) -join ', ') |" }
if ($env:GITHUB_STEP_SUMMARY) { Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value ($summary -join "`n") }
Write-Host "Source-surface coverage: $($covered.Count)/$($sources.Count) ($percent%)."
if ($missing.Count) { throw "Uncovered source scripts: $($missing -join ', ')" }
if ($percent -lt $MinimumCoverage) { throw "Source-surface coverage $percent% is below required $MinimumCoverage%." }
Write-Host 'PASS: 100% of production PowerShell scripts have executable regression-test coverage.'
