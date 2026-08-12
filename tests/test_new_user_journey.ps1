#Requires -Version 5.1
<#!
.SYNOPSIS
  Simulates a first-time user's complete local journey without real credentials.
#>
$ErrorActionPreference = 'Stop'
$psExe = (Get-Process -Id $PID).Path
$runningOnWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
$root = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-new-user-' + [guid]::NewGuid().ToString('N'))
$harness = Join-Path $temp 'harness'
$target = Join-Path $temp 'first-project'
$bin = Join-Path $temp 'bin'
$codexHome = Join-Path $temp 'codex-home'

function Assert-ExitCode([int]$Expected, [string]$Action) {
    if ($LASTEXITCODE -ne $Expected) { throw "$Action failed: expected exit $Expected, got $LASTEXITCODE." }
}

try {
    New-Item -ItemType Directory -Path $harness, $target, $bin -Force | Out-Null
    Get-ChildItem -LiteralPath $root -Force | Where-Object { $_.Name -notin @('.git', '.claude', 'review-input', 'review-output') } | Copy-Item -Destination $harness -Recurse -Force
    Set-Content -LiteralPath (Join-Path $target 'app.ps1') -Value "function Get-Greeting { 'hello' }" -Encoding UTF8
    git -C $harness init --quiet
    git -C $target init --quiet
    git -C $target add app.ps1
    git -C $target -c user.name='CI User' -c user.email='ci@example.invalid' commit -m 'Initial project' --quiet

    $report = @'
# Codex Repository Review Report

## Executive Summary
- Synthetic first review completed.

## Findings
- No findings.

## Positive Observations
- The target remained unchanged.

## Recommended Next Actions
1. Read the generated report.
'@
    $reportPath = Join-Path $temp 'synthetic-report.md'
    Set-Content -LiteralPath $reportPath -Value $report -Encoding UTF8
    if ($runningOnWindows) {
        Set-Content -LiteralPath (Join-Path $bin 'codex.cmd') -Value "@echo off`ntype `"$reportPath`"`nexit /b 0" -Encoding ASCII
    } else {
        $fakeCodex = Join-Path $bin 'codex'
        Set-Content -LiteralPath $fakeCodex -Value "#!/usr/bin/env bash`ncat '$($reportPath -replace "'", "'\\''")'`nexit 0" -Encoding UTF8
        & chmod +x $fakeCodex
    }
    $previousPath = $env:PATH
    $env:PATH = $bin + [IO.Path]::PathSeparator + $previousPath
    try {
        & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $harness 'scripts\Validate-Harness.ps1')
        Assert-ExitCode 0 'Fresh-install validation'
        & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $harness 'scripts\Install-AgentPack.ps1') -DestinationRoot $codexHome
        Assert-ExitCode 0 'Managed-agent installation'
        & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $harness 'scripts\Validate-Integrations.ps1') -DestinationRoot $codexHome
        Assert-ExitCode 0 'Managed-agent validation'
        $before = (git -C $target status --porcelain) -join "`n"
        & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $harness 'scripts\Run-Review.ps1') -RepositoryPath $target -TimeoutSeconds 20
        Assert-ExitCode 0 'First read-only review'
        $after = (git -C $target status --porcelain) -join "`n"
        if ($before -ne $after) { throw 'The first review changed the target repository.' }
        $artifacts = @(Get-ChildItem -LiteralPath (Join-Path $harness 'reports') -Recurse -File)
        foreach ($name in @('review.md', 'review.json', 'review.sha256')) { if (@($artifacts | Where-Object Name -eq $name).Count -ne 1) { throw "First review did not create $name." } }
        & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $harness 'scripts\Remove-AgentPack.ps1') -DestinationRoot $codexHome
        Assert-ExitCode 0 'Managed-agent removal'
    } finally { $env:PATH = $previousPath }
    Write-Host 'PASS: new-user install, validation, first review, report retrieval, isolation, and removal journey succeeded.'
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
