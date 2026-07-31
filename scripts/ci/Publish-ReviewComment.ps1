#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$marker = '<!-- codex-review-harness -->'
$env:REVIEW_OUTPUT_DIR = Join-Path (Get-Location) 'review-output'
& (Join-Path $PSScriptRoot 'Verify-ReviewArtifacts.ps1')
$report = Get-Content (Join-Path (Get-Location) 'review-output\review.md') -Raw
$body = "$marker`n## Codex review ($env:WORKFLOW_CONCLUSION)`n`n$report"
$comments = gh api "repos/$env:REPOSITORY/issues/$env:PR_NUMBER/comments?per_page=100" | ConvertFrom-Json
$existing = $comments | Where-Object { $_.body -like "$marker*" } | Select-Object -First 1
$payload = @{ body = $body } | ConvertTo-Json -Compress
if ($existing) { $payload | gh api "repos/$env:REPOSITORY/issues/comments/$($existing.id)" --method PATCH --input - | Out-Null }
else { $payload | gh api "repos/$env:REPOSITORY/issues/$env:PR_NUMBER/comments" --method POST --input - | Out-Null }
Write-Host 'Review comment published.'
