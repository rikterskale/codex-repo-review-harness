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
$document = Get-Content -LiteralPath $json -Raw | ConvertFrom-Json
foreach ($required in @('schema_version', 'status', 'summary', 'findings', 'metadata')) { if ($null -eq $document.$required) { throw "Review JSON missing $required." } }
if ($document.schema_version -ne '1.0') { throw 'Unsupported review JSON schema.' }
if ($document.status -notin @('passed','findings','blocked','failed')) { throw "Invalid report status: $($document.status)." }
foreach ($required in @('repository','commit','generated_at','failure_class')) { if ($null -eq $document.metadata.$required) { throw "Review metadata missing $required." } }
if ($document.metadata.failure_class -notin @('none','usage','prerequisite','timeout','output_limit','codex','contract','blocked')) { throw "Invalid failure class: $($document.metadata.failure_class)." }
foreach ($finding in @($document.findings)) {
  foreach ($required in @('severity','title','location','evidence','suggested_fix')) { if ($null -eq $finding.$required) { throw "Finding missing $required." } }
  if ($finding.severity -notin @('critical','high','medium','low','info')) { throw "Invalid finding severity: $($finding.severity)." }
}
$text = Get-Content -LiteralPath $markdown -Raw
if ($text -notmatch '(?m)^# Codex Repository Review Report\s*$') { throw 'Markdown report has an invalid title.' }
foreach ($heading in @('## Executive Summary', '## Findings', '## Positive Observations', '## Recommended Next Actions')) { if ($text -notmatch [regex]::Escape($heading)) { throw "Markdown report missing $heading." } }
foreach ($artifact in @($text, (Get-Content -LiteralPath $json -Raw))) {
  if (Test-ReviewSecrets $artifact) { throw 'Potential secret found in review artifacts.' }
}
Write-Host 'PASS: review artifacts verified.'
