#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
# GitHub Actions runs both .yml and .yaml. Matching only .yml would let a
# workflow escape every policy check below simply by using the other spelling.
$workflows = @(Get-ChildItem (Join-Path $root '.github\workflows') -File | Where-Object { $_.Extension.ToLowerInvariant() -in @('.yml', '.yaml') })
if ($workflows.Count -eq 0) { throw 'No workflow files were found to validate.' }
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
# The analysis workflow also runs on demand, for refs that never went through a
# pull request. That path is maintainer-triggered, so its inputs are trusted at
# the level of a push — but only if they stay data. These three checks are what
# keep them data.
if ($analysis -match '(?m)^\s*workflow_dispatch\s*:') {
  # `${{ inputs.x }}` inside a run body is substituted before the shell parses
  # the line, so an input containing shell metacharacters executes as code. The
  # inputs must arrive through env: instead.
  foreach ($runBlock in [regex]::Matches($analysis, '(?ms)^\s*run:\s*\|.*?(?=^\s{6}- |\Z)')) {
    if ($runBlock.Value -match '\$\{\{\s*(?:inputs|github\.event\.inputs)\.') {
      throw 'Analysis workflow interpolates a workflow_dispatch input directly into a run block; pass it through env: instead.'
    }
  }
  $dispatchCollect = [regex]::Match($analysis, "(?ms)^\s{6}- name: Collect the dispatched commit range as data.*?(?=^\s{6}- name: )")
  if (-not $dispatchCollect.Success) { throw 'Analysis workflow declares workflow_dispatch but collects no diff for it.' }
  # The dispatch path must not reuse the pull-request diff source: there is no
  # pull request, and gh pr diff would review the wrong thing or nothing at all.
  if ($dispatchCollect.Value -match 'gh pr diff') { throw 'The dispatched review path must not read a pull-request diff.' }
  foreach ($variable in @('REVIEW_BASE', 'REVIEW_REF')) {
    if ($dispatchCollect.Value -notmatch ("(?m)^\s*" + $variable + ':\s*\$\{\{\s*inputs\.')) { throw "The dispatched review path does not receive $variable from a workflow input through env:." }
  }
  # A revision beginning with a dash is read by git as an option rather than a
  # revision, so the step must reject anything that is not a plain revision.
  if ($dispatchCollect.Value -notmatch "-notmatch\s+'\^\[A-Za-z0-9\]") { throw 'The dispatched review path does not constrain its revisions to a plain-revision pattern.' }
  if ($dispatchCollect.Value -notmatch '(?m)^\s*\$diff = git diff --no-color \$range\s*$') { throw 'The dispatched review path does not build its diff from the validated range.' }
}
if ($publisher -notmatch "workflow_run\.event == 'pull_request_target'") { throw 'Publisher workflow must comment only for pull-request runs; a dispatched run has no pull request.' }
if ($publisher -notmatch '(?m)^\s*workflow_run\s*:') { throw 'Publisher workflow must use workflow_run.' }
if ($publisher -notmatch 'pull-requests:\s*write') { throw 'Publisher workflow must own PR comment permission.' }
if ($publisher -notmatch 'pull_requests\[0\]\.number') { throw 'Publisher workflow must guard against workflow runs without an associated PR.' }
if ($publisher -notmatch 'ref:\s*\$\{\{\s*github\.event\.repository\.default_branch\s*\}\}') { throw 'Publisher workflow must checkout the trusted default branch.' }
Write-Host 'PASS: workflow policy checks succeeded.'
