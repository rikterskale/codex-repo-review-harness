#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$psExe = (Get-Process -Id $PID).Path
$root = Split-Path -Parent $PSScriptRoot
$isWin = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-runner-' + [guid]::NewGuid().ToString('N'))
$bin = Join-Path $temp 'bin'
New-Item -ItemType Directory -Path $temp -Force | Out-Null
New-Item -ItemType Directory -Path $bin -Force | Out-Null

function Set-FakeCodex([string]$LineBody, [int]$ExitCode) {
  if ($isWin) {
    $cmd = "@echo off`n$LineBody`nexit /b $ExitCode"
    Set-Content -LiteralPath (Join-Path $bin 'codex.cmd') -Value $cmd -Encoding ASCII
  } else {
    $sh = "#!/usr/bin/env bash`n$LineBody`nexit $ExitCode`n"
    $path = Join-Path $bin 'codex'
    Set-Content -LiteralPath $path -Value $sh -Encoding ASCII
    & chmod +x $path | Out-Null
  }
}

try {
  Get-ChildItem $root -Force | Where-Object { $_.Name -notin @('.git', 'reports', 'review-input', 'review-output') } |
    Copy-Item -Destination $temp -Recurse -Force
  Set-FakeCodex 'echo simulated Codex failure' 9
  git -C $temp init --quiet
  $oldPath = $env:PATH
  $env:PATH = $bin + [IO.Path]::PathSeparator + $oldPath
  $previousErrorAction = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\Run-Review.ps1') -TimeoutSeconds 10 2>&1 | Out-Null
  $ErrorActionPreference = $previousErrorAction
  if ($LASTEXITCODE -ne 4) { throw "Expected local runner exit code 4, got $LASTEXITCODE." }
  Write-Host 'PASS: local runner propagates Codex failure.'
  $reportLines = @(
    '# Codex Repository Review Report',
    '',
    '## Executive Summary',
    '- Overall risk assessment: Medium.',
    '',
    '## Findings',
    '',
    '### [MEDIUM] Synthetic issue',
    '- **Location:** `fixture.ps1:1`',
    '- **Why it matters:** Synthetic test finding.',
    '- **Evidence:** The fake Codex output is deterministic.',
    '- **Suggested fix:** Keep the regression test.',
    '',
    '## Positive Observations',
    '- The runner produced structured output.',
    '',
    '## Recommended Next Actions',
    '1. Keep the regression test.'
  )
  $successReportPath = Join-Path $temp 'fake-report.md'
  Set-Content -LiteralPath $successReportPath -Value ($reportLines -join "`n") -Encoding ASCII
  if ($isWin) {
    $cmd = "@echo off`ntype `"$successReportPath`"`nexit /b 0"
    Set-Content -LiteralPath (Join-Path $bin 'codex.cmd') -Value $cmd -Encoding ASCII
  } else {
    $sh = "#!/usr/bin/env bash`ncat `"$successReportPath`"`nexit 0`n"
    $path = Join-Path $bin 'codex'
    Set-Content -LiteralPath $path -Value $sh -Encoding ASCII
    & chmod +x $path | Out-Null
  }
  & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\Run-Review.ps1') -TimeoutSeconds 10
  if ($LASTEXITCODE -ne 0) { throw "Expected successful local runner exit code 0, got $LASTEXITCODE." }

  # The synthetic Codex above accepts any arguments, which is why it kept
  # passing while the runner invoked `codex` with none at all: the first job
  # parameter was named $Args, a PowerShell automatic variable that cannot be
  # bound, so the splat expanded to nothing and every real review launched the
  # interactive TUI instead of `codex exec`. This fake refuses to play along.
  # It also pins the read-only sandbox, which is the harness's core safety
  # promise and was likewise never checked at the point of invocation.
  $strictReport = Join-Path $temp 'strict-report.md'
  Set-Content -LiteralPath $strictReport -Value ($reportLines -join "`n") -Encoding ASCII
  if ($isWin) {
    $strict = @(
      '@echo off',
      'if not "%1"=="exec" exit /b 42',
      'if not "%2"=="--sandbox" exit /b 43',
      'if not "%3"=="read-only" exit /b 44',
      "type `"$strictReport`"",
      'exit /b 0'
    ) -join "`n"
    Set-Content -LiteralPath (Join-Path $bin 'codex.cmd') -Value $strict -Encoding ASCII
  } else {
    $strict = @(
      '#!/usr/bin/env bash',
      'if [ "$1" != "exec" ]; then exit 42; fi',
      'if [ "$2" != "--sandbox" ]; then exit 43; fi',
      'if [ "$3" != "read-only" ]; then exit 44; fi',
      "cat `"$strictReport`"",
      'exit 0'
    ) -join "`n"
    $strictPath = Join-Path $bin 'codex'
    Set-Content -LiteralPath $strictPath -Value $strict -Encoding ASCII
    & chmod +x $strictPath | Out-Null
  }
  & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\Run-Review.ps1') -TimeoutSeconds 10
  if ($LASTEXITCODE -ne 0) {
    throw "The runner did not invoke 'codex exec --sandbox read-only'; the strict fake rejected its arguments (runner exit $LASTEXITCODE, where 4 means the fake refused)."
  }
  Write-Host 'PASS: the runner invokes codex exec with the read-only sandbox.'
  $json = Get-ChildItem (Join-Path $temp 'reports') -Filter '*.json' -Recurse | Select-Object -First 1
  $document = Get-Content $json.FullName -Raw | ConvertFrom-Json
  if ($document.status -ne 'findings' -or @($document.findings).Count -ne 1) { throw 'Structured finding output regression.' }
  Write-Host 'PASS: local runner creates structured findings.'
} finally {
  $env:PATH = $oldPath
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
