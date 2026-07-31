#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "VERSION is not SemVer: $version" }
$changelog = Get-Content (Join-Path $root 'CHANGELOG.md') -Raw
if ($changelog -notmatch "## \[$version\]") { throw "CHANGELOG.md has no entry for [$version]." }
foreach ($guide in @('WINDOWS_NOVICE_USABILITY_GUIDE.md', 'LINUX_NOVICE_USABILITY_GUIDE.md')) {
  $guidePath = Join-Path $root "docs\guides\$guide"
  if (-not (Test-Path -LiteralPath $guidePath)) { throw "Missing canonical novice guide: $guide" }
  $guideText = Get-Content -LiteralPath $guidePath -Raw
  if ($guideText -notmatch '(?m)^validation_status:\s+(verified|partially_verified|blocked)\s*$') { throw "Guide has invalid validation status: $guide" }
  if ($guideText -notmatch [regex]::Escape($version)) { throw "Guide does not identify release ${version}: $guide" }
}
Write-Host "PASS: release metadata is consistent for $version."
