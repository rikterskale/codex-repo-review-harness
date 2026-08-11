#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$version = (Get-Content (Join-Path $root 'VERSION') -Raw).Trim()
# Resolve with --verify --quiet so an unresolvable revision yields nothing and a
# non-zero exit. Plain `git rev-parse HEAD~1` echoes the literal string "HEAD~1"
# on failure, which is truthy and would be compared against reviewed_head as if
# it were a SHA. HEAD~1 is unresolvable in a shallow checkout, so CI must fetch
# enough history for the metadata-update pattern to work.
function Resolve-ReleaseCommit([string]$Revision) {
  if (-not $Revision) { return $null }
  $sha = git -c core.excludesfile=NUL -C $root rev-parse --verify --quiet "${Revision}^{commit}" 2>$null
  if ($LASTEXITCODE -eq 0 -and $sha) { return ([string]$sha).Trim() }
  return $null
}

# On a pull_request event the checked-out commit is a synthetic merge of the pull
# request into the base branch. HEAD is a commit no author ever wrote, and HEAD~1
# is the base branch tip, so neither can carry a guide's reviewed_head and the
# freshness check would always fail. The commit the guides were actually written
# against is the pull request head, so resolve that explicitly and treat it as
# the tip. PR_HEAD_SHA comes from github.event.pull_request.head.sha; HEAD^2 is
# the same commit derived from the merge topology and covers the case where the
# variable is absent. If neither resolves, fall back to HEAD so a non-merge
# checkout still behaves as it does on push.
$heads = @()
if (Test-Path (Join-Path $root '.git')) {
  $tip = 'HEAD'
  if ($env:GITHUB_EVENT_NAME -eq 'pull_request') {
    foreach ($candidate in @($env:PR_HEAD_SHA, 'HEAD^2')) {
      $resolvedTip = Resolve-ReleaseCommit $candidate
      if ($resolvedTip) { $tip = $resolvedTip; break }
    }
  }
  foreach ($rev in @($tip, "${tip}~1")) {
    $resolved = Resolve-ReleaseCommit $rev
    if ($resolved) { $heads += $resolved }
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
