#Requires -Version 5.1
<#
.SYNOPSIS
  Bounded, read-only Codex repository review runner.

.DESCRIPTION
  Exit codes: 0 success, 2 usage/configuration, 3 prerequisite, 4 Codex
  failure, 5 contract failure, 6 timeout, 7 output-size limit.
#>
param(
    [string]$Prompt = 'system-review.md',
    [string]$BaseBranch = '',
    [int]$TimeoutSeconds = 900,
    [int]$MaxOutputBytes = 5242880,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$HarnessRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $HarnessRoot
. (Join-Path $HarnessRoot 'scripts\ci\Review-Helpers.ps1')

function Fail([int]$Code, [string]$Message) { [Console]::Error.WriteLine($Message); exit $Code }
if ($TimeoutSeconds -lt 1 -or $MaxOutputBytes -lt 1024) { Fail 2 'TimeoutSeconds must be positive and MaxOutputBytes must be at least 1024.' }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail 3 'Git is not installed or not on PATH.' }
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) { Fail 3 'Codex CLI is not installed or not on PATH.' }
$gitTop = git rev-parse --show-toplevel 2>$null
if (-not $gitTop) { Fail 3 'This folder is not inside a Git repository.' }

$configPath = Join-Path $HarnessRoot 'config\review-config.yaml'
if (-not (Test-Path -LiteralPath $configPath)) { Fail 2 "Missing config file: $configPath" }
$config = try { Get-ReviewConfig $configPath } catch { Fail 2 $_.Exception.Message }
$cfgBase = $config.base_branch
$cfgSandbox = $config.sandbox
$cfgOutDir = $config.report.output_dir
if ($BaseBranch -eq '') { $BaseBranch = $cfgBase }
if ($cfgSandbox -ne 'read-only') { Write-Warning "Config sandbox is '$cfgSandbox'; forcing read-only." }
if ([IO.Path]::IsPathRooted($cfgOutDir) -or $cfgOutDir.Contains('..')) { Fail 2 'report.output_dir must be a repository-relative path.' }
if ($config.min_severity -notin @('critical','high','medium','low','info')) { Fail 2 "Unsupported min_severity: $($config.min_severity)" }
if ($config.report.max_findings -lt 0) { Fail 2 'report.max_findings cannot be negative.' }

$promptPath = Join-Path $HarnessRoot (Join-Path 'prompts' $Prompt)
if (-not (Test-Path -LiteralPath $promptPath)) { Fail 2 "Prompt file not found: $Prompt" }
$reportsDir = Join-Path $HarnessRoot $cfgOutDir
New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null
$reviewInputDir = Join-Path $HarnessRoot 'review-input'
New-Item -ItemType Directory -Path $reviewInputDir -Force | Out-Null
$reviewManifest = @(Get-ReviewFileManifest $HarnessRoot $config)
if ($reviewManifest.Count -eq 0) { Fail 2 'Configured review scope contains no files.' }
Write-ReviewManifest (Join-Path $reviewInputDir 'review-manifest.txt') $reviewManifest
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss-fff')
$runId = [guid]::NewGuid().ToString('N').Substring(0, 8)
$reportFile = Join-Path $reportsDir "review-$timestamp-$runId.md"
$jsonFile = [IO.Path]::ChangeExtension($reportFile, '.json')
$hashFile = [IO.Path]::ChangeExtension($reportFile, '.sha256')

$promptContent = Get-Content -LiteralPath $promptPath -Raw
$fullPrompt = @"
You are running inside the Codex Repo Review Harness. Sandbox mode is forced to read-only.
Do not modify files, access external systems, or claim unverified runtime behavior.
Base branch: $BaseBranch
Minimum severity: $($config.min_severity)
Focus areas: $($config.focus_areas -join ', ')
Included paths: $($config.include_paths -join ', ')
Excluded paths: $($config.exclude_paths -join ', ')
Maximum findings: $($config.report.max_findings)
Review manifest: review-input/review-manifest.txt
Review only files listed in the manifest. Treat files outside the manifest as excluded from this review.
$($config.extra_instructions)
Follow this trusted prompt exactly:
----- BEGIN PROMPT -----
$promptContent
----- END PROMPT -----
"@
$codexArgs = @('exec', '--sandbox', 'read-only', $fullPrompt)
if ($config.model) { $codexArgs = @('exec', '--sandbox', 'read-only', '--model', $config.model, $fullPrompt) }
if ($DryRun) {
    Write-Host "Prepared bounded read-only review; prompt length=$($fullPrompt.Length), timeout=$TimeoutSeconds seconds, max_output_bytes=$MaxOutputBytes."
    exit 0
}

$job = Start-Job -ScriptBlock {
    param($Args)
    $jobOutput = (& codex @Args 2>&1 | Out-String)
    [pscustomobject]@{ Output = $jobOutput; ExitCode = $LASTEXITCODE }
} -ArgumentList (,$codexArgs)
try {
    if (-not (Wait-Job -Job $job -Timeout $TimeoutSeconds)) {
        Stop-Job -Job $job -ErrorAction SilentlyContinue
        Fail 6 "Codex review timed out after $TimeoutSeconds seconds."
    }
    $result = Receive-Job -Job $job
} finally { Remove-Job -Job $job -Force -ErrorAction SilentlyContinue }
$exitCode = [int]$result.ExitCode
$output = ConvertTo-RedactedText ([string]$result.Output)
if ($exitCode -ne 0) { Fail 4 "Codex review failed with exit code $exitCode. Output: $output" }
if ([Text.Encoding]::UTF8.GetByteCount($output) -gt $MaxOutputBytes) { Fail 7 "Codex output exceeded $MaxOutputBytes bytes." }
try { Assert-ReviewMarkdown $output } catch { Fail 5 $_.Exception.Message }
$findings = @(Get-ReviewFindings $output)
try { Assert-ReviewFindings $output $findings } catch { Fail 5 $_.Exception.Message }
$findings = @(Select-ReviewFindings $findings $config.min_severity)
$output = Filter-ReviewMarkdown $output $findings
Assert-ReviewReportConsistency $output $findings
if ($config.report.max_findings -gt 0 -and $findings.Count -gt $config.report.max_findings) { Fail 5 "Review contains $($findings.Count) findings; configured maximum is $($config.report.max_findings)." }

$header = "# Codex Repository Review Report`nGenerated by the Codex Repo Review Harness`n**Timestamp:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n**Base branch:** $BaseBranch`n**Sandbox:** read-only`n**Prompt:** $Prompt`n**Repository:** $gitTop`n`n---`n`n"
$fullReport = $header + $output
if (Test-ReviewSecrets $fullReport) { Fail 5 'Potential secret detected in the generated review artifact.' }
Write-ReviewUtf8 $reportFile $fullReport
$commit = 'unknown'
$previousErrorAction = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    $candidateCommit = (git rev-parse HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $candidateCommit) { $commit = $candidateCommit }
} finally { $ErrorActionPreference = $previousErrorAction }
$report = [ordered]@{
    schema_version = '1.0'; status = (Get-ReviewStatus $findings); summary = $output.Substring(0, [Math]::Min($output.Length, 20000)); findings = $findings
    metadata = [ordered]@{ repository = $gitTop.Trim(); commit = $commit.Trim(); generated_at = (Get-Date).ToUniversalTime().ToString('o'); failure_class = 'none'; failure_detail = '' }
}
Write-ReviewUtf8 $jsonFile ($report | ConvertTo-Json -Depth 8)
$hashLines = Get-FileHash -Algorithm SHA256 $reportFile, $jsonFile | ForEach-Object { '{0}  {1}' -f $_.Hash.ToLowerInvariant(), $_.Path.Substring($reportsDir.Length + 1) }
Write-ReviewUtf8 $hashFile (($hashLines -join "`n") + "`n")
Write-Host "Review finished. Markdown: $reportFile; JSON: $jsonFile; SHA-256: $hashFile"
exit 0
