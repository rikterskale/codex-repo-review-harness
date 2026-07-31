#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-runner-' + [guid]::NewGuid().ToString('N'))
$bin = Join-Path $temp 'bin'
New-Item -ItemType Directory -Path $temp -Force | Out-Null
New-Item -ItemType Directory -Path $bin -Force | Out-Null
try {
  Get-ChildItem $root -Force | Where-Object { $_.Name -notin @('.git', 'reports', 'review-input', 'review-output') } |
    Copy-Item -Destination $temp -Recurse -Force
  Set-Content -LiteralPath (Join-Path $bin 'codex.cmd') -Value "@echo off`necho simulated Codex failure`nexit /b 9" -Encoding ASCII
  git -C $temp init --quiet
  $oldPath = $env:PATH
  $env:PATH = "$bin;$oldPath"
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\Run-Review.ps1') -TimeoutSeconds 10 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 4) { throw "Expected local runner exit code 4, got $LASTEXITCODE." }
  Write-Host 'PASS: local runner propagates Codex failure.'
  $success = @(
    '@echo off',
    'echo # Codex Repository Review Report',
    'echo.',
    'echo ## Executive Summary',
    'echo - Overall risk assessment: Medium.',
    'echo.',
    'echo ## Findings',
    'echo.',
    'echo ### [MEDIUM] Synthetic issue',
    'echo - **Location:** `fixture.ps1:1`',
    'echo - **Why it matters:** Synthetic test finding.',
    'echo - **Evidence:** The fake Codex output is deterministic.',
    'echo - **Suggested fix:** Keep the regression test.',
    'echo.',
    'echo ## Positive Observations',
    'echo - The runner produced structured output.',
    'echo.',
    'echo ## Recommended Next Actions',
    'echo 1. Keep the regression test.'
  )
  Set-Content -LiteralPath (Join-Path $bin 'codex.cmd') -Value ($success -join "`n") -Encoding ASCII
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\Run-Review.ps1') -TimeoutSeconds 10
  if ($LASTEXITCODE -ne 0) { throw "Expected successful local runner exit code 0, got $LASTEXITCODE." }
  $json = Get-ChildItem (Join-Path $temp 'reports') -Filter '*.json' | Select-Object -First 1
  $document = Get-Content $json.FullName -Raw | ConvertFrom-Json
  if ($document.status -ne 'findings' -or @($document.findings).Count -ne 1) { throw 'Structured finding output regression.' }
  Write-Host 'PASS: local runner creates structured findings.'
} finally {
  $env:PATH = $oldPath
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
