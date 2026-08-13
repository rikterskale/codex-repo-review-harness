#Requires -Version 5.1
<#
  Contract for the release-readiness gate.

  Asserting only that the gate passes on a good tree would not distinguish it
  from a script that prints PASS unconditionally — which is roughly what the
  previous substring-matching version amounted to. Every case below breaks one
  requirement in docs/RELEASE_READINESS_STANDARD.md in a copy of the tree and
  requires the gate to notice, then restores the tree and requires the gate to
  go green again. The restore half matters: it proves the failure came from the
  mutation and that the gate is a pure function of the tree.
#>
$ErrorActionPreference = 'Stop'
$psExe = (Get-Process -Id $PID).Path
$root = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-readiness-' + [guid]::NewGuid().ToString('N'))

$workflowPath = Join-Path $temp '.github\workflows\ci.yml'
$reviewWorkflowPath = Join-Path $temp '.github\workflows\codex-review.yml'
$runnerPath = Join-Path $temp 'scripts\Run-Review.ps1'
$standardPath = Join-Path $temp 'docs\RELEASE_READINESS_STANDARD.md'
$windowsGuidePath = Join-Path $temp 'docs\guides\WINDOWS_NOVICE_USABILITY_GUIDE.md'
$linuxGuidePath = Join-Path $temp 'docs\guides\LINUX_NOVICE_USABILITY_GUIDE.md'

function Invoke-Readiness {
  # A failing child writes to stderr, which Windows PowerShell 5.1 would raise
  # as a terminating error before the exit code could be read.
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $null = & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\ci\Test-ReleaseReadiness.ps1') 2>$null
    return $LASTEXITCODE
  } finally { $ErrorActionPreference = $previous }
}

function Read-Text([string]$Path) { return [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($Path)) }
function Write-Text([string]$Path, [string]$Text) { [IO.File]::WriteAllBytes($Path, (New-Object Text.UTF8Encoding($false)).GetBytes($Text)) }

# Applies one mutation, requires the gate to reject the tree, then restores the
# file and requires the gate to accept it again.
function Assert-Rejects([string]$Requirement, [string]$Path, [scriptblock]$Mutate) {
  $original = [IO.File]::ReadAllBytes($Path)
  try {
    $mutated = & $Mutate (Read-Text $Path)
    if ($mutated -eq (Read-Text $Path)) { throw "$Requirement mutation changed nothing; the test would pass vacuously." }
    Write-Text $Path $mutated
    if ((Invoke-Readiness) -eq 0) { throw "Release readiness accepted a tree that violates ${Requirement}." }
  } finally { [IO.File]::WriteAllBytes($Path, $original) }
  if ((Invoke-Readiness) -ne 0) { throw "Restoring the $Requirement mutation did not restore readiness; the gate is not a pure function of the tree." }
}

# Blanks one cell of a Markdown table row, addressed by the row's leading id.
function Clear-TableCell([string]$Text, [string]$RowId, [int]$CellIndex) {
  $lines = $Text -split "`n"
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -notmatch ('^\|\s*`' + [regex]::Escape($RowId) + '`\s*\|')) { continue }
    $eol = if ($lines[$i].EndsWith("`r")) { "`r" } else { '' }
    $cells = @($lines[$i].TrimEnd("`r").Trim().Trim('|') -split '\|')
    if ($cells.Count -le $CellIndex) { throw "Row $RowId has no cell $CellIndex." }
    $cells[$CellIndex] = ' '
    $lines[$i] = '|' + ($cells -join '|') + '|' + $eol
    return ($lines -join "`n")
  }
  throw "Row $RowId was not found."
}

New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
  Get-ChildItem $root -Force |
    Where-Object { $_.Name -notin @('.git', '.claude', 'reports', 'review-input', 'review-output', 'logs') } |
    Copy-Item -Destination $temp -Recurse -Force

  if ((Invoke-Readiness) -ne 0) { throw 'Release readiness rejected an unmodified tree.' }

  # RR-04: a requirement whose named CI step is deleted is not enforced, even
  # though the aggregate "run every test" step still happens to run the script.
  Assert-Rejects 'RR-04 (named gate deleted)' $workflowPath {
    param($text)
    $text -replace "(?m)^      - name: 'RR-04.*\r?\n(?:        .*\r?\n)+", ''
  }

  # The failure the old substring gate could not see: the evidence script is
  # still named in the file, but only in a comment, so nothing runs it.
  Assert-Rejects 'RR-04 (evidence demoted to a comment)' $workflowPath {
    param($text)
    $text -replace '(?m)^(\s*)run: pwsh -NoProfile -File tests/test_clean_room\.ps1\s*$', '$1run: echo "see tests/test_clean_room.ps1"'
  }

  # RR-06: a gate that cannot fail the build is not a gate.
  Assert-Rejects 'RR-06 (gate made continue-on-error)' $workflowPath {
    param($text)
    $text -replace "(?m)^(      - name: 'RR-06.*\r?\n)", "`$1        continue-on-error: true`r`n"
  }

  # RR-01: nor is one that is skipped on most runs.
  Assert-Rejects 'RR-01 (gate made conditional)' $workflowPath {
    param($text)
    $text -replace "(?m)^(      - name: 'RR-01.*\r?\n)", "`$1        if: `${{ github.event_name == 'workflow_dispatch' }}`r`n"
  }

  # RR-09: one platform's evidence must not stand in for the other's.
  Assert-Rejects 'RR-09 (platform dropped from the matrix)' $workflowPath {
    param($text)
    $text -replace '(?m)^(\s*)os: \[ubuntu-latest, windows-latest\]\s*$', '$1os: [ubuntu-latest]'
  }

  # RR-07: a new runner failure mode must not ship undocumented. The exit-code
  # set is read out of the runner, so adding one here is enough to break it.
  Assert-Rejects 'RR-07 (undocumented runner exit code)' $runnerPath {
    param($text)
    $text + "`nif (`$false) { Fail 8 'Undocumented failure mode.' }`n"
  }

  # RR-07: a documented code that points at a troubleshooting row which does
  # not exist tells the user what broke and not what to do about it.
  Assert-Rejects 'RR-07 (dangling troubleshooting reference)' $linuxGuidePath {
    param($text)
    $text -replace '(?m)^\|\s*`LNX-TRB-009`\s*\|.*\r?\n', ''
  }

  # RR-07: and a row with no verification command leaves the user unable to
  # confirm the fix worked. Cell 5 is the Verification command column.
  Assert-Rejects 'RR-07 (troubleshooting row without a verification command)' $windowsGuidePath {
    param($text)
    Clear-TableCell $text 'WIN-TRB-006' 5
  }

  # RR-08: a guide that names a file this tree does not have will strand a new
  # user on the step that names it.
  Assert-Rejects 'RR-08 (guide cites a path that does not exist)' $linuxGuidePath {
    param($text)
    $text + "`nRun ``scripts/Nonexistent-Step.ps1`` to finish.`n"
  }

  # RR-08: freshness is tracked by reviewed_digest, so a commit SHA in a guide
  # can only go stale or contradict it — which is exactly what happened.
  Assert-Rejects 'RR-08 (guide pins a commit SHA)' $linuxGuidePath {
    param($text)
    $text + "`nThis guide describes commit ``26cc06cf96cd2a854fe1f3fc9bc3c461b45f73c9``.`n"
  }

  # RR-08: and a line-number citation rots on the next edit of the file it names.
  Assert-Rejects 'RR-08 (guide cites a source line number)' $windowsGuidePath {
    param($text)
    $text + "`nThe sandbox is forced by ``scripts/Run-Review.ps1`` lines 79-80.`n"
  }

  # RR-10: the independent review job the standard requires as a status check.
  Assert-Rejects 'RR-10 (analyze job removed)' $reviewWorkflowPath {
    param($text)
    $text -replace '(?m)^  analyze:\s*$', '  review:'
  }

  # RR-11 is the one requirement CI cannot stand in for; dropping it from the
  # document would silently convert a human sign-off into nothing at all.
  Assert-Rejects 'RR-11 (human smoke test removed from the standard)' $standardPath {
    param($text)
    $text -replace '(?i)real-Codex smoke test', 'optional check'
  }

  # The standard and the gate must describe the same requirements, or the
  # document stops being the thing CI enforces.
  Assert-Rejects 'RR-00 (standard drops a requirement the gate enforces)' $standardPath {
    param($text)
    $text -replace '(?m)^## RR-06\b', '## Recovery'
  }

  Write-Host 'PASS: the release-readiness gate rejects every violation of the standard it claims to enforce.'
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
