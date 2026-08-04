#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$marker = '<!-- codex-review-harness -->'
$reviewOutputDir = Join-Path (Get-Location) 'review-output'
$env:REVIEW_OUTPUT_DIR = $reviewOutputDir

if ($env:WORKFLOW_CONCLUSION -eq 'success') {
    & (Join-Path $PSScriptRoot 'Verify-ReviewArtifacts.ps1')
    $report = Get-Content (Join-Path $reviewOutputDir 'review.md') -Raw
    $body = "$marker`n## Codex review (success)`n`n$report"
} else {
    $body = @"
$marker
## Codex review ($($env:WORKFLOW_CONCLUSION))

The analysis workflow did not complete successfully. See the workflow run for details.
The artifact from this run was **not** published because the run did not conclude with success.
"@
}

$commentsJson = gh api --paginate "repos/$env:REPOSITORY/issues/$env:PR_NUMBER/comments"
$comments = @()
if ($commentsJson) {
    # `gh --paginate` concatenates JSON arrays; parse each page separately.
    foreach ($chunk in [regex]::Split($commentsJson, '(?<=\])\s*(?=\[)')) {
        if ($chunk.Trim()) { $comments += @($chunk | ConvertFrom-Json) }
    }
}
$existing = $comments | Where-Object { $_.body -like "$marker*" } | Select-Object -First 1
$payload = @{ body = $body } | ConvertTo-Json -Compress
if ($existing) { $payload | gh api "repos/$env:REPOSITORY/issues/comments/$($existing.id)" --method PATCH --input - | Out-Null }
else { $payload | gh api "repos/$env:REPOSITORY/issues/$env:PR_NUMBER/comments" --method POST --input - | Out-Null }
Write-Host 'Review comment published.'
