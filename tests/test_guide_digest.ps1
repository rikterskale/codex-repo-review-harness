#Requires -Version 5.1
<#
  Contract for the guide freshness check.

  The previous check recorded a commit SHA, which forced every change into two
  commits (a commit cannot contain its own hash) and did not survive squash,
  rebase, or merge-commit strategies, because all three rewrite or discard the
  SHA the guides named. The digest replaces it, and these are the properties
  that make that work:

    - a change to the surface the guides describe invalidates the digest
    - editing a guide does not, so a guide and its digest fit in one commit
    - a change outside that surface does not force guide churn
    - the digest does not depend on line endings, so both CI runners agree
#>
$ErrorActionPreference = 'Stop'
$psExe = (Get-Process -Id $PID).Path
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'scripts\ci\Review-Helpers.ps1')
$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-digest-' + [guid]::NewGuid().ToString('N'))

function Invoke-ValidateRelease {
  # Called for runs that are expected to fail, and a failing child writes to
  # stderr, which Windows PowerShell 5.1 would raise as a terminating error
  # before the exit code could be read.
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $null = & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\ci\Validate-Release.ps1') 2>$null
    return $LASTEXITCODE
  } finally { $ErrorActionPreference = $previous }
}

New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
  Get-ChildItem $root -Force |
    Where-Object { $_.Name -notin @('.git', 'reports', 'review-input', 'review-output', 'logs') } |
    Copy-Item -Destination $temp -Recurse -Force

  if ((Invoke-ValidateRelease) -ne 0) { throw 'Validate-Release rejected an unmodified tree.' }

  # Editing a guide must not change the digest, or the guide could never record
  # its own digest in one commit, which is the entire point of the mechanism.
  $guide = Join-Path $temp 'docs\guides\LINUX_NOVICE_USABILITY_GUIDE.md'
  Add-Content -LiteralPath $guide -Value 'Prose appended by the digest contract test.'
  if ((Invoke-ValidateRelease) -ne 0) { throw 'A guide edit changed the digest; the guides are not excluded from their own subject set.' }

  # A change outside the described surface must not force guide churn. The
  # guides mention templates only inside directory listings, so a file inside
  # one cannot falsify a claim.
  Add-Content -LiteralPath (Join-Path $temp 'CHANGELOG.md') -Value ''
  Add-Content -LiteralPath (Join-Path $temp 'templates\report-skeleton.md') -Value ''
  if ((Invoke-ValidateRelease) -ne 0) { throw 'A change outside the guides'' subject surface invalidated the digest.' }

  # Every family the guides cite by name or line number must invalidate the
  # digest. Tests and schemas are here because the Linux guide lists individual
  # test scripts and cites the report schema by line.
  foreach ($file in @('config\review-config.yaml', 'tests\test_clean_room.ps1', 'schemas\review-report.schema.json', 'prompts\system-review.md', 'scripts\Run-Review.ps1')) {
    $path = Join-Path $temp $file
    $original = [IO.File]::ReadAllBytes($path)
    Add-Content -LiteralPath $path -Value '# digest contract test'
    if ((Invoke-ValidateRelease) -eq 0) { throw "A change to $file did not invalidate the guide digest." }
    [IO.File]::WriteAllBytes($path, $original)
    if ((Invoke-ValidateRelease) -ne 0) { throw "Restoring $file did not restore the digest; the digest is not a pure function of content." }
  }

  # GitHub Actions runs both extensions, so both must be in the subject set.
  foreach ($extension in @('yml', 'yaml')) {
    $probe = Join-Path $temp ".github\workflows\digest-probe.$extension"
    Set-Content -LiteralPath $probe -Value '# digest contract probe' -Encoding UTF8
    $changed = ((Invoke-ValidateRelease) -ne 0)
    Remove-Item -LiteralPath $probe -Force
    if (-not $changed) { throw "A .$extension workflow did not invalidate the guide digest." }
  }
  if ((Invoke-ValidateRelease) -ne 0) { throw 'Removing the workflow probes did not restore the digest.' }

  # Leave the tree stale for the update step below.
  Add-Content -LiteralPath (Join-Path $temp 'config\review-config.yaml') -Value '# digest contract test'
  if ((Invoke-ValidateRelease) -eq 0) { throw 'Validate-Release accepted a guide recorded against a stale harness surface.' }

  # And the recorded update must clear it, without needing a second commit.
  & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\ci\Update-GuideDigest.ps1') | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Update-GuideDigest.ps1 failed.' }
  if ((Invoke-ValidateRelease) -ne 0) { throw 'Validate-Release still rejected the tree after the digest was updated.' }

  # Re-running on a current tree must succeed. Validate-Release names this
  # script in its failure message, so a second run has to be safe.
  & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\ci\Update-GuideDigest.ps1') | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Update-GuideDigest.ps1 is not idempotent; a second run failed.' }
  if ((Invoke-ValidateRelease) -ne 0) { throw 'Validate-Release rejected the tree after a repeat digest update.' }

  # Line endings must not move the digest, or the Ubuntu and Windows runners
  # would disagree about an identical tree.
  $prompt = Join-Path $temp 'prompts\system-review.md'
  $before = Get-GuideDigest $temp
  $text = [IO.File]::ReadAllText($prompt)
  [IO.File]::WriteAllText($prompt, ($text -replace "`r`n", "`n"))
  if ((Get-GuideDigest $temp) -ne $before) { throw 'Digest changed when line endings changed; the two CI runners would disagree.' }
  [IO.File]::WriteAllText($prompt, ($text -replace "(?<!`r)`n", "`r`n"))
  if ((Get-GuideDigest $temp) -ne $before) { throw 'Digest changed when line endings changed; the two CI runners would disagree.' }

  Write-Host 'PASS: guide digest tracks the harness surface and ignores the guides themselves.'
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
