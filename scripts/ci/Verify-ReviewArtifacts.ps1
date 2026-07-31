#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Review-Helpers.ps1')
$root = if ($env:REVIEW_OUTPUT_DIR) { $env:REVIEW_OUTPUT_DIR } else { Join-Path (Get-Location) 'review-output' }
$markdown = Join-Path $root 'review.md'
$json = Join-Path $root 'review.json'
$manifest = Join-Path $root 'SHA256SUMS'
foreach ($path in @($markdown, $json, $manifest)) { if (-not (Test-Path -LiteralPath $path)) { throw "Missing review artifact: $path" } }
foreach ($path in @($markdown, $json)) { if ((Get-Item -LiteralPath $path).Length -gt 200KB) { throw "Review artifact exceeds 200 KiB: $path" } }
$entries = Get-Content -LiteralPath $manifest
foreach ($relative in @('review.md', 'review.json')) {
  $entry = $entries | Where-Object { $_ -match "\s$([regex]::Escape($relative))$" } | Select-Object -First 1
  if (-not $entry) { throw "SHA-256 manifest has no entry for $relative." }
  $expected = ($entry -split '\s+')[0].ToLowerInvariant()
  $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $root $relative)).Hash.ToLowerInvariant()
  if ($expected -ne $actual) { throw "SHA-256 mismatch for $relative." }
}
$schemaPath = Join-Path $PSScriptRoot '..\..\schemas\review-report.schema.json'
Assert-ReviewJson (Get-Content -LiteralPath $json -Raw) $schemaPath
$text = Get-Content -LiteralPath $markdown -Raw
if ($text -notmatch '(?m)^# Codex Repository Review Report\s*$') { throw 'Markdown report has an invalid title.' }
foreach ($heading in @('## Executive Summary', '## Findings', '## Positive Observations', '## Recommended Next Actions')) { if ($text -notmatch [regex]::Escape($heading)) { throw "Markdown report missing $heading." } }
foreach ($artifact in @($text, (Get-Content -LiteralPath $json -Raw))) {
  if (Test-ReviewSecrets $artifact) { throw 'Potential secret found in review artifacts.' }
}
Write-Host 'PASS: review artifacts verified.'
