#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$workflows = Get-ChildItem (Join-Path $root '.github\workflows') -Filter '*.yml'
foreach ($workflow in $workflows) {
  $text = Get-Content $workflow.FullName -Raw
  if ($text -match 'curl\s+.*\|\s*(sh|bash)') { throw "Unpinned remote shell execution in $($workflow.Name)." }
  if ($text -match 'uses:\s+[^@\s]+@(v|main|master|latest)\b') { throw "Mutable action reference in $($workflow.Name)." }
  if ($text -match '(?m)^\s*pull_request_target\s*:' -and $text -match 'pull-requests:\s*write') { throw "Analysis workflow must not grant pull-requests: write: $($workflow.Name)." }
}
Write-Host 'PASS: workflow policy checks succeeded.'
