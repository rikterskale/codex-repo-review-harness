#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$wizardPath = Join-Path $root 'scripts\Start-ReviewWizard.ps1'
if (-not (Test-Path -LiteralPath $wizardPath)) { throw 'Interactive review wizard is missing.' }
$tokens = $errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($wizardPath, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count) { throw "Interactive review wizard has PowerShell syntax errors: $($errors[0].Message)" }
$wizard = Get-Content -LiteralPath $wizardPath -Raw
foreach ($required in @('Run-Review.ps1', 'Read-Host', 'Type REVIEW', '-DryRun', '-DiagnosticLogPath', 'exit $exitCode')) {
    if ($wizard -notmatch [regex]::Escape($required)) { throw "Interactive review wizard is missing required behavior: $required" }
}
if ($wizard -match 'Set-Content|Add-Content|Remove-Item|Copy-Item|Move-Item') { throw 'Interactive review wizard must delegate review work to the runner instead of modifying files itself.' }
Write-Host 'PASS: interactive review wizard has its required read-only review controls.'
