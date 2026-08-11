#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
# Resolve with --verify --quiet so an unresolvable revision yields nothing and a
# non-zero exit. Plain `git rev-parse HEAD~1` echoes the literal string "HEAD~1"
# on failure, which is truthy and would be compared against reviewed_head as if
# it were a SHA. HEAD~1 is unresolvable in a shallow checkout, so CI must fetch
# at least two commits for the metadata-update pattern to work.
$heads = @()
if (Test-Path (Join-Path $root '.git')) {
  foreach ($rev in @('HEAD', 'HEAD~1')) {
    $resolved = git -c core.excludesfile=NUL -C $root rev-parse --verify --quiet "$rev^{commit}" 2>$null
    if ($LASTEXITCODE -eq 0 -and $resolved) { $heads += ([string]$resolved).Trim() }
  }
}
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "VERSION is not SemVer: $version" }
$changelog = Get-Content (Join-Path $root 'CHANGELOG.md') -Raw
if ($changelog -notmatch "## \[$version\]") { throw "CHANGELOG.md has no entry for [$version]." }
$releaseMatch = [regex]::Match($changelog, "(?m)^## \[$([regex]::Escape($version))\]\s*-\s*(\d{4}-\d{2}-\d{2})")
if (-not $releaseMatch.Success) { throw "CHANGELOG.md has no dated entry for [$version]." }
$releaseDate = $releaseMatch.Groups[1].Value
foreach ($guide in @('WINDOWS_NOVICE_USABILITY_GUIDE.md', 'LINUX_NOVICE_USABILITY_GUIDE.md')) {
  $guidePath = Join-Path $root "docs\guides\$guide"
  if (-not (Test-Path -LiteralPath $guidePath)) { throw "Missing canonical novice guide: $guide" }
  $guideText = Get-Content -LiteralPath $guidePath -Raw
  if ($guideText -notmatch '(?m)^validation_status:\s+(verified|partially_verified|blocked)\s*$') { throw "Guide has invalid validation status: $guide" }
  if ($guideText -notmatch [regex]::Escape($version)) { throw "Guide does not identify release ${version}: $guide" }
  if ($guideText -notmatch [regex]::Escape($releaseDate)) { throw "Guide does not identify release date ${releaseDate}: $guide" }
  if ($heads.Count -gt 0 -and @($heads | Where-Object { $guideText -match ('(?m)^reviewed_head:\s*"?' + [regex]::Escape($_) + '"?\s*$') }).Count -eq 0) { throw "Guide does not identify current HEAD or its metadata-update parent: $guide" }
}
Write-Host "PASS: release metadata is consistent for $version."
