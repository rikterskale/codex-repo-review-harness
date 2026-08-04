#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Review-Helpers.ps1')
$schemaPath = Join-Path $PSScriptRoot '..\..\schemas\review-report.schema.json'
$markdown = Get-Content (Join-Path $PSScriptRoot '..\..\templates\report-skeleton.md') -Raw
foreach ($heading in @('## Executive Summary', '## Findings', '## Positive Observations', '## Recommended Next Actions')) {
  if ($markdown -notmatch [regex]::Escape($heading)) { throw "Markdown report contract is missing: $heading" }
}
$config = Get-Content (Join-Path $PSScriptRoot '..\..\config\review-config.yaml') -Raw
if ($config -notmatch '(?ms)^report:\s*.*?^\s+output_dir:\s*reports\s*$') { throw 'Nested report.output_dir configuration is missing.' }
$fixture = [ordered]@{
  schema_version = '1.0'; status = 'findings'; summary = 'Synthetic review'; findings = @([ordered]@{ severity='medium'; title='Synthetic'; location='fixture'; evidence='fixture'; suggested_fix='fixture' }); metadata = [ordered]@{ repository='fixture'; commit='fixture'; generated_at=(Get-Date).ToUniversalTime().ToString('o'); failure_class='none' }
}
$json = $fixture | ConvertTo-Json -Depth 8 | ConvertFrom-Json
Assert-ReviewJson ($fixture | ConvertTo-Json -Depth 8) $schemaPath
Write-Host 'PASS: report contract fixture is valid.'
