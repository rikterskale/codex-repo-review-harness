#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-harness-clean-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
    Get-ChildItem $root -Force | Where-Object { $_.Name -notin @('.git', 'reports', 'review-input', 'review-output') } |
        Copy-Item -Destination $temp -Recurse -Force
    $cleanTest = Join-Path $temp 'tests\test_harness_structure.ps1'
    powershell -NoProfile -ExecutionPolicy Bypass -File $cleanTest
    if ($LASTEXITCODE -ne 0) { throw 'Clean-room structural validation failed.' }

    $versionPath = Join-Path $temp 'VERSION'
    Set-Content -LiteralPath $versionPath -Value '0.0.1' -Encoding ASCII
    Copy-Item -LiteralPath (Join-Path $root 'VERSION') -Destination $versionPath -Force
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\ci\Validate-Release.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Clean-room upgrade validation failed.' }
    Write-Host 'PASS: clean-room installation and upgrade checks succeeded.'
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
