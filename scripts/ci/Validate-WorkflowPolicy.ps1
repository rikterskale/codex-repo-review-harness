#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$workflows = Get-ChildItem (Join-Path $root '.github\workflows') -Filter '*.yml'
foreach ($workflow in $workflows) {
  $text = Get-Content $workflow.FullName -Raw
  if ($text -notmatch '(?m)^permissions:') { throw "Workflow lacks an explicit top-level permissions block: $($workflow.Name)." }
  if ($text -notmatch '(?m)^permissions:\s*\{\}\s*$') { throw "Workflow top-level permissions must default to none: $($workflow.Name)." }
  if ($text -notmatch '(?m)^\s{4}permissions:') { throw "Workflow lacks an explicit job-level permissions block: $($workflow.Name)." }
  if ($text -notmatch 'timeout-minutes:') { throw "Workflow lacks a timeout: $($workflow.Name)." }
  if ($text -notmatch 'cancel-in-progress:') { throw "Workflow lacks concurrency cancellation policy: $($workflow.Name)." }
  if ($text -match 'curl\s+.*\|\s*(sh|bash)') { throw "Unpinned remote shell execution in $($workflow.Name)." }
  foreach ($use in [regex]::Matches($text, '(?m)^\s*uses:\s*([^\s]+)$')) {
    if ($use.Groups[1].Value -notmatch '^\./' -and $use.Groups[1].Value -notmatch '@[0-9a-fA-F]{40}$') { throw "Action is not pinned to a full commit SHA in $($workflow.Name): $($use.Groups[1].Value)" }
  }
  $checkoutCount = @([regex]::Matches($text, '(?m)^\s*uses:\s*actions/checkout@')).Count
  $credentialCount = @([regex]::Matches($text, '(?m)^\s*persist-credentials:\s*false\s*$')).Count
  if ($checkoutCount -ne $credentialCount) { throw "Every checkout must disable persisted credentials in $($workflow.Name)." }
  if ($text -match '(?m)^\s*pull_request_target\s*:' -and $text -match 'pull-requests:\s*write') { throw "Analysis workflow must not grant pull-requests: write: $($workflow.Name)." }
}
$analysis = Get-Content (Join-Path $root '.github\workflows\codex-review.yml') -Raw
$publisher = Get-Content (Join-Path $root '.github\workflows\codex-review-comment.yml') -Raw
if ($analysis -notmatch '(?m)^\s*pull_request_target\s*:') { throw 'Analysis workflow must use pull_request_target.' }
if ($analysis -notmatch 'ref:\s*\$\{\{\s*github\.event\.pull_request\.base\.sha\s*\}\}') { throw 'Analysis workflow must checkout the trusted pull-request base SHA.' }
if ($analysis -match '(?m)^\s*pull-requests:\s*write\s*$') { throw 'Analysis workflow must not grant pull-request write permission.' }
# codex-action appends its own --sandbox argument after the codex-args
# pass-through, defaulting to workspace-write, so a sandbox selected through
# codex-args is silently outranked and the review would run write-enabled. The
# sandbox input is the only setting that survives.
if ($analysis -notmatch '(?m)^\s*sandbox:\s*read-only\s*$') { throw 'Analysis workflow must pin the Codex sandbox to read-only through the action input.' }
if ($analysis -match '(?m)^\s*codex-args:.*(--sandbox|(?<![\w-])-s(?![\w-])|sandbox_mode)') { throw 'Analysis workflow must not select a sandbox through codex-args; the action overrides it.' }
# The preflight must see only whether the secret is set. Passing the secret
# itself would copy the key into another process's environment for no reason.
$credentialCheck = [regex]::Match($analysis, '(?m)^\s*REVIEW_CREDENTIAL_PRESENT:\s*\$\{\{\s*secrets\.OPENAI_API_KEY\s*!=\s*''''\s*\}\}\s*$')
$codexAction = [regex]::Match($analysis, '(?m)^\s*uses:\s*openai/codex-action@')
if (-not $credentialCheck.Success) { throw 'Analysis workflow must verify that the review credential is present, passing only its presence.' }
if ($codexAction.Success -and $credentialCheck.Index -gt $codexAction.Index) { throw 'Analysis workflow must verify the review credential before invoking Codex, not after.' }
if ($publisher -notmatch '(?m)^\s*workflow_run\s*:') { throw 'Publisher workflow must use workflow_run.' }
if ($publisher -notmatch 'pull-requests:\s*write') { throw 'Publisher workflow must own PR comment permission.' }
if ($publisher -notmatch 'pull_requests\[0\]\.number') { throw 'Publisher workflow must guard against workflow runs without an associated PR.' }
if ($publisher -notmatch 'ref:\s*\$\{\{\s*github\.event\.repository\.default_branch\s*\}\}') { throw 'Publisher workflow must checkout the trusted default branch.' }
Write-Host 'PASS: workflow policy checks succeeded.'
