#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
foreach ($file in Get-ChildItem $root -Recurse -Filter '*.ps1' | Where-Object { $_.FullName -notmatch '\\.git\\' }) {
  $tokens = $null; $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count) { throw "PowerShell syntax errors in $($file.FullName): $($errors -join '; ')" }
}
Write-Host 'PASS: PowerShell syntax checks succeeded.'
