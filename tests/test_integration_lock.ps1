#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$lock = Get-Content -LiteralPath (Join-Path $root 'config\integrations.lock.json') -Raw | ConvertFrom-Json
if ($lock.superpowers.tag -ne 'v6.3.0' -or $lock.agency_agents.commit -ne 'ebe9c99acb5c96f9468de368d8bead775387d1a7') { throw 'Upstream integration pins changed unexpectedly.' }
if ($lock.superpowers.automatic_updates_allowed -or $lock.agency_agents.automatic_updates_allowed -or -not $lock.agent_pack.checksums_required -or $lock.review_harness.sandbox -ne 'read-only') { throw 'Integration lock weakens governance.' }
Write-Host 'PASS: integration lock pins and safety controls are intact.'
