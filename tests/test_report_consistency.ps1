#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\ci\Review-Helpers.ps1')
$markdown = @'
# Codex Repository Review Report

## Executive Summary
- Overall risk assessment: Medium.

## Findings

### [HIGH] Keep high finding
- **Location:** `fixture.ps1:1`
- **Why it matters:** High finding.
- **Evidence:** High evidence.
- **Suggested fix:** Fix high finding.

### [LOW] Remove low finding
- **Location:** `fixture.ps1:2`
- **Why it matters:** Low finding.
- **Evidence:** Low evidence.
- **Suggested fix:** Fix low finding.

## Positive Observations
- Filtered report.

## Recommended Next Actions
1. Verify consistency.
'@
$all = @(Get-ReviewFindings $markdown)
$filteredFindings = @(Select-ReviewFindings $all 'medium')
$filteredMarkdown = Filter-ReviewMarkdown $markdown $filteredFindings
Assert-ReviewReportConsistency $filteredMarkdown $filteredFindings
if ($filteredMarkdown -match 'Remove low finding') { throw 'Filtered Markdown retained a low-severity finding.' }
$jsonFindings = @($filteredFindings)
Assert-ReviewReportConsistency $filteredMarkdown $jsonFindings
Write-Host 'PASS: Markdown and JSON contain the same filtered findings.'
