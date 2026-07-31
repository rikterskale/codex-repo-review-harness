#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$schemaPath = Join-Path $PSScriptRoot '..\..\schemas\review-report.schema.json'
$schema = Get-Content $schemaPath -Raw | ConvertFrom-Json
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
foreach ($required in @('schema_version','status','summary','findings','metadata')) { if ($null -eq $json.$required) { throw "Missing required report field: $required" } }
if ($json.schema_version -ne '1.0') { throw 'Unsupported report schema version.' }
$fixtureJson = $fixture | ConvertTo-Json -Depth 8
if (Get-Command Test-Json -ErrorAction SilentlyContinue) {
  if (-not (Test-Json -Json $fixtureJson -SchemaFile $schemaPath)) { throw 'Report fixture does not conform to the JSON schema.' }
}
Write-Host 'PASS: report contract fixture is valid.'
