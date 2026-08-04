#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\ci\Review-Helpers.ps1')

# #14: fenced code blocks must not count as declared findings.
$markdown = @'
# Codex Repository Review Report

## Executive Summary
- Overall risk: Low.

## Findings

For example, a finding heading looks like this:

```
### [HIGH] Not a real finding
- **Location:** `x`
- **Why it matters:** should be ignored
- **Evidence:** in code fence
- **Suggested fix:** none
```

### [MEDIUM] Real finding
- **Location:** `foo.ps1:10`
- **Why it matters:** parsed
- **Evidence:** counted once
- **Suggested fix:** keep test

## Positive Observations
- Fenced blocks are ignored.

## Recommended Next Actions
1. Keep this test.
'@
$findings = @(Get-ReviewFindings $markdown)
if ($findings.Count -ne 1) { throw "Fenced-block finding leaked into parser (got $($findings.Count) findings, expected 1)." }
if ($findings[0].severity -ne 'medium' -or $findings[0].title -ne 'Real finding') { throw 'Wrong finding parsed from fenced-block sample.' }
Assert-ReviewFindings $markdown $findings

# #13: relaxed drift - colon outside **bold** is accepted.
$driftMarkdown = @'
# Codex Repository Review Report

## Executive Summary
- Overall risk: Low.

## Findings

### [LOW] Colon outside bold
- **Location**: `bar.ps1:1`
- **Why it matters**: drift tolerated
- **Evidence**: parsed anyway
- **Suggested fix**: keep parser lenient

## Positive Observations
- Formatting drift handled.

## Recommended Next Actions
1. Ok.
'@
$driftFindings = @(Get-ReviewFindings $driftMarkdown)
if ($driftFindings.Count -ne 1) { throw "Colon-outside-bold drift not accepted (got $($driftFindings.Count) findings)." }

# #6: extended validator - pattern and integer types are enforced.
$schemaText = @'
{
  "type": "object",
  "required": ["commit", "count"],
  "properties": {
    "commit": { "type": "string", "pattern": "^[0-9a-f]{40}$" },
    "count":  { "type": "integer", "minimum": 0, "maximum": 10 }
  },
  "additionalProperties": false
}
'@
$schemaFile = Join-Path ([IO.Path]::GetTempPath()) ('batch2-schema-' + [guid]::NewGuid().ToString('N') + '.json')
Write-ReviewUtf8 $schemaFile $schemaText
try {
  Assert-ReviewJson '{"commit":"0123456789abcdef0123456789abcdef01234567","count":3}' $schemaFile
  $rejected = $false
  try { Assert-ReviewJson '{"commit":"not-a-sha","count":3}' $schemaFile } catch { $rejected = $true }
  if (-not $rejected) { throw 'Extended validator missed a pattern mismatch.' }
  $rejected = $false
  try { Assert-ReviewJson '{"commit":"0123456789abcdef0123456789abcdef01234567","count":99}' $schemaFile } catch { $rejected = $true }
  if (-not $rejected) { throw 'Extended validator missed a maximum-bound mismatch.' }
  $rejected = $false
  try { Assert-ReviewJson '{"commit":"0123456789abcdef0123456789abcdef01234567","count":3,"stray":true}' $schemaFile } catch { $rejected = $true }
  if (-not $rejected) { throw 'Extended validator missed additionalProperties: false.' }
} finally {
  Remove-Item -LiteralPath $schemaFile -ErrorAction SilentlyContinue
}

Write-Host 'PASS: batch-2 regressions (fenced-blocks, drift, schema features) hold.'
