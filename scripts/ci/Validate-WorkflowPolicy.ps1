#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$workflows = Get-ChildItem (Join-Path $root '.github\workflows') -Filter '*.yml'
foreach ($workflow in $workflows) {
  $text = Get-Content $workflow.FullName -Raw
  if ($text -notmatch '(?m)^permissions:') { throw "Workflow lacks an explicit top-level permissions block: $($workflow.Name)." }
  if ($text -notmatch 'timeout-minutes:') { throw "Workflow lacks a timeout: $($workflow.Name)." }
  if ($text -notmatch 'cancel-in-progress:') { throw "Workflow lacks concurrency cancellation policy: $($workflow.Name)." }
  if ($text -match 'curl\s+.*\|\s*(sh|bash)') { throw "Unpinned remote shell execution in $($workflow.Name)." }
  if ($text -match 'uses:\s+[^@\s]+@(v|main|master|latest)\b') { throw "Mutable action reference in $($workflow.Name)." }
  if ($text -match '(?m)^\s*pull_request_target\s*:' -and $text -match 'pull-requests:\s*write') { throw "Analysis workflow must not grant pull-requests: write: $($workflow.Name)." }
}
$analysis = Get-Content (Join-Path $root '.github\workflows\codex-review.yml') -Raw
$publisher = Get-Content (Join-Path $root '.github\workflows\codex-review-comment.yml') -Raw
if ($analysis -notmatch '(?m)^\s*pull_request_target\s*:') { throw 'Analysis workflow must use pull_request_target.' }
if ($publisher -notmatch '(?m)^\s*workflow_run\s*:') { throw 'Publisher workflow must use workflow_run.' }
if ($publisher -notmatch 'pull-requests:\s*write') { throw 'Publisher workflow must own PR comment permission.' }
Write-Host 'PASS: workflow policy checks succeeded.'
