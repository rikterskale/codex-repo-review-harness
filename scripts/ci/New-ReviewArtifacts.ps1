#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Review-Helpers.ps1')
$out = Join-Path (Get-Location) 'review-output'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$message = if ($env:CODEX_MESSAGE) { $env:CODEX_MESSAGE } else { 'Codex did not produce a final message.' }
$message = ConvertTo-RedactedText $message
if ([Text.Encoding]::UTF8.GetByteCount($message) -gt 200KB) { $message = $message.Substring(0, 180000) + "`n`n[Output truncated by contract.]" }
$failure = if ($env:CODEX_OUTCOME -eq 'success') { 'none' } else { 'codex' }
$status = if ($failure -eq 'none') { 'passed' } else { 'failed' }
$report = [ordered]@{
  schema_version = '1.0'
  status = $status
  summary = $message.Substring(0, [Math]::Min($message.Length, 20000))
  findings = @()
  metadata = [ordered]@{ repository = $env:GITHUB_REPOSITORY; commit = $env:GITHUB_SHA; generated_at = (Get-Date).ToUniversalTime().ToString('o'); failure_class = $failure }
}
$json = $report | ConvertTo-Json -Depth 8
Set-Content -LiteralPath (Join-Path $out 'review.md') -Value $message -Encoding UTF8
Set-Content -LiteralPath (Join-Path $out 'review.json') -Value $json -Encoding UTF8
Get-FileHash -Algorithm SHA256 (Join-Path $out 'review.md'), (Join-Path $out 'review.json') |
  ForEach-Object { '{0}  {1}' -f $_.Hash.ToLowerInvariant(), $_.Path.Substring($out.Length + 1) } |
  Set-Content -LiteralPath (Join-Path $out 'SHA256SUMS') -Encoding ASCII
