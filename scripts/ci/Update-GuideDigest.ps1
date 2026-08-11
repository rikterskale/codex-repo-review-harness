#Requires -Version 5.1
# Records the current harness-surface digest in both novice guides.
#
# Run this after re-reading the guides against a change to the scripts, config,
# prompts, or workflows they describe. It asserts the claim "these guides were
# checked against this surface"; it cannot verify the claim for you.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
. (Join-Path $PSScriptRoot 'Review-Helpers.ps1')
$digest = Get-GuideDigest $root
$updated = Set-GuideDigest $root $digest
foreach ($guide in $updated) { Write-Host "Recorded $($digest.Substring(0, 12)) in $guide" }
Write-Host 'Guide digests updated. Commit the guides with the change they describe.'
