#Requires -Version 5.1
<#
  Regressions for the three user-facing defects the novice guides recorded
  against release 0.1.0 and that 0.2.0 fixes. Each one is a papercut a
  first-time user hits before anything else works, which is exactly the class of
  failure docs/RELEASE_READINESS_STANDARD.md exists to catch:

    REV-UX-001  `-DryRun` refused to run without the Codex CLI, defeating the
                one switch that exists to check things before installing it.
    REV-DOC-004 every report printed its title twice.
    REV-DOC-005 the validator told Linux users to run a Windows installer.
#>
$ErrorActionPreference = 'Stop'
$psExe = (Get-Process -Id $PID).Path
$root = Split-Path -Parent $PSScriptRoot
$onWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-novice-fix-' + [guid]::NewGuid().ToString('N'))
$bin = Join-Path $temp 'bin'

# Removes every PATH entry that provides a codex executable. The defects below
# are about behaviour when Codex is absent, and a developer machine with Codex
# installed would otherwise pass them vacuously.
function Remove-CodexFromPath {
  $separator = [IO.Path]::PathSeparator
  $names = if ($onWindows) { @('codex.cmd', 'codex.exe', 'codex.bat', 'codex') } else { @('codex') }
  $kept = @($env:PATH -split $separator | Where-Object {
      if (-not $_) { return $false }
      $directory = $_
      -not (@($names | Where-Object { Test-Path -LiteralPath (Join-Path $directory $_) }).Count -gt 0)
    })
  $env:PATH = ($kept -join $separator)
  if (Get-Command codex -ErrorAction SilentlyContinue) { throw 'Could not remove codex from PATH; these regressions need it absent.' }
}

function Invoke-Script([string]$RelativePath, [string[]]$Arguments) {
  # These runs are expected to fail, and a failing child writes to stderr, which
  # Windows PowerShell 5.1 would raise as a terminating error before the exit
  # code could be read.
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp $RelativePath) @Arguments 2>&1 | Out-String
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
  } finally { $ErrorActionPreference = $previous }
}

$originalPath = $env:PATH
New-Item -ItemType Directory -Path $temp, $bin -Force | Out-Null
try {
  Get-ChildItem $root -Force |
    Where-Object { $_.Name -notin @('.git', '.claude', 'reports', 'review-input', 'review-output', 'logs') } |
    Copy-Item -Destination $temp -Recurse -Force
  git -C $temp init --quiet

  Remove-CodexFromPath

  # REV-UX-001: a dry run must complete without Codex installed.
  $dry = Invoke-Script 'scripts\Run-Review.ps1' @('-DryRun')
  if ($dry.ExitCode -ne 0) { throw "-DryRun requires the Codex CLI again (exit $($dry.ExitCode)): $($dry.Output)" }
  if ($dry.Output -notmatch 'Prepared bounded read-only review') { throw 'The dry run did not report what it prepared.' }

  # ...and the prerequisite must still apply to a real run, or the fix would
  # just have deleted the check.
  $real = Invoke-Script 'scripts\Run-Review.ps1' @('-TimeoutSeconds', '10')
  if ($real.ExitCode -ne 3) { throw "A real review without Codex must still exit 3, got $($real.ExitCode)." }

  # REV-DOC-005: the fix hint must be actionable on the platform in hand.
  $validation = Invoke-Script 'scripts\Validate-Harness.ps1' @()
  $windowsInstaller = 'chatgpt\.com/codex/install\.ps1'
  $windowsGit = 'git-scm\.com/download/win'
  if ($onWindows) {
    if ($validation.Output -notmatch 'maintainer-approved Codex setup instructions for Windows') { throw 'The Windows validator no longer explains how to obtain its supported setup instructions.' }
  } else {
    if ($validation.Output -match $windowsInstaller) { throw 'The validator still prints the Windows Codex installer on a non-Windows host.' }
    if ($validation.Output -match $windowsGit) { throw 'The validator still prints the Windows Git download on a non-Windows host.' }
    if ($validation.Output -notmatch 'chatgpt\.com/codex/install\.sh') { throw 'The validator gives non-Windows users no way to install Codex.' }
  }

  # REV-DOC-004: the written report must carry its title exactly once.
  $reportLines = @(
    '# Codex Repository Review Report',
    '',
    '## Executive Summary',
    '- Overall risk assessment: Low.',
    '',
    '## Findings',
    '- No findings.',
    '',
    '## Positive Observations',
    '- The title is written once.',
    '',
    '## Recommended Next Actions',
    '1. Keep this regression.'
  )
  $fakeReport = Join-Path $temp 'fake-report.md'
  Set-Content -LiteralPath $fakeReport -Value ($reportLines -join "`n") -Encoding ASCII
  # Argument 7 is the --output-last-message path the harness reads the review from.
  if ($onWindows) {
    Set-Content -LiteralPath (Join-Path $bin 'codex.cmd') -Value "@echo off`ntype `"$fakeReport`" > %7`nexit /b 0" -Encoding ASCII
  } else {
    $fake = Join-Path $bin 'codex'
    Set-Content -LiteralPath $fake -Value "#!/usr/bin/env bash`ncat `"$fakeReport`" > `"`$7`"`nexit 0`n" -Encoding ASCII
    & chmod +x $fake | Out-Null
  }
  $env:PATH = $bin + [IO.Path]::PathSeparator + $env:PATH

  $review = Invoke-Script 'scripts\Run-Review.ps1' @('-TimeoutSeconds', '20')
  if ($review.ExitCode -ne 0) { throw "The review failed (exit $($review.ExitCode)): $($review.Output)" }
  $markdown = @(Get-ChildItem (Join-Path $temp 'reports') -Filter 'review.md' -Recurse -File)
  if ($markdown.Count -ne 1) { throw "Expected exactly one review.md, found $($markdown.Count)." }
  $text = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($markdown[0].FullName))
  $titles = @([regex]::Matches($text, '(?m)^# Codex Repository Review Report[ \t]*$')).Count
  if ($titles -ne 1) { throw "The report title appears $titles times; it must appear exactly once." }
  # The header carries the metadata, so it must be the copy that survived.
  if ($text -notmatch '(?m)^\*\*Sandbox:\*\* read-only\s*$') { throw 'The surviving title is not the harness header.' }
  # And the body must still be intact under it.
  foreach ($section in @('## Executive Summary', '## Findings', '## Positive Observations', '## Recommended Next Actions')) {
    if ($text -notmatch [regex]::Escape($section)) { throw "Stripping the duplicate title removed $section." }
  }
  $json = @(Get-ChildItem (Join-Path $temp 'reports') -Filter 'review.json' -Recurse -File)[0]
  $document = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($json.FullName)) | ConvertFrom-Json
  if ($document.summary -match '(?m)^# Codex Repository Review Report[ \t]*$') { throw 'The JSON summary still carries the duplicated title.' }

  Write-Host 'PASS: dry run works without Codex, validator hints match the platform, and the report title is written once.'
} finally {
  $env:PATH = $originalPath
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
