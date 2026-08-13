#Requires -Version 5.1
<#!
.SYNOPSIS
  Enforces the automated requirements in docs/RELEASE_READINESS_STANDARD.md.

.DESCRIPTION
  The previous version of this gate asserted that certain strings appeared
  somewhere in ci.yml. That passes for a path mentioned only in a comment, for a
  step marked continue-on-error, and for a matrix that dropped a platform, so it
  proved nothing about whether a new user's journey is actually tested. This
  version parses the workflow into steps and reads the runner's own exit codes,
  so every assertion below is about behaviour that CI really enforces.

  Exits 0 when every automated requirement holds; otherwise prints every failure
  and exits 1. It reports all failures in one run rather than stopping at the
  first, so a maintainer fixes the standard in one pass.
#>
param([string]$Root)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$Root = [IO.Path]::GetFullPath($Root)

$script:Failures = New-Object 'System.Collections.Generic.List[string]'
function Add-Failure([string]$Requirement, [string]$Detail) {
  $script:Failures.Add("$Requirement`: $Detail")
}
function Get-RootText([string]$Relative) {
  $path = Join-Path $Root $Relative
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  return [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($path))
}

# --- Workflow parsing -------------------------------------------------------
# A deliberately small reader rather than a YAML library: the harness has no
# package dependencies on purpose, and it must behave identically under Windows
# PowerShell 5.1 and pwsh 7. It understands only the shape this repository's
# workflows actually use — two-space indentation, block steps under a named job.

function Get-WorkflowJobBlock([string]$Text, [string]$JobName) {
  $lines = $Text -split '\r?\n'
  $start = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match ('^  ' + [regex]::Escape($JobName) + ':\s*$')) { $start = $i + 1; break }
  }
  if ($start -lt 0) { return $null }
  $block = @()
  for ($i = $start; $i -lt $lines.Count; $i++) {
    # A non-blank line at two-space indent or less starts the next job.
    if ($lines[$i].Trim() -ne '' -and $lines[$i] -notmatch '^    ') { break }
    $block += $lines[$i]
  }
  return , $block
}

function Get-WorkflowStep([string[]]$JobBlock) {
  $steps = @()
  $current = $null
  $inSteps = $false
  foreach ($line in $JobBlock) {
    if (-not $inSteps) {
      if ($line -match '^    steps:\s*$') { $inSteps = $true }
      continue
    }
    if ($line.Trim() -ne '' -and $line -notmatch '^      ') { break }
    if ($line -match '^      - ') {
      if ($null -ne $current) { $steps += , $current }
      # Normalise the dash away so every key in a step sits at one indent.
      $current = @(($line -replace '^      - ', '        '))
      continue
    }
    if ($null -ne $current) { $current += $line }
  }
  if ($null -ne $current) { $steps += , $current }

  return @($steps | ForEach-Object {
      $lines = $_
      $name = ''
      $condition = ''
      $continueOnError = $false
      $run = New-Object 'System.Collections.Generic.List[string]'
      for ($i = 0; $i -lt $lines.Count; $i++) {
        # Step keys sit at exactly eight spaces. Anything deeper is a value —
        # notably the body of `run: |`, which must never be read as a key.
        if ($lines[$i] -notmatch '^        \S') { continue }
        if ($lines[$i] -match '^        name:\s*(.+?)\s*$') { $name = $Matches[1].Trim('"', "'") }
        elseif ($lines[$i] -match '^        if:\s*(.+?)\s*$') { $condition = $Matches[1] }
        elseif ($lines[$i] -match '^        continue-on-error:\s*(.+?)\s*$') { $continueOnError = ($Matches[1] -notmatch '^(false|"false"|''false'')$') }
        elseif ($lines[$i] -match '^        run:\s*(.*)$') {
          $inline = $Matches[1]
          if ($inline -and $inline -notmatch '^[|>][-+]?\s*$') { $run.Add($inline) }
          for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            if ($lines[$j].Trim() -ne '' -and $lines[$j] -notmatch '^         ') { break }
            $run.Add($lines[$j])
          }
        }
      }
      [pscustomobject]@{
        Name            = $name
        Condition       = $condition
        ContinueOnError = $continueOnError
        Run             = ($run -join "`n")
      }
    })
}

# --- RR-01..RR-06, RR-08: every gate is a real, unconditional CI step --------

# Each entry is one requirement and the evidence that decides it. The step names
# are not matched, only required to exist: a name is for humans reading a failed
# build, while the evidence script is what actually proves the requirement.
$requiredGates = @(
  @{ Id = 'RR-01/02/03'; What = 'proven installation, first review, and target safety'; Evidence = @('tests/test_new_user_journey.ps1') },
  @{ Id = 'RR-04'; What = 'clean-room installation and upgrade'; Evidence = @('tests/test_clean_room.ps1') },
  @{ Id = 'RR-05'; What = 'full user-facing feature set'; Evidence = @('tests/test_runner_failure.ps1', 'tests/test_review_artifacts.ps1', 'tests/test_security_regressions.ps1') },
  @{ Id = 'RR-06'; What = 'tested recovery paths'; Evidence = @('tests/test_recovery_paths.ps1') },
  @{ Id = 'RR-08'; What = 'documentation that resolves against this tree'; Evidence = @('tests/test_guide_digest.ps1', 'scripts/ci/Validate-Release.ps1') },
  @{ Id = 'RR-07/09/10'; What = 'the readiness standard itself'; Evidence = @('scripts/ci/Test-ReleaseReadiness.ps1') }
)

$workflowText = Get-RootText '.github/workflows/ci.yml'
$steps = @()
if ($null -eq $workflowText) {
  Add-Failure 'RR-00' 'The validation workflow .github/workflows/ci.yml is missing.'
} else {
  $jobBlock = Get-WorkflowJobBlock $workflowText 'validate'
  if ($null -eq $jobBlock) {
    Add-Failure 'RR-00' 'ci.yml defines no "validate" job, so no gate below can be required.'
  } else {
    $steps = @(Get-WorkflowStep $jobBlock)
    if ($steps.Count -eq 0) { Add-Failure 'RR-00' 'The validate job declares no steps.' }

    # RR-09: both platforms, or a green build proves only half the standard.
    $matrixLine = [regex]::Match(($jobBlock -join "`n"), '(?m)^\s*os:\s*\[(?<list>[^\]]*)\]\s*$')
    $platforms = if ($matrixLine.Success) { @($matrixLine.Groups['list'].Value -split ',' | ForEach-Object { $_.Trim().Trim('"', "'") }) } else { @() }
    foreach ($platform in @('windows-latest', 'ubuntu-latest')) {
      if ($platforms -notcontains $platform) { Add-Failure 'RR-09' "The validate job's OS matrix does not include ${platform}; cross-platform evidence would be incomplete." }
    }
    if (($jobBlock -join "`n") -match '(?m)^\s{4}continue-on-error:\s*(?!false)') {
      Add-Failure 'RR-09' 'The validate job is continue-on-error, so none of its gates can block a release.'
    }
  }
}

foreach ($gate in $requiredGates) {
  foreach ($evidence in $gate.Evidence) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $evidence))) {
      Add-Failure $gate.Id "Evidence script is missing from the tree: $evidence"
      continue
    }
    # Matched against the run body only. A path in a comment, a step name, or a
    # deleted-but-documented step must not satisfy a requirement.
    $owning = @($steps | Where-Object { $_.Run -match ('(?m)-File\s+' + [regex]::Escape($evidence) + '(\s|$)') })
    if ($owning.Count -eq 0) {
      Add-Failure $gate.Id "CI does not run $evidence, so $($gate.What) is unproven."
      continue
    }
    foreach ($step in $owning) {
      if (-not $step.Name) { Add-Failure $gate.Id "The step running $evidence has no name; a failed build could not say which requirement broke." }
      if ($step.ContinueOnError) { Add-Failure $gate.Id "The step running $evidence is continue-on-error, so $($gate.What) cannot fail the build." }
      if ($step.Condition) { Add-Failure $gate.Id "The step running $evidence is conditional on '$($step.Condition)', so $($gate.What) is not required on every run." }
    }
  }
}

# Coverage stays required but supplemental. If it is the only thing left
# standing, the standard has been hollowed out and this says so.
$coverageStep = @($steps | Where-Object { $_.Run -match 'Test-SourceCoverage\.ps1' })
if ($coverageStep.Count -eq 0) { Add-Failure 'RR-COVERAGE' 'The supplemental source-coverage step is missing from CI.' }

# --- RR-07: every failure a user can hit has a documented way out ------------

$guides = [ordered]@{
  'WINDOWS_NOVICE_USABILITY_GUIDE.md' = 'WIN'
  'LINUX_NOVICE_USABILITY_GUIDE.md'   = 'LNX'
}

# Read the codes out of the runner instead of hard-coding them: adding a new
# Fail path then fails this gate until both guides document it.
$runnerText = Get-RootText 'scripts/Run-Review.ps1'
$exitCodes = @()
if ($null -eq $runnerText) {
  Add-Failure 'RR-07' 'scripts/Run-Review.ps1 is missing; the documented exit codes cannot be checked against it.'
} else {
  $exitCodes = @([regex]::Matches($runnerText, '(?m)\bFail\s+(\d+)\b') | ForEach-Object { [int]$_.Groups[1].Value } | Sort-Object -Unique)
  if ($exitCodes.Count -eq 0) { Add-Failure 'RR-07' 'No stable exit codes could be read from scripts/Run-Review.ps1.' }
}

function Get-TroubleshootingRow([string]$GuideText, [string]$Prefix) {
  # Column positions come from the table's own header, so reordering or adding a
  # column cannot silently move the check onto the wrong cell.
  $rows = @{}
  $header = [regex]::Match($GuideText, '(?m)^\|\s*ID\s*\|.*Verification command.*\|\s*$')
  if (-not $header.Success) { return $null }
  $headerCells = [string[]]@($header.Value.Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
  $actionIndex = [array]::FindIndex($headerCells, [Predicate[string]] { param($c) $c -match '(?i)corrective' })
  $verifyIndex = [array]::FindIndex($headerCells, [Predicate[string]] { param($c) $c -match '(?i)^verification command$' })
  if ($actionIndex -lt 0 -or $verifyIndex -lt 0) { return $null }
  foreach ($match in [regex]::Matches($GuideText, ('(?m)^\|\s*`(' + $Prefix + '-TRB-\d+)`\s*\|.*$'))) {
    $cells = @($match.Value.Trim().Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
    if ($cells.Count -le [Math]::Max($actionIndex, $verifyIndex)) { continue }
    $rows[$match.Groups[1].Value] = [pscustomobject]@{
      Action       = $cells[$actionIndex]
      Verification = $cells[$verifyIndex]
    }
  }
  return $rows
}

foreach ($guide in $guides.Keys) {
  $prefix = $guides[$guide]
  $relative = "docs/guides/$guide"
  $text = Get-RootText $relative
  if ($null -eq $text) { Add-Failure 'RR-08' "Canonical novice guide is missing: $relative"; continue }

  $rows = Get-TroubleshootingRow $text $prefix
  if ($null -eq $rows) {
    Add-Failure 'RR-07' "$guide has no troubleshooting table with an 'Exact corrective steps' and a 'Verification command' column."
    $rows = @{}
  }

  foreach ($code in $exitCodes) {
    $tableRow = [regex]::Match($text, ('(?m)^\|\s*`' + $code + '`\s*\|.*$'))
    if (-not $tableRow.Success) {
      Add-Failure 'RR-07' "$guide does not list runner exit code $code in its exit-code table."
      continue
    }
    $referenced = @([regex]::Matches($tableRow.Value, ($prefix + '-TRB-\d+')) | ForEach-Object { $_.Value } | Sort-Object -Unique)
    if ($referenced.Count -eq 0) {
      Add-Failure 'RR-07' "$guide documents exit code $code but points at no troubleshooting row, so the user is told what happened and not what to do."
      continue
    }
    foreach ($id in $referenced) {
      if (-not $rows.ContainsKey($id)) { Add-Failure 'RR-07' "$guide sends exit code $code to $id, which is not a row in the troubleshooting table."; continue }
      if (-not $rows[$id].Action) { Add-Failure 'RR-07' "$guide row $id (exit code $code) has no corrective action." }
      if (-not $rows[$id].Verification) { Add-Failure 'RR-07' "$guide row $id (exit code $code) has no verification command, so the user cannot confirm the fix worked." }
    }
  }

  # RR-08: a guide that names a file this tree does not have is a guide that
  # will strand a new user on the step that names it.
  $cited = @([regex]::Matches($text, '(?<![\w./\\-])((?:\.github/workflows|scripts|tests|prompts|config|schemas|templates|docs|agents)[/\\][A-Za-z0-9_./\\-]*\.(?:ps1|md|yaml|yml|json))') |
    ForEach-Object { $_.Groups[1].Value.Replace('\', '/') } |
    Where-Object { $_ -notmatch '[*?]' -and $_ -notmatch 'YOUR_' } |
    Sort-Object -Unique)
  foreach ($path in $cited) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $path))) {
      Add-Failure 'RR-08' "$guide cites a path that does not exist in this tree: $path"
    }
  }

  # A guide that names a commit is a guide that starts lying on the next commit.
  # The project already replaced commit pinning with reviewed_digest, and the
  # leftover SHAs had drifted into contradicting each other: the front matter and
  # the body named different commits (REV-DOC-006).
  foreach ($sha in @([regex]::Matches($text, '(?<![0-9a-fA-F])[0-9a-f]{40}(?![0-9a-fA-F])') | ForEach-Object { $_.Value } | Sort-Object -Unique)) {
    Add-Failure 'RR-08' "$guide pins commit ${sha}; freshness is tracked by reviewed_digest, so a commit SHA can only go stale or contradict it."
  }
  # Line numbers in a file that changes every release rot silently. The same
  # finding caught both guides citing Run-Review.ps1 lines 79-80 for the
  # read-only sandbox long after that code had moved.
  foreach ($citation in @([regex]::Matches($text, '`(scripts/[A-Za-z0-9_.-]+\.ps1)`\s+lines?\s+\d+') | ForEach-Object { $_.Value } | Sort-Object -Unique)) {
    Add-Failure 'RR-08' "$guide cites a line number that will not survive the next edit: $citation. Reference a parameter, function, or behaviour instead."
  }

  foreach ($topic in @(@{ Label = 'update'; Pattern = '(?i)##[^\n]*(update|upgrade)' }, @{ Label = 'uninstall'; Pattern = '(?i)##[^\n]*(uninstall|cleanup|remove)' }, @{ Label = 'rollback'; Pattern = '(?i)rollback' })) {
    if ($text -notmatch $topic.Pattern) { Add-Failure 'RR-08' "$guide documents no $($topic.Label) path." }
  }
}

# --- RR-10: the independent review workflow still exists ---------------------

$reviewWorkflow = Get-RootText '.github/workflows/codex-review.yml'
if ($null -eq $reviewWorkflow) {
  Add-Failure 'RR-10' 'The independent review workflow .github/workflows/codex-review.yml is missing.'
} elseif ($reviewWorkflow -notmatch '(?m)^  analyze:\s*$') {
  Add-Failure 'RR-10' 'The independent review workflow no longer defines the "analyze" job.'
}

# --- The standard document and the enforcer must describe the same gates -----

$standard = Get-RootText 'docs/RELEASE_READINESS_STANDARD.md'
if ($null -eq $standard) {
  Add-Failure 'RR-00' 'docs/RELEASE_READINESS_STANDARD.md is missing; there is no standard to enforce.'
} else {
  foreach ($id in @('RR-01', 'RR-02', 'RR-03', 'RR-04', 'RR-05', 'RR-06', 'RR-07', 'RR-08', 'RR-09', 'RR-10', 'RR-11', 'RR-12')) {
    if ($standard -notmatch ('(?m)^##\s+' + $id + '\b')) { Add-Failure 'RR-00' "The standard has no $id section, but this gate enforces one." }
  }
  foreach ($gate in $requiredGates) {
    foreach ($evidence in $gate.Evidence) {
      if ($standard -notmatch [regex]::Escape($evidence)) { Add-Failure 'RR-00' "The standard does not name the evidence CI runs for $($gate.Id): $evidence" }
    }
  }
  # RR-11 is the one requirement CI cannot stand in for, so losing it from the
  # document would quietly convert a human sign-off into nothing at all.
  if ($standard -notmatch '(?i)real-Codex smoke test') { Add-Failure 'RR-11' 'The standard no longer requires a human real-Codex smoke test.' }
  if ($standard -notmatch '(?i)coverage is supplemental|never the release decision') { Add-Failure 'RR-00' 'The standard no longer states that source coverage is supplemental.' }
}

# --- Report -----------------------------------------------------------------

if ($script:Failures.Count -gt 0) {
  [Console]::Error.WriteLine("FAIL: $($script:Failures.Count) release-readiness requirement(s) are not met:")
  foreach ($failure in $script:Failures) { [Console]::Error.WriteLine("  - $failure") }
  if ($env:GITHUB_STEP_SUMMARY) {
    Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value ("## Release readiness: NOT MET`n`n" + (($script:Failures | ForEach-Object { "- $_" }) -join "`n"))
  }
  exit 1
}

$codeList = ($exitCodes -join ', ')
if ($env:GITHUB_STEP_SUMMARY) {
  Add-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Value @"
## Release readiness: automated requirements met

| Requirement | Proof |
| --- | --- |
| RR-01/02/03 installation, first review, target safety | required CI step |
| RR-04 clean-room installation and upgrade | required CI step |
| RR-05 full user-facing feature set | required CI step |
| RR-06 tested recovery paths | required CI step |
| RR-07 guided troubleshooting | exit codes $codeList documented with a fix and a verification command in both guides |
| RR-08 documentation resolves against this tree | required CI step, cited paths verified |
| RR-09 cross-platform | windows-latest and ubuntu-latest |
| RR-10 independent review | analyze job present (not a required status check — see RR-10) |

RR-11 (real-Codex smoke test) and RR-12 (no unresolved blocking findings) are
human sign-offs and are **not** covered by this run.
"@
}
Write-Host "PASS: automated release-readiness requirements RR-01..RR-10 hold (runner exit codes $codeList documented in both guides)."
Write-Host 'Still required before release: RR-11 real-Codex smoke test and RR-12 no unresolved blocking findings.'
