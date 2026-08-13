#Requires -Version 5.1
# Regressions for the two ways the analysis workflow silently failed:
# a sandbox override that the action outranked, and a missing credential that
# surfaced as an unrelated crash inside the action.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$analysis = Get-Content (Join-Path $root '.github\workflows\codex-review.yml') -Raw
$ci = Get-Content (Join-Path $root '.github\workflows\ci.yml') -Raw

if ($ci -notmatch "Get-ChildItem -LiteralPath tests -Filter 'test_\*\.ps1' -File") { throw 'CI must discover every test_*.ps1 file rather than maintaining a partial list.' }
if ($ci -notmatch 'Test-SourceCoverage\.ps1 -MinimumCoverage 100') { throw 'CI must enforce the 100% production-source coverage threshold.' }

# codex-action appends its own --sandbox argument after the codex-args
# pass-through, defaulting to workspace-write, so a sandbox selected through
# codex-args is silently outranked and the review runs write-enabled.
if ($analysis -notmatch '(?m)^\s*sandbox:\s*read-only\s*$') { throw 'Analysis workflow no longer pins the sandbox through the action input.' }
if ($analysis -match '(?m)^\s*codex-args:.*(--sandbox|(?<![\w-])-s(?![\w-])|sandbox_mode)') { throw 'Analysis workflow selects a sandbox through codex-args, which the action overrides with its own default.' }

# The preflight must run before Codex and must receive only whether the secret
# is set, never its value.
$credentialCheck = [regex]::Match($analysis, '(?m)^\s*REVIEW_CREDENTIAL_PRESENT:\s*\$\{\{\s*secrets\.OPENAI_API_KEY\s*!=\s*''''\s*\}\}\s*$')
if (-not $credentialCheck.Success) { throw 'Analysis workflow no longer verifies the review credential by presence alone.' }
$codexAction = [regex]::Match($analysis, '(?m)^\s*uses:\s*openai/codex-action@')
if ($codexAction.Success -and $credentialCheck.Index -gt $codexAction.Index) { throw 'Credential preflight no longer runs before Codex is invoked.' }
if ($analysis -notmatch '::error::[^\r\n]*OPENAI_API_KEY') { throw 'Credential preflight failure does not name the missing secret as a workflow error.' }
if ($analysis -notmatch 'gh secret set OPENAI_API_KEY') { throw 'Credential preflight failure does not tell the reader how to fix it.' }

# A workflow using the .yaml spelling must not escape the policy checks. Only
# matching .yml would have let an unpinned action with write permissions run
# without any of the assertions in Validate-WorkflowPolicy.ps1 applying to it.
$psExe = (Get-Process -Id $PID).Path
$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-workflow-ext-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
  Get-ChildItem $root -Force |
    Where-Object { $_.Name -notin @('.git', 'reports', 'review-input', 'review-output', 'logs') } |
    Copy-Item -Destination $temp -Recurse -Force

  $previousErrorAction = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\ci\Validate-WorkflowPolicy.ps1') 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Workflow policy rejected an unmodified copy of the repository.' }

    foreach ($extension in @('yml', 'yaml')) {
      $rogue = Join-Path $temp ".github\workflows\rogue.$extension"
      # Unpinned action, no permissions block, no timeout: every assertion the
      # validator makes is violated at once.
      Set-Content -LiteralPath $rogue -Encoding UTF8 -Value @'
name: Rogue
on: push
jobs:
  rogue:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
'@
      & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\ci\Validate-WorkflowPolicy.ps1') 2>&1 | Out-Null
      $accepted = ($LASTEXITCODE -eq 0)
      Remove-Item -LiteralPath $rogue -Force
      if ($accepted) { throw "A non-compliant .$extension workflow bypassed the workflow policy checks." }
    }

    # The on-demand review path is maintainer-triggered, so its inputs are
    # trusted at the level of a push — but only for as long as they stay data.
    # Each mutation below is a way that stops being true.
    $analysisPath = Join-Path $temp '.github\workflows\codex-review.yml'
    $original = [IO.File]::ReadAllBytes($analysisPath)
    $analysisText = [Text.Encoding]::UTF8.GetString($original)
    $mutations = @(
      @{ Why = 'a dispatch input interpolated straight into a run block'
        Text = $analysisText -replace '(?m)^(\s*)\$range = .*$', '$1$range = "${{ inputs.base }}..${{ inputs.ref }}"' },
      @{ Why = 'the plain-revision guard removed'
        Text = $analysisText -replace "(?m)^\s*if \(\`$value -notmatch '\^\[A-Za-z0-9\].*$", '' },
      @{ Why = 'the dispatched range replaced by a pull-request diff'
        Text = $analysisText -replace '(?m)^(\s*)\$diff = git diff --no-color \$range\s*$', '$1$diff = gh pr diff 1' },
      @{ Why = 'the publisher commenting on runs that have no pull request'
        Path = (Join-Path $temp '.github\workflows\codex-review-comment.yml') }
    )
    foreach ($mutation in $mutations) {
      $path = if ($mutation.Path) { $mutation.Path } else { $analysisPath }
      $before = [IO.File]::ReadAllBytes($path)
      $text = if ($mutation.Text) { $mutation.Text } else {
        ([Text.Encoding]::UTF8.GetString($before) -replace "workflow_run\.event == 'pull_request_target' && ", '')
      }
      if ($text -eq [Text.Encoding]::UTF8.GetString($before)) { throw "The mutation for '$($mutation.Why)' changed nothing; the check would pass vacuously." }
      [IO.File]::WriteAllBytes($path, (New-Object Text.UTF8Encoding($false)).GetBytes($text))
      try {
        & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\ci\Validate-WorkflowPolicy.ps1') 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { throw "Workflow policy accepted $($mutation.Why)." }
      } finally { [IO.File]::WriteAllBytes($path, $before) }
    }
    & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\ci\Validate-WorkflowPolicy.ps1') 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Restoring the dispatch mutations did not restore workflow policy.' }
  } finally { $ErrorActionPreference = $previousErrorAction }
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'PASS: sandbox pinning, credential preflight, and workflow discovery hold.'
