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

# Git
Check "Git is installed" (Get-Command git -ErrorAction SilentlyContinue) "Install Git for Windows: https://git-scm.com/download/win"
if (Get-Command git -ErrorAction SilentlyContinue) {
    $inside = git rev-parse --is-inside-work-tree 2>$null
    Check "Inside a Git repository" ($inside -eq "true") "Run 'git init' or clone a repository first."
}

# Codex
Check "Codex CLI is installed" (Get-Command codex -ErrorAction SilentlyContinue) "Install with: powershell -ExecutionPolicy ByPass -c `"irm https://chatgpt.com/codex/install.ps1 | iex`""

# Config sanity
$config = Get-Content (Join-Path $HarnessRoot "config\review-config.yaml") -Raw
Check "Config declares sandbox: read-only" ($config -match "(?m)^\s*sandbox\s*:\s*read-only") "Edit config/review-config.yaml and set sandbox: read-only"
Check "Config has a base_branch" ($config -match "(?m)^\s*base_branch\s*:") "Add base_branch: main (or master) to the config"

# Reports directory is writable
$reports = Join-Path $HarnessRoot "reports"
if (-not (Test-Path $reports)) { New-Item -ItemType Directory -Path $reports | Out-Null }
$testFile = Join-Path $reports ".write-test"
try {
    "ok" | Set-Content $testFile -ErrorAction Stop
    Remove-Item $testFile -ErrorAction SilentlyContinue
    Check "reports/ directory is writable" $true ""
} catch {
    Check "reports/ directory is writable" $false "Check folder permissions."
}

Write-Host ""
if ($failed -eq 0) {
    Write-Host "All checks passed. You can run a review with:" -ForegroundColor Green
    Write-Host "  .\scripts\Run-Review.ps1" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "$failed check(s) failed. Fix the issues above and re-run this script." -ForegroundColor Red
    exit 1
}
