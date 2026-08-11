#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot 'Review-Helpers.ps1')

# Guide freshness is checked against a digest of the harness surface, not
# against a commit SHA. A SHA had to be recorded in a follow-up commit, because
# a commit cannot contain its own hash, and it did not survive squash, rebase,
# or merge-commit strategies, all of which rewrite or discard the SHA the guides
# named. The digest excludes the guides themselves, so a guide and its digest
# update belong in the same commit and any merge strategy preserves them.
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "VERSION is not SemVer: $version" }
$changelog = Get-Content (Join-Path $root 'CHANGELOG.md') -Raw
if ($changelog -notmatch "## \[$version\]") { throw "CHANGELOG.md has no entry for [$version]." }
$releaseMatch = [regex]::Match($changelog, "(?m)^## \[$([regex]::Escape($version))\]\s*-\s*(\d{4}-\d{2}-\d{2})")
if (-not $releaseMatch.Success) { throw "CHANGELOG.md has no dated entry for [$version]." }
$releaseDate = $releaseMatch.Groups[1].Value
$expected = Get-GuideDigest $root
foreach ($guide in @('WINDOWS_NOVICE_USABILITY_GUIDE.md', 'LINUX_NOVICE_USABILITY_GUIDE.md')) {
  $guidePath = Join-Path $root "docs\guides\$guide"
  if (-not (Test-Path -LiteralPath $guidePath)) { throw "Missing canonical novice guide: $guide" }
  $guideText = Get-Content -LiteralPath $guidePath -Raw
  if ($guideText -notmatch '(?m)^validation_status:\s+(verified|partially_verified|blocked)\s*$') { throw "Guide has invalid validation status: $guide" }
  if ($guideText -notmatch [regex]::Escape($version)) { throw "Guide does not identify release ${version}: $guide" }
  if ($guideText -notmatch [regex]::Escape($releaseDate)) { throw "Guide does not identify release date ${releaseDate}: $guide" }
  $recorded = [regex]::Match($guideText, '(?m)^reviewed_digest:\s*"([0-9a-fA-F]{64})"\s*$')
  if (-not $recorded.Success) { throw "Guide does not record a reviewed_digest: $guide" }
  if ($recorded.Groups[1].Value.ToLowerInvariant() -ne $expected) {
    throw "Guide $guide was reviewed against a different harness surface. Re-read it against the current tree, then record the new digest with:`n  pwsh -NoProfile -File scripts/ci/Update-GuideDigest.ps1"
  }
}
Write-Host "PASS: release metadata is consistent for $version (guide digest $($expected.Substring(0, 12)))."
