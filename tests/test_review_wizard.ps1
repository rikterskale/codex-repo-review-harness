#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$psExe = (Get-Process -Id $PID).Path
$wizardPath = Join-Path $root 'scripts\Start-ReviewWizard.ps1'
if (-not (Test-Path -LiteralPath $wizardPath)) { throw 'Interactive review wizard is missing.' }
$tokens = $errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($wizardPath, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count) { throw "Interactive review wizard has PowerShell syntax errors: $($errors[0].Message)" }
$wizard = Get-Content -LiteralPath $wizardPath -Raw
foreach ($required in @('Run-Review.ps1', 'Read-Host', 'Type REVIEW', '-DryRun', '-DiagnosticLogPath', 'exit $exitCode')) {
    if ($wizard -notmatch [regex]::Escape($required)) { throw "Interactive review wizard is missing required behavior: $required" }
}
if ($wizard -match 'Set-Content|Add-Content|Remove-Item|Copy-Item|Move-Item') { throw 'Interactive review wizard must delegate review work to the runner instead of modifying files itself.' }

function Invoke-Wizard([string]$WorkingRoot, [string[]]$Answers) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $WorkingRoot 'scripts\Start-ReviewWizard.ps1') + '"'
    $psi.WorkingDirectory = $WorkingRoot
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $psi
    [void]$process.Start()
    foreach ($answer in $Answers) { $process.StandardInput.WriteLine($answer) }
    $process.StandardInput.Close()
    $output = $process.StandardOutput.ReadToEnd() + $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $output }
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-wizard-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    Get-ChildItem $root -Force | Where-Object { $_.Name -notin @('.git', '.claude', 'reports', 'review-input', 'review-output') } |
        Copy-Item -Destination $temp -Recurse -Force
    git -C $temp init --quiet

    # Default prompt, harness target, dry-run mode, default branch/limits, no log,
    # then cancel. This proves cancellation occurs before invoking the runner.
    $cancelled = Invoke-Wizard $temp @('', '', '', '', '', '', '2', 'CANCEL')
    if ($cancelled.ExitCode -ne 0 -or $cancelled.Output -notmatch 'Cancelled\. No review was started\.') { throw "Wizard cancellation path did not complete safely (exit $($cancelled.ExitCode)): $($cancelled.Output)" }
    if (Test-Path (Join-Path $temp 'review-input')) { throw 'Wizard cancellation invoked the runner.' }

    # The same default choices, with diagnostics enabled and an empty confirmation,
    # executes a dry run. It requires Git but never invokes the external codex command.
    $dryRun = Invoke-Wizard $temp @('', '', '', '', '', '', '', '', '')
    if ($dryRun.ExitCode -ne 0 -or $dryRun.Output -notmatch 'Prepared bounded read-only review') { throw 'Wizard dry-run path did not prepare the runner successfully.' }
    if (-not (Test-Path (Join-Path $temp 'review-input\review-manifest.txt'))) { throw 'Wizard dry run did not create the runner manifest.' }
    Write-Host 'PASS: interactive review wizard cancellation and dry-run paths are exercised without Codex.'
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
