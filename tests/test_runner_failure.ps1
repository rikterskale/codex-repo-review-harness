#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-runner-' + [guid]::NewGuid().ToString('N'))
$bin = Join-Path $temp 'bin'
New-Item -ItemType Directory -Path $temp -Force | Out-Null
New-Item -ItemType Directory -Path $bin -Force | Out-Null
try {
  $powerShell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { (Get-Command pwsh).Source } else { (Get-Command powershell).Source }
  Get-ChildItem $root -Force | Where-Object { $_.Name -notin @('.git', 'reports', 'review-input', 'review-output') } |
    Copy-Item -Destination $temp -Recurse -Force
  $isWindows = $env:OS -eq 'Windows_NT'
  $codexPath = if ($isWindows) { Join-Path $bin 'codex.cmd' } else { Join-Path $bin 'codex' }
  if ($isWindows) {
    Set-Content -LiteralPath $codexPath -Value "@echo off`necho simulated Codex failure`nexit /b 9" -Encoding ASCII
  } else {
    Set-Content -LiteralPath $codexPath -Value "#!/bin/sh`necho simulated Codex failure`nexit 9" -Encoding ASCII
    & chmod +x $codexPath
  }
  git -C $temp init --quiet
  $oldPath = $env:PATH
  $pathSeparator = [IO.Path]::PathSeparator
  $env:PATH = "$bin$pathSeparator$oldPath"
  $previousErrorAction = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & $powerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\Run-Review.ps1') -TimeoutSeconds 10 2>&1 | Out-Null
  $ErrorActionPreference = $previousErrorAction
  if ($LASTEXITCODE -ne 4) { throw "Expected local runner exit code 4, got $LASTEXITCODE." }
  Write-Host 'PASS: local runner propagates Codex failure.'
  $before = @(Get-ChildItem $temp -Recurse -File | ForEach-Object { $_.FullName })
  if ($isWindows) {
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
      'echo - **Evidence:** The fake Codex output is deterministic. CWD=%CD%',
      'echo - **Suggested fix:** Keep the regression test.',
      'echo.',
      'echo ## Positive Observations',
      'echo - The runner produced structured output.',
      'echo.',
      'echo ## Recommended Next Actions',
      'echo 1. Keep the regression test.'
    )
  } else {
    $success = @(
      '#!/bin/sh',
      'cat <<EOF',
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
      '- **Evidence:** The fake Codex output is deterministic. CWD=$PWD',
      '- **Suggested fix:** Keep the regression test.',
      '',
      '## Positive Observations',
      '- The runner produced structured output.',
      '',
      '## Recommended Next Actions',
      '1. Keep the regression test.',
      'EOF'
    )
  }
  Set-Content -LiteralPath $codexPath -Value (($success -join "`n") + "`n") -Encoding ASCII
  if (-not $isWindows) { & chmod +x $codexPath }
  & $powerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\Run-Review.ps1') -TimeoutSeconds 10
  if ($LASTEXITCODE -ne 0) { throw "Expected successful local runner exit code 0, got $LASTEXITCODE." }
  $json = Get-ChildItem (Join-Path $temp 'reports') -Filter '*.json' | Select-Object -First 1
  $document = Get-Content $json.FullName -Raw | ConvertFrom-Json
  if ($document.status -ne 'findings' -or @($document.findings).Count -ne 1) { throw 'Structured finding output regression.' }
  $reportText = Get-Content ([IO.Path]::ChangeExtension($json.FullName, '.md')) -Raw
  if ($reportText -notmatch [regex]::Escape($temp)) { throw 'Codex was not launched from the repository under test.' }
  $after = @(Get-ChildItem $temp -Recurse -File | ForEach-Object { $_.FullName })
  $newFiles = @($after | Where-Object { $_ -notin $before })
  foreach ($newFile in $newFiles) {
    if ($newFile -notlike "$(Join-Path $temp 'reports')*") { throw "Runner wrote outside the configured reports directory: $newFile" }
  }
  Write-Host 'PASS: local runner creates structured findings.'

  if ($isWindows) {
    Set-Content -LiteralPath $codexPath -Value "@echo off`npowershell -NoProfile -Command `"Start-Sleep -Seconds 3`"" -Encoding ASCII
  } else {
    Set-Content -LiteralPath $codexPath -Value "#!/bin/sh`nsleep 3" -Encoding ASCII
    & chmod +x $codexPath
  }
  $ErrorActionPreference = 'Continue'
  & $powerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\Run-Review.ps1') -TimeoutSeconds 1 2>&1 | Out-Null
  $timeoutExit = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  if ($timeoutExit -ne 6) { throw "Expected timeout exit code 6, got $timeoutExit." }
  Write-Host 'PASS: local runner enforces review timeouts.'

  if ($isWindows) {
    Set-Content -LiteralPath $codexPath -Value "@echo off`npowershell -NoProfile -Command `"[Console]::Write(('x' * 6000000))`"" -Encoding ASCII
  } else {
    Set-Content -LiteralPath $codexPath -Value "#!/bin/sh`nhead -c 6000000 /dev/zero | tr '\\0' x" -Encoding ASCII
    & chmod +x $codexPath
  }
  $ErrorActionPreference = 'Continue'
  & $powerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\Run-Review.ps1') -TimeoutSeconds 10 -MaxOutputBytes 1024 2>&1 | Out-Null
  $sizeExit = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  if ($sizeExit -ne 7) { throw "Expected output-size exit code 7, got $sizeExit." }
  Write-Host 'PASS: local runner enforces output-size limits.'
} finally {
  $env:PATH = $oldPath
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
