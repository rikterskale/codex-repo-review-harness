#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
& (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'scripts\ci\Test-ReleaseReadiness.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Release-readiness gate failed.' }
Write-Host 'PASS: release-readiness gate contract holds.'
