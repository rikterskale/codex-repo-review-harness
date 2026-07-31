#Requires -Version 5.1
<#
.SYNOPSIS
  Codex Repo Review Harness – Windows runner (read-only by default)

.DESCRIPTION
  This script launches a Codex review against the current repository.
  It is deliberately conservative:
  - Forces read-only sandbox
  - Never modifies source files
  - Writes only a timestamped report under ./reports/

.PARAMETER Prompt
  Which prompt file to use (relative to prompts/). Default: system-review.md

.PARAMETER BaseBranch
  Override the base branch from config. Default: value from review-config.yaml or "main"

.PARAMETER DryRun
  Only validate the environment and print the command that would be run.

.EXAMPLE
  .\scripts\Run-Review.ps1

.EXAMPLE
  .\scripts\Run-Review.ps1 -Prompt security-focus.md

.EXAMPLE
  .\scripts\Run-Review.ps1 -DryRun
#>

param(
    [string]$Prompt = "system-review.md",
    [string]$BaseBranch = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$HarnessRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $HarnessRoot

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    WARN: $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "    ERROR: $msg" -ForegroundColor Red }

Write-Step "Codex Repo Review Harness (read-only)"
Write-Host "    Working directory: $HarnessRoot"

# ------------------------------------------------------------------
# 1. Basic environment checks
# ------------------------------------------------------------------
Write-Step "Checking prerequisites"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Err "Git is not installed or not on PATH."
    Write-Host "    Install Git for Windows from https://git-scm.com/download/win"
    exit 1
}
Write-Ok "Git found: $(git --version)"

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Write-Err "Codex CLI is not installed or not on PATH."
    Write-Host "    Run the official installer:"
    Write-Host '    powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"'
    exit 1
}
Write-Ok "Codex found: $(codex --version 2>$null)"

# Are we inside a git repo?
$gitTop = git rev-parse --show-toplevel 2>$null
if (-not $gitTop) {
    Write-Err "This folder is not inside a Git repository."
    Write-Host "    Initialize one with:  git init"
    exit 1
}
Write-Ok "Git repository root: $gitTop"

# ------------------------------------------------------------------
# 2. Load configuration (simple YAML-ish parse – no external deps)
# ------------------------------------------------------------------
Write-Step "Loading configuration"
$configPath = Join-Path $HarnessRoot "config\review-config.yaml"
if (-not (Test-Path $configPath)) {
    Write-Err "Missing config file: $configPath"
    exit 1
}

# Very small parser for the keys we care about
$configText = Get-Content $configPath -Raw
function Get-YamlValue($text, $key, $default = "") {
    if ($text -match "(?m)^\s*${key}\s*:\s*[`"']?([^`"'\r\n#]+)") {
        return $Matches[1].Trim()
    }
    return $default
}

$cfgBase   = Get-YamlValue $configText "base_branch" "main"
$cfgSandbox = Get-YamlValue $configText "sandbox" "read-only"
$cfgOutDir  = Get-YamlValue $configText "output_dir" "reports"

if ($BaseBranch -eq "") { $BaseBranch = $cfgBase }

if ($cfgSandbox -ne "read-only") {
    Write-Warn "Config sandbox is '$cfgSandbox'. Forcing read-only for safety."
    $cfgSandbox = "read-only"
}
Write-Ok "base_branch = $BaseBranch"
Write-Ok "sandbox     = $cfgSandbox"

# ------------------------------------------------------------------
# 3. Locate the chosen prompt
# ------------------------------------------------------------------
$promptPath = Join-Path $HarnessRoot "prompts\$Prompt"
if (-not (Test-Path $promptPath)) {
    Write-Err "Prompt file not found: $promptPath"
    Write-Host "    Available prompts:"
    Get-ChildItem (Join-Path $HarnessRoot "prompts") -Filter *.md | ForEach-Object { Write-Host "      - $($_.Name)" }
    exit 1
}
Write-Ok "Using prompt: $Prompt"

# ------------------------------------------------------------------
# 4. Prepare reports directory
# ------------------------------------------------------------------
$reportsDir = Join-Path $HarnessRoot $cfgOutDir
if (-not (Test-Path $reportsDir)) {
    New-Item -ItemType Directory -Path $reportsDir | Out-Null
}
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportFile = Join-Path $reportsDir "review-$timestamp.md"
Write-Ok "Report will be written to: $reportFile"

# ------------------------------------------------------------------
# 5. Build the Codex command
# ------------------------------------------------------------------
$promptContent = Get-Content $promptPath -Raw

# Compose a single instruction that forces read-only + loads config intent
$fullPrompt = @"
You are running inside the Codex Repo Review Harness.
Sandbox mode is forced to read-only. You must not modify any files.

Base branch to compare against: $BaseBranch

Follow the instructions in the prompt below exactly, including the required Markdown report structure.

----- BEGIN PROMPT -----
$promptContent
----- END PROMPT -----

Also respect every rule under "## Code Review Rules" in AGENTS.md (if present).
"@

# Codex CLI invocation.
# We use `codex exec` for non-interactive runs when available.
# Fallback to interactive `codex` if exec is missing.
$codexArgs = @(
    "exec",
    "--sandbox", "read-only",
    $fullPrompt
)

Write-Step "Prepared command"
Write-Host "    codex $($codexArgs[0]) --sandbox read-only <long prompt>"

if ($DryRun) {
    Write-Step "Dry-run mode – stopping before launching Codex"
    Write-Host "    The full prompt length is $($fullPrompt.Length) characters."
    Write-Host "    Report path would be: $reportFile"
    exit 0
}

# ------------------------------------------------------------------
# 6. Run Codex and capture output
# ------------------------------------------------------------------
Write-Step "Launching Codex (this may take a few minutes)..."
Write-Host "    Please wait. Codex will print progress in this window."

try {
    # Capture both stdout and stderr
    $output = & codex @codexArgs 2>&1 | Out-String
} catch {
    Write-Err "Codex failed: $_"
    exit 1
}

# ------------------------------------------------------------------
# 7. Write the report
# ------------------------------------------------------------------
$header = @"
# Codex Repo Review Report
Generated by the Codex Repo Review Harness
**Timestamp:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Base branch:** $BaseBranch
**Sandbox:** read-only
**Prompt:** $Prompt
**Repository:** $gitTop

---

"@

$fullReport = $header + $output
Set-Content -Path $reportFile -Value $fullReport -Encoding UTF8

Write-Step "Review finished"
Write-Ok "Report saved to: $reportFile"
Write-Host ""
Write-Host "Open the file with any text editor or Markdown viewer."
Write-Host "You can also run:  notepad `"$reportFile`""
Write-Host ""
Write-Host "To run another review type:" -ForegroundColor Cyan
Write-Host "  .\scripts\Run-Review.ps1 -Prompt security-focus.md"
Write-Host "  .\scripts\Run-Review.ps1 -Prompt pr-diff-review.md"
