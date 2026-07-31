#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\ci\Review-Helpers.ps1')

$config = Get-ReviewConfig (Join-Path $PSScriptRoot '..\config\review-config.yaml')
if ($config.base_branch -ne 'main' -or $config.sandbox -ne 'read-only' -or $config.report.max_findings -ne 50) { throw 'Configuration parser regression.' }
if ($config.focus_areas.Count -lt 5 -or $config.exclude_paths.Count -lt 1) { throw 'Configuration list parsing regression.' }

$markdown = @'
# Codex Repository Review Report

## Executive Summary
- Overall risk assessment: Medium.

## Findings

### [HIGH] Synthetic issue
- **Location:** `fixture.ps1:10`
- **Why it matters:** It demonstrates structured parsing.
- **Evidence:** The fixture contains a deterministic finding.
- **Suggested fix:** Keep the contract test.
- **Rule (if any):** Testing

## Positive Observations
- The report is structured.

## Recommended Next Actions
1. Keep the test.
'@
Assert-ReviewMarkdown $markdown
if ($markdown -notmatch '(?m)^###\s+\[HIGH\]\s+(.+)$') { throw 'Fixture heading regex failed.' }
foreach ($field in @('Location','Why it matters','Evidence','Suggested fix')) { if ($markdown -notmatch "(?m)^-\s+\*\*${field}:\*\*\s+(.+)$") { throw "Fixture field regex failed: $field" } }
$findings = @(Get-ReviewFindings $markdown)
if ($findings.Count -ne 1 -or $findings[0].severity -ne 'high' -or $findings[0].title -ne 'Synthetic issue') { throw 'Markdown finding parser regression.' }
if (@(Select-ReviewFindings $findings 'medium').Count -ne 1) { throw 'Minimum severity filtering regression.' }
$redacted = ConvertTo-RedactedText "ghp_12345678901234567890`n-----BEGIN PRIVATE KEY-----`nsecret`n-----END PRIVATE KEY-----"
if ($redacted -match 'ghp_12345678901234567890|BEGIN PRIVATE KEY|secret') { throw 'Secret redaction regression.' }
$credentialReview = ConvertTo-RedactedText 'A finding quotes PASSWORD=hunter2 for remediation.'
if (Test-ReviewSecrets $credentialReview) { throw 'Redacted credential findings must remain publishable.' }
$schemaPath = Join-Path $PSScriptRoot '..\schemas\review-report.schema.json'
Assert-ReviewJson (@{ schema_version='1.0'; status='passed'; summary='ok'; findings=@(); metadata=@{ repository='fixture'; commit='fixture'; generated_at=(Get-Date).ToUniversalTime().ToString('o'); failure_class='none' } } | ConvertTo-Json -Depth 8) $schemaPath
Write-Host 'PASS: review helper contract tests passed.'
