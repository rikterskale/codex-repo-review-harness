#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$errors = @()

function Add-Error([string]$Message) { $script:errors += $Message }

$markdownFiles = @(git -C $root ls-files '*.md')
foreach ($relative in $markdownFiles) {
    $path = Join-Path $root $relative
    $text = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($path))
    $suspicious = $false
    foreach ($character in $text.ToCharArray()) {
        if ([int][char]$character -in @(0x00C2, 0x00E2)) { $suspicious = $true; break }
    }
    if ($suspicious) { Add-Error "Possible mojibake in $relative" }
    foreach ($linkMatch in @([regex]::Matches($text, '\]\(([^)]+)\)'))) {
        $link = $linkMatch.Groups[1].Value
        if ($link -match '^(https?:|mailto:|#)') { continue }
        $target = ($link -split '#', 2)[0]
        if ([string]::IsNullOrWhiteSpace($target)) { continue }
        $resolved = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $path) $target))
        if (-not (Test-Path -LiteralPath $resolved)) { Add-Error "Broken documentation link: $relative -> $link" }
    }
}

$cli = Get-Content -LiteralPath (Join-Path $root 'docs\CLI_REFERENCE.md') -Raw
$runner = Get-Content -LiteralPath (Join-Path $root 'scripts\Run-Review.ps1') -Raw
foreach ($parameter in [regex]::Matches($runner, '(?m)^\s*\[(?:string|int)\]\$(\w+)|(?m)^\s*\[switch\]\$(\w+)')) {
    $name = if ($parameter.Groups[1].Success) { $parameter.Groups[1].Value } else { $parameter.Groups[2].Value }
    if ($cli -notmatch [regex]::Escape("-$name")) { Add-Error "CLI reference does not document -$name" }
}

foreach ($guide in @('docs\guides\WINDOWS_NOVICE_USABILITY_GUIDE.md', 'docs\guides\LINUX_NOVICE_USABILITY_GUIDE.md')) {
    $text = Get-Content -LiteralPath (Join-Path $root $guide) -Raw
    if ($text -notmatch 'DiagnosticLogPath') { Add-Error "$guide does not document DiagnosticLogPath" }
}

if ($errors.Count) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }
Write-Host 'PASS: documentation encoding, local links, CLI parameters, and diagnostic coverage are valid.'
