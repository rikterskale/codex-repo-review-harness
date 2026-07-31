#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
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
$text = Get-Content -LiteralPath $markdown -Raw
if ($text -match '(?i)(OPENAI_API_KEY|API_KEY|PASSWORD|SECRET)\s*[:=]\s*\S+') { throw 'Potential secret found in Markdown review artifact.' }
Write-Host 'PASS: review artifacts verified.'
