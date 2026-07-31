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
Assert-True (Test-Path "$root\schemas\review-report.schema.json") "Missing report schema"
Assert-True (Test-Path "$root\VERSION") "Missing VERSION"
Assert-True (Test-Path "$root\CHANGELOG.md") "Missing CHANGELOG.md"
Assert-True (Test-Path "$root\SECURITY.md") "Missing SECURITY.md"
Assert-True (Test-Path "$root\.github\CODEOWNERS") "Missing CODEOWNERS"
Assert-True (Test-Path "$root\tests\test_clean_room.ps1") "Missing clean-room test"
Assert-True (Test-Path "$root\tests\test_security_regressions.ps1") "Missing security regression test"
Assert-True (Test-Path "$root\tests\test_review_artifacts.ps1") "Missing artifact verification test"
Assert-True (Test-Path "$root\tests\test_review_helpers.ps1") "Missing review helper contract test"
Assert-True (Test-Path "$root\tests\test_runner_failure.ps1") "Missing runner failure test"

$config = Get-Content "$root\config\review-config.yaml" -Raw
Assert-True ($config -match "sandbox:\s*read-only") "Config must default to sandbox: read-only"
Assert-True ($config -match "base_branch:") "Config must declare base_branch"

$agents = Get-Content "$root\AGENTS.md" -Raw
Assert-True ($agents -match "## Code Review Rules") "AGENTS.md must contain Code Review Rules section"

foreach ($workflow in Get-ChildItem "$root\.github\workflows" -Filter '*.yml') {
    $workflowText = Get-Content $workflow.FullName -Raw
    Assert-True ($workflowText -notmatch 'curl\s+.*\|\s*(sh|bash)') "Workflow uses remote shell execution: $($workflow.Name)"
}
$validator = Get-Content "$root\scripts\Validate-Harness.ps1" -Raw
Assert-True ($validator -notmatch '(?m)^\s*[^#\r\n]*(Set-Content|New-Item|Remove-Item)') "Validator must remain read-only"

if ($errors.Count -eq 0) {
    Write-Host "PASS: All structural tests succeeded." -ForegroundColor Green
    exit 0
} else {
    Write-Host "FAIL:" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
