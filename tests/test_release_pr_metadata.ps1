#Requires -Version 5.1
<#
  Regression test for the reviewed_head freshness check on pull_request events.

  On a pull_request, GitHub checks out refs/pull/N/merge: a synthetic merge whose
  first parent is the base branch tip and whose second parent is the pull request
  head. HEAD is therefore a commit no author wrote, and HEAD~1 is the base
  branch, so a guide's reviewed_head can never match either and the check fails
  on every pull request.

  This test builds that exact topology in a throwaway repository and asserts that
  Validate-Release.ps1 accepts it when GITHUB_EVENT_NAME is pull_request, both
  from PR_HEAD_SHA and from the merge topology alone, and still rejects a guide
  that names an unrelated commit.
#>
$ErrorActionPreference = 'Stop'
$psExe = (Get-Process -Id $PID).Path
$root = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([IO.Path]::GetTempPath()) ('codex-harness-pr-' + [guid]::NewGuid().ToString('N'))

function Invoke-Git {
    param([string[]]$Arguments)
    # Windows PowerShell 5.1 raises NativeCommandError for anything a native
    # command writes to stderr while $ErrorActionPreference is 'Stop', and the
    # redirection below does not prevent it, so the preference is relaxed for the
    # duration of the call. stderr is discarded rather than merged because
    # merging would corrupt the stdout of commands like rev-parse.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = & git -C $temp @Arguments 2>$null }
    finally { $ErrorActionPreference = $previousPreference }
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed with exit code $LASTEXITCODE." }
    return ((@($output) | ForEach-Object { [string]$_ }) -join "`n").Trim()
}

function Set-ReviewedHead {
    param([string]$Sha)
    foreach ($guide in @('WINDOWS_NOVICE_USABILITY_GUIDE.md', 'LINUX_NOVICE_USABILITY_GUIDE.md')) {
        $path = Join-Path $temp "docs\guides\$guide"
        $bytes = [IO.File]::ReadAllBytes($path)
        $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $text = [Text.Encoding]::UTF8.GetString($bytes)
        if ($hasBom) { $text = $text.Substring(1) }
        $updated = [regex]::Replace($text, '(?m)^(reviewed_head:\s*")[0-9a-fA-F]{40}(")', ('${1}' + $Sha + '${2}'))
        if ($updated -eq $text) { throw "Could not rewrite reviewed_head in $guide." }
        $out = New-Object 'System.Collections.Generic.List[byte]'
        if ($hasBom) { $out.AddRange([byte[]]@(0xEF, 0xBB, 0xBF)) }
        $out.AddRange((New-Object Text.UTF8Encoding($false)).GetBytes($updated))
        [IO.File]::WriteAllBytes($path, $out.ToArray())
    }
}

function Invoke-ValidateRelease {
    param([string]$EventName, [string]$PrHeadSha)
    $previousEvent = $env:GITHUB_EVENT_NAME
    $previousSha = $env:PR_HEAD_SHA
    $previousPreference = $ErrorActionPreference
    $env:GITHUB_EVENT_NAME = $EventName
    $env:PR_HEAD_SHA = $PrHeadSha
    # This helper is deliberately called for runs that are expected to fail, and
    # a failing child writes to stderr, which Windows PowerShell 5.1 would raise
    # as a terminating error before the exit code could be returned.
    $ErrorActionPreference = 'Continue'
    try {
        $null = & $psExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $temp 'scripts\ci\Validate-Release.ps1') 2>$null
        return $LASTEXITCODE
    } finally {
        $env:GITHUB_EVENT_NAME = $previousEvent
        $env:PR_HEAD_SHA = $previousSha
        $ErrorActionPreference = $previousPreference
    }
}

New-Item -ItemType Directory -Path $temp -Force | Out-Null
try {
    Get-ChildItem $root -Force |
        Where-Object { $_.Name -notin @('.git', 'reports', 'review-input', 'review-output', 'logs') } |
        Copy-Item -Destination $temp -Recurse -Force

    Invoke-Git @('init', '--quiet', '--initial-branch=main') | Out-Null
    Invoke-Git @('config', 'user.email', 'harness@example.invalid') | Out-Null
    Invoke-Git @('config', 'user.name', 'Harness Test') | Out-Null
    Invoke-Git @('config', 'commit.gpgsign', 'false') | Out-Null
    # Keep the fixture's bytes exactly as copied, so rewriting reviewed_head is
    # the only difference between commits.
    Invoke-Git @('config', 'core.autocrlf', 'false') | Out-Null
    Invoke-Git @('add', '-A') | Out-Null
    Invoke-Git @('commit', '--quiet', '-m', 'base') | Out-Null
    $baseSha = Invoke-Git @('rev-parse', 'HEAD')

    # Pull request branch: a content commit, then the metadata commit that
    # records it. This is the two-commit pattern the check exists to allow.
    Invoke-Git @('checkout', '--quiet', '-b', 'feature') | Out-Null
    Add-Content -LiteralPath (Join-Path $temp 'CHANGELOG.md') -Value ''
    Invoke-Git @('commit', '--quiet', '-am', 'content change') | Out-Null
    $contentSha = Invoke-Git @('rev-parse', 'HEAD')
    Set-ReviewedHead $contentSha
    Invoke-Git @('commit', '--quiet', '-am', 'metadata update') | Out-Null
    $prHeadSha = Invoke-Git @('rev-parse', 'HEAD')

    # GitHub's merge ref: base with the pull request merged in, so parent 1 is
    # the base tip and parent 2 is the pull request head.
    Invoke-Git @('checkout', '--quiet', 'main') | Out-Null
    Invoke-Git @('merge', '--quiet', '--no-ff', '-m', 'merge pull request', 'feature') | Out-Null
    $mergeSha = Invoke-Git @('rev-parse', 'HEAD')

    if ((Invoke-Git @('rev-parse', 'HEAD^1')) -ne $baseSha) { throw 'Fixture parent 1 is not the base tip.' }
    if ((Invoke-Git @('rev-parse', 'HEAD^2')) -ne $prHeadSha) { throw 'Fixture parent 2 is not the pull request head.' }
    if ($mergeSha -eq $prHeadSha) { throw 'Fixture did not produce a merge commit.' }

    # Without the pull_request handling this topology is exactly what failed:
    # HEAD is the merge and HEAD~1 is the base, so neither carries reviewed_head.
    if ((Invoke-ValidateRelease -EventName 'push' -PrHeadSha '') -eq 0) {
        throw 'Merge-commit checkout was accepted as a push; the regression no longer reproduces.'
    }

    # Explicit pull request head, supplied the way the workflow supplies it.
    if ((Invoke-ValidateRelease -EventName 'pull_request' -PrHeadSha $prHeadSha) -ne 0) {
        throw 'Validate-Release rejected a valid pull request head supplied via PR_HEAD_SHA.'
    }

    # Same result derived from the merge topology when the variable is absent.
    if ((Invoke-ValidateRelease -EventName 'pull_request' -PrHeadSha '') -ne 0) {
        throw 'Validate-Release rejected a valid pull request head derived from HEAD^2.'
    }

    # A guide naming an unrelated commit must still be rejected, or the check
    # would pass for any tree and stop being a freshness gate at all.
    Set-ReviewedHead ('0' * 40)
    if ((Invoke-ValidateRelease -EventName 'pull_request' -PrHeadSha $prHeadSha) -eq 0) {
        throw 'Validate-Release accepted a guide naming an unrelated commit.'
    }

    Write-Host 'PASS: release metadata check resolves the pull request head.'
} finally {
    if (Test-Path -LiteralPath $temp) {
        # Git marks object files read-only, which blocks a plain recursive delete.
        Get-ChildItem -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Attributes = 'Normal' }
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
