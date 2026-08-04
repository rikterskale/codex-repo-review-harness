#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$tracked = @(git -c core.excludesfile=NUL -C $root ls-files -- 'review-output/**' 2>$null)
if ($tracked.Count -gt 0) { throw "Generated review-output artifacts are tracked: $($tracked -join ', ')" }
Write-Host 'PASS: generated review-output artifacts are not tracked.'
