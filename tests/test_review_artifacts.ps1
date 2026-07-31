#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-artifacts-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
  Set-Content (Join-Path $temp 'review.md') '# Synthetic review' -Encoding UTF8
  $object = [ordered]@{ schema_version='1.0'; status='passed'; summary='Synthetic'; findings=@(); metadata=[ordered]@{ repository='fixture'; commit='fixture'; generated_at=(Get-Date).ToUniversalTime().ToString('o'); failure_class='none' } }
  Set-Content (Join-Path $temp 'review.json') ($object | ConvertTo-Json -Depth 8) -Encoding UTF8
  Get-FileHash -Algorithm SHA256 (Join-Path $temp 'review.md'), (Join-Path $temp 'review.json') |
    ForEach-Object { '{0}  {1}' -f $_.Hash.ToLowerInvariant(), $_.Path.Substring($temp.Length + 1) } |
    Set-Content (Join-Path $temp 'SHA256SUMS') -Encoding ASCII
  $env:REVIEW_OUTPUT_DIR = $temp
  powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '..\scripts\ci\Verify-ReviewArtifacts.ps1')
  if ($LASTEXITCODE -ne 0) { throw 'Artifact verification fixture failed.' }
  Write-Host 'PASS: review artifact verification fixture passed.'
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item Env:REVIEW_OUTPUT_DIR -ErrorAction SilentlyContinue
}
