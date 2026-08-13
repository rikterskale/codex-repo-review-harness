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

# The real Codex writes its final message to the path given by
# --output-last-message, and the harness reads the review from there rather than
# from the console. A fake that prints to stdout instead would let a regression
# back to stdout-scraping pass unnoticed, so these write to argument 7 — the
# runner builds `exec --sandbox read-only --color never --output-last-message
# <file>` in that fixed order.
function Set-ReportingFakeCodex([string]$ReportPath) {
  if ($isWin) {
    $cmd = @('@echo off', "type `"$ReportPath`" > %7", 'exit /b 0') -join "`n"
    Set-Content -LiteralPath (Join-Path $bin 'codex.cmd') -Value $cmd -Encoding ASCII
  } else {
    $sh = @('#!/usr/bin/env bash', "cat `"$ReportPath`" > `"`$7`"", 'exit 0') -join "`n"
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
  & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\Run-Review.ps1') -TimeoutSeconds 10 -DiagnosticLogPath 'diagnostics\failure.log' 2>&1 | Out-Null
  $ErrorActionPreference = $previousErrorAction
  if ($LASTEXITCODE -ne 4) { throw "Expected local runner exit code 4, got $LASTEXITCODE." }
  $diagnosticLog = Join-Path $temp 'diagnostics\failure.log'
  if (-not (Test-Path -LiteralPath $diagnosticLog) -or (Get-Content -LiteralPath $diagnosticLog -Raw) -notmatch 'simulated Codex failure') { throw 'Diagnostic logging did not retain the redacted Codex failure transcript.' }
  Write-Host 'PASS: local runner propagates Codex failure.'
  $previousErrorAction = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\Run-Review.ps1') -Prompt '..\README.md' -DryRun 2>&1 | Out-Null
  $ErrorActionPreference = $previousErrorAction
  if ($LASTEXITCODE -ne 2) { throw "Expected escaping prompt path to exit 2, got $LASTEXITCODE." }
  Write-Host 'PASS: local runner rejects a prompt path that escapes prompts/.'
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
  Set-ReportingFakeCodex $successReportPath
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
  # Outside $temp on purpose: $temp is the repository under review, and a file
  # appearing inside it mid-run is exactly what the runner's read-only check is
  # built to catch. It caught this one.
  $capture = Join-Path ([IO.Path]::GetTempPath()) ('codex-stdin-' + [guid]::NewGuid().ToString('N') + '.txt')
  # Exit codes: 42/43/44 wrong subcommand or sandbox, 45 colour left on so ANSI
  # escapes could reach the artifact, 46 no --output-last-message so the runner
  # would be scraping the console again, 47 a prompt passed as an argument, 48
  # no prompt on stdin. 47 is the one that catches the quoting defect: a prompt
  # containing a double quote split into extra arguments, which looks exactly
  # like passing it as an argument in the first place.
  if ($isWin) {
    $strict = @(
      '@echo off',
      'if not "%1"=="exec" exit /b 42',
      'if not "%2"=="--sandbox" exit /b 43',
      'if not "%3"=="read-only" exit /b 44',
      'if not "%4%5"=="--colornever" exit /b 45',
      'if not "%6"=="--output-last-message" exit /b 46',
      'if not "%8"=="" exit /b 47',
      "findstr `"^`" > `"$capture`"",
      "findstr /C:`"BEGIN PROMPT`" `"$capture`" >nul",
      'if errorlevel 1 exit /b 48',
      "type `"$strictReport`" > %7",
      'exit /b 0'
    ) -join "`n"
    Set-Content -LiteralPath (Join-Path $bin 'codex.cmd') -Value $strict -Encoding ASCII
  } else {
    $strict = @(
      '#!/usr/bin/env bash',
      'if [ "$1" != "exec" ]; then exit 42; fi',
      'if [ "$2" != "--sandbox" ]; then exit 43; fi',
      'if [ "$3" != "read-only" ]; then exit 44; fi',
      'if [ "$4$5" != "--colornever" ]; then exit 45; fi',
      'if [ "$6" != "--output-last-message" ]; then exit 46; fi',
      'if [ -n "$8" ]; then exit 47; fi',
      "cat > `"$capture`"",
      "grep -q 'BEGIN PROMPT' `"$capture`" || exit 48",
      "cat `"$strictReport`" > `"`$7`"",
      'exit 0'
    ) -join "`n"
    $strictPath = Join-Path $bin 'codex'
    Set-Content -LiteralPath $strictPath -Value $strict -Encoding ASCII
    & chmod +x $strictPath | Out-Null
  }
  # A quote in the prompt is the exact shape of the defect, so put one there:
  # Windows PowerShell 5.1 does not escape embedded quotes into a native command
  # line, and passing the prompt as an argument split it at this character.
  $promptPath = Join-Path $temp 'prompts\system-review.md'
  Add-Content -LiteralPath $promptPath -Value 'Apply every rule under "## Code Review Rules" that is in scope.'

  & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\Run-Review.ps1') -TimeoutSeconds 10
  if ($LASTEXITCODE -ne 0) {
    throw "The runner did not invoke 'codex exec --sandbox read-only' with the prompt on stdin; the strict fake refused (runner exit $LASTEXITCODE, where 4 means the fake rejected the invocation)."
  }
  Write-Host 'PASS: the runner invokes codex exec read-only and sends a quoted prompt on stdin.'
  $json = Get-ChildItem (Join-Path $temp 'reports') -Filter '*.json' -Recurse | Select-Object -First 1
  $document = Get-Content $json.FullName -Raw | ConvertFrom-Json
  if ($document.status -ne 'findings' -or @($document.findings).Count -ne 1) { throw 'Structured finding output regression.' }
  Write-Host 'PASS: local runner creates structured findings.'
} finally {
  $env:PATH = $oldPath
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
  if ($capture) { Remove-Item -LiteralPath $capture -Force -ErrorAction SilentlyContinue }
}
