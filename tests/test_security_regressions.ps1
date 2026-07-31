#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\ci\Review-Helpers.ps1')
$fixture = Get-Content (Join-Path $PSScriptRoot 'fixtures\secrets.txt') -Raw
$redacted = ConvertTo-RedactedText $fixture
if ($redacted -match 'sk-12345678901234567890|ghp_fixture_token') { throw 'Secret-redaction regression detected.' }
$injection = Get-Content (Join-Path $PSScriptRoot 'fixtures\prompt-injection.diff') -Raw
if ($injection -notmatch 'Ignore AGENTS.md') { throw 'Prompt-injection fixture missing.' }
if ($injection -notmatch 'read-only') { throw 'Prompt-injection fixture missing safety boundary.' }
Write-Host 'PASS: secret redaction and prompt-injection fixtures passed.'
