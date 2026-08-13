#Requires -Version 5.1
<#
.SYNOPSIS
  Starts a guided, local interface for the read-only review runner.

.DESCRIPTION
  The wizard selects only parameters already supported by Run-Review.ps1. It
  never changes the reviewed repository, grants approval, or applies findings.
  A real review requires the user to type REVIEW after seeing the full plan.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$HarnessRoot = Split-Path -Parent $PSScriptRoot
$RunnerPath = Join-Path $HarnessRoot 'scripts\Run-Review.ps1'
$PromptRoot = Join-Path $HarnessRoot 'prompts'

function Read-MenuChoice([string]$Title, [string[]]$Choices, [int]$DefaultIndex) {
    Write-Host "`n$Title" -ForegroundColor Cyan
    for ($index = 0; $index -lt $Choices.Count; $index++) {
        Write-Host ('  {0}. {1}' -f ($index + 1), $Choices[$index])
    }
    while ($true) {
        $reply = Read-Host ('Choose 1-{0} [{1}]' -f $Choices.Count, ($DefaultIndex + 1))
        if ([string]::IsNullOrWhiteSpace($reply)) { return $DefaultIndex }
        $parsed = 0
        if ([int]::TryParse($reply, [ref]$parsed) -and $parsed -ge 1 -and $parsed -le $Choices.Count) { return ($parsed - 1) }
        Write-Warning 'Enter one of the displayed numbers.'
    }
}

function Read-PositiveInteger([string]$Label, [int]$Default, [int]$Minimum) {
    while ($true) {
        $reply = Read-Host "$Label [$Default]"
        if ([string]::IsNullOrWhiteSpace($reply)) { return $Default }
        $parsed = 0
        if ([int]::TryParse($reply, [ref]$parsed) -and $parsed -ge $Minimum) { return $parsed }
        Write-Warning "$Label must be an integer of at least $Minimum."
    }
}

function Format-Argument([string]$Value) {
    if ($Value -match '[\s"]') { return '"' + ($Value -replace '"', '\"') + '"' }
    return $Value
}

Write-Host 'Codex Repo Review Harness — Guided Review' -ForegroundColor Cyan
Write-Host 'This wizard runs the existing read-only review runner. It cannot apply, approve, or merge changes.'

if (-not (Test-Path -LiteralPath $RunnerPath -PathType Leaf)) { throw "Review runner is missing: $RunnerPath" }
$prompts = @(Get-ChildItem -LiteralPath $PromptRoot -File -Filter '*.md' | Sort-Object Name)
if ($prompts.Count -eq 0) { throw "No prompt files found under $PromptRoot" }
$promptLabels = @($prompts | ForEach-Object { $_.Name })
$defaultPrompt = [array]::IndexOf($promptLabels, 'system-review.md')
if ($defaultPrompt -lt 0) { $defaultPrompt = 0 }
$prompt = $promptLabels[(Read-MenuChoice 'Select a bundled prompt:' $promptLabels $defaultPrompt)]

$targetChoice = Read-MenuChoice 'Select the review target:' @('This harness repository', 'Another local Git repository') 0
$repositoryPath = ''
if ($targetChoice -eq 1) {
    while ($true) {
        $repositoryPath = Read-Host 'Enter the target repository path'
        if (-not [string]::IsNullOrWhiteSpace($repositoryPath) -and (Test-Path -LiteralPath $repositoryPath -PathType Container)) { break }
        Write-Warning 'Enter an existing directory. The runner will confirm that it is inside a Git repository.'
    }
}

$modeChoice = Read-MenuChoice 'Select the run mode:' @('Dry run — prepare the review without invoking Codex', 'Real read-only review') 0
$baseBranch = Read-Host 'Base branch override (press Enter to use config default)'
$timeout = Read-PositiveInteger 'Timeout in seconds' 900 1
$maxOutputBytes = Read-PositiveInteger 'Maximum final-message bytes' 5242880 1024
$diagnosticLogPath = ''
if ((Read-MenuChoice 'Write a redacted diagnostic log?' @('Yes', 'No') 0) -eq 0) {
    $defaultLog = 'reports\diagnostics\wizard-' + (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '.log'
    $diagnosticLogPath = Read-Host "Diagnostic log path beneath the harness root [$defaultLog]"
    if ([string]::IsNullOrWhiteSpace($diagnosticLogPath)) { $diagnosticLogPath = $defaultLog }
}

$runnerArguments = @('-Prompt', $prompt, '-TimeoutSeconds', $timeout, '-MaxOutputBytes', $maxOutputBytes)
if ($repositoryPath) { $runnerArguments += @('-RepositoryPath', $repositoryPath) }
if ($baseBranch) { $runnerArguments += @('-BaseBranch', $baseBranch) }
if ($diagnosticLogPath) { $runnerArguments += @('-DiagnosticLogPath', $diagnosticLogPath) }
if ($modeChoice -eq 0) { $runnerArguments += '-DryRun' }

Write-Host "`nReview plan" -ForegroundColor Cyan
Write-Host "  Prompt: $prompt"
Write-Host ('  Target: {0}' -f $(if ($repositoryPath) { $repositoryPath } else { $HarnessRoot }))
Write-Host ('  Mode: {0}' -f $(if ($modeChoice -eq 0) { 'Dry run' } else { 'Real read-only review' }))
Write-Host "  Timeout: $timeout seconds"
Write-Host "  Output limit: $maxOutputBytes bytes"
Write-Host ('  Diagnostics: {0}' -f $(if ($diagnosticLogPath) { $diagnosticLogPath } else { 'disabled' }))
$previewArguments = @($runnerArguments | ForEach-Object { Format-Argument ([string]$_) }) -join ' '
Write-Host "`nCommand preview: powershell -NoProfile -ExecutionPolicy Bypass -File $(Format-Argument $RunnerPath) $previewArguments"

if ($modeChoice -eq 1) {
    $confirmation = Read-Host 'Type REVIEW to start the real read-only review'
    if ($confirmation -cne 'REVIEW') {
        Write-Host 'Cancelled. No review was started.' -ForegroundColor Yellow
        exit 0
    }
} else {
    $confirmation = Read-Host 'Press Enter to start the dry run, or type CANCEL to stop'
    if ($confirmation -ceq 'CANCEL') {
        Write-Host 'Cancelled. No review was started.' -ForegroundColor Yellow
        exit 0
    }
}

& $RunnerPath @runnerArguments
$exitCode = $LASTEXITCODE
if ($exitCode -eq 0) {
    Write-Host "`nCompleted. Review artifacts, when produced, are listed above." -ForegroundColor Green
} else {
    Write-Warning "The runner stopped with exit code $exitCode. See docs/TROUBLESHOOTING.md and the diagnostic log, if enabled."
}
exit $exitCode
