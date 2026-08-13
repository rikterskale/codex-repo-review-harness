#Requires -Version 5.1
<#
.SYNOPSIS
  Validates that the Codex Repo Review Harness is correctly installed and ready.
#>

$ErrorActionPreference = "Stop"
$HarnessRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $HarnessRoot

$failed = 0

function Check($name, $condition, $fixHint) {
    if ($condition) {
        Write-Host "[PASS] $name" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $name" -ForegroundColor Red
        Write-Host "       $fixHint" -ForegroundColor Yellow
        $script:failed++
    }
}

Write-Host "`n=== Codex Repo Review Harness Validation ===`n" -ForegroundColor Cyan

# Required files
$required = @(
    "config\review-config.yaml",
    "prompts\system-review.md",
    "prompts\security-focus.md",
    "prompts\pr-diff-review.md",
    "AGENTS.md",
    "scripts\Run-Review.ps1",
    "scripts\Validate-Harness.ps1"
)

foreach ($rel in $required) {
    $full = Join-Path $HarnessRoot $rel
    Check "File exists: $rel" (Test-Path $full) "Restore the missing file from the harness template."
}

# A fix hint the reader cannot act on is worse than none. This script runs on
# Linux too, where it used to print a Windows PowerShell installer command
# (REV-DOC-005). $IsWindows does not exist in Windows PowerShell 5.1, so the
# platform is read from the runtime instead.
$onWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)

# Git
$gitHint = if ($onWindows) {
    "Install Git for Windows: https://git-scm.com/download/win"
} else {
    "Install Git with your system package manager, for example: sudo apt install git"
}
Check "Git is installed" (Get-Command git -ErrorAction SilentlyContinue) $gitHint
if (Get-Command git -ErrorAction SilentlyContinue) {
    $inside = git rev-parse --is-inside-work-tree 2>$null
    Check "Inside a Git repository" ($inside -eq "true") "Run 'git init' or clone a repository first."
}

# Codex installation and authentication are external to this repository. Do not
# present an unverified external installer as a supported setup procedure.
$codexHint = if ($onWindows) {
    'Obtain your maintainer-approved Codex setup instructions for Windows, then re-run this script.'
} else {
    'This repository has no verified Linux Codex setup procedure. Obtain maintainer-approved instructions, then re-run this script.'
}
Check "Codex CLI is installed" (Get-Command codex -ErrorAction SilentlyContinue) $codexHint

# Config sanity
$config = Get-Content (Join-Path $HarnessRoot "config\review-config.yaml") -Raw
Check "Config declares sandbox: read-only" ($config -match "(?m)^\s*sandbox\s*:\s*read-only") "Edit config/review-config.yaml and set sandbox: read-only"
Check "Config has a base_branch" ($config -match "(?m)^\s*base_branch\s*:") "Add base_branch: main (or master) to the config"

# Reports directory is present. Do not write a probe file: validation itself is
# read-only; the review runner is the component authorized to create reports.
$reports = Join-Path $HarnessRoot "reports"
Check "reports/ directory exists" (Test-Path $reports) "Create the reports directory before running a review."

Write-Host ""
if ($failed -eq 0) {
    Write-Host "All checks passed. You can run a review with:" -ForegroundColor Green
    Write-Host "  .\scripts\Run-Review.ps1" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "$failed check(s) failed. Fix the issues above and re-run this script." -ForegroundColor Red
    exit 1
}
