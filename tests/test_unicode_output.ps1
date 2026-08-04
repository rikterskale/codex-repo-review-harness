#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\ci\Review-Helpers.ps1')
$emoji = [char]::ConvertFromUtf32(0x1F642)
$unicodeSample = ($emoji * 10000) + ('X' * 10000)
$codexOutput = "# Codex Repository Review Report`n`n## Executive Summary`n- Overall risk: Medium.`n`n## Findings`n`n## Positive Observations`n- Unicode sample.`n`n## Recommended Next Actions`n1. Verify.`n" + $unicodeSample
$limited = Limit-ReviewUtf8 $codexOutput 200KB "`n`n[Output truncated by contract.]"
$encoding = New-Object System.Text.UTF8Encoding($false, $true)
if ($encoding.GetByteCount($limited) -gt 200KB) { throw 'Unicode-heavy Codex output exceeded the byte limit.' }
try { [void]$encoding.GetBytes($limited) } catch { throw 'Unicode-heavy Codex output was truncated into invalid UTF-8.' }
Write-Host 'PASS: Unicode-heavy Codex output remains valid and bounded.'
