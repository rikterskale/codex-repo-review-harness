#Requires -Version 5.1
# Regressions for the two ways the analysis workflow silently failed:
# a sandbox override that the action outranked, and a missing credential that
# surfaced as an unrelated crash inside the action.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$analysis = Get-Content (Join-Path $root '.github\workflows\codex-review.yml') -Raw

# codex-action appends its own --sandbox argument after the codex-args
# pass-through, defaulting to workspace-write, so a sandbox selected through
# codex-args is silently outranked and the review runs write-enabled.
if ($analysis -notmatch '(?m)^\s*sandbox:\s*read-only\s*$') { throw 'Analysis workflow no longer pins the sandbox through the action input.' }
if ($analysis -match '(?m)^\s*codex-args:.*(--sandbox|(?<![\w-])-s(?![\w-])|sandbox_mode)') { throw 'Analysis workflow selects a sandbox through codex-args, which the action overrides with its own default.' }

# The preflight must run before Codex and must receive only whether the secret
# is set, never its value.
$credentialCheck = [regex]::Match($analysis, '(?m)^\s*REVIEW_CREDENTIAL_PRESENT:\s*\$\{\{\s*secrets\.OPENAI_API_KEY\s*!=\s*''''\s*\}\}\s*$')
if (-not $credentialCheck.Success) { throw 'Analysis workflow no longer verifies the review credential by presence alone.' }
$codexAction = [regex]::Match($analysis, '(?m)^\s*uses:\s*openai/codex-action@')
if ($codexAction.Success -and $credentialCheck.Index -gt $codexAction.Index) { throw 'Credential preflight no longer runs before Codex is invoked.' }
if ($analysis -notmatch '::error::[^\r\n]*OPENAI_API_KEY') { throw 'Credential preflight failure does not name the missing secret as a workflow error.' }
if ($analysis -notmatch 'gh secret set OPENAI_API_KEY') { throw 'Credential preflight failure does not tell the reader how to fix it.' }

Write-Host 'PASS: sandbox pinning and credential preflight hold.'
