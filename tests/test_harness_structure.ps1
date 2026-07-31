# Simple structural tests that can run without Codex being fully authenticated.
# Run with:  powershell -File tests/test_harness_structure.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

$errors = @()

function Assert-True($cond, $msg) {
    if (-not $cond) { $script:errors += $msg }
}

Assert-True (Test-Path "$root\config\review-config.yaml") "Missing config/review-config.yaml"
Assert-True (Test-Path "$root\prompts\system-review.md") "Missing prompts/system-review.md"
Assert-True (Test-Path "$root\AGENTS.md") "Missing AGENTS.md"
Assert-True (Test-Path "$root\scripts\Run-Review.ps1") "Missing scripts/Run-Review.ps1"
Assert-True (Test-Path "$root\scripts\Validate-Harness.ps1") "Missing scripts/Validate-Harness.ps1"

$config = Get-Content "$root\config\review-config.yaml" -Raw
Assert-True ($config -match "sandbox:\s*read-only") "Config must default to sandbox: read-only"
Assert-True ($config -match "base_branch:") "Config must declare base_branch"

$agents = Get-Content "$root\AGENTS.md" -Raw
Assert-True ($agents -match "## Code Review Rules") "AGENTS.md must contain Code Review Rules section"

if ($errors.Count -eq 0) {
    Write-Host "PASS: All structural tests succeeded." -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAIL:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
