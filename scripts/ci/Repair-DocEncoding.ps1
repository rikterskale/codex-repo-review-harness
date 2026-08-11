#Requires -Version 5.1
<#
.SYNOPSIS
  Repairs double-encoded ("mojibake") UTF-8 text in files.

.DESCRIPTION
  Some documents in this repository were written as UTF-8, then misread as
  Windows-1252, then re-encoded as UTF-8. The corruption is baked into the file
  bytes, not a display artifact. An em dash (U+2014) originally stored as the
  UTF-8 bytes E2 80 94 becomes the three characters U+00E2 U+20AC U+201D, which
  re-encode to the six bytes C3 A2 E2 82 AC E2 80 9D.

  This script reverses exactly that transformation, and only that
  transformation. It works on runs, not on the whole file:

    1. Scan for a character whose code point is a plausible UTF-8 lead byte as
       seen through Windows-1252: 0xC2-0xDF (2-byte), 0xE0-0xEF (3-byte), or
       0xF0-0xF4 (4-byte).
    2. Take that character plus the following continuation characters.
    3. Encode the run back to Windows-1252 with an exception fallback, so any
       character that is not representable aborts the attempt.
    4. Decode those bytes as UTF-8 with an exception fallback, so anything that
       is not well-formed UTF-8 aborts the attempt.
    5. Replace the run only if both steps succeed and the result is a single
       code point outside the C1 control range.

  Any run that fails at any step is left byte-for-byte untouched. That is what
  protects genuine characters: a real em dash (U+2014) is representable in
  Windows-1252 as the single byte 0x97, but 0x97 on its own is not well-formed
  UTF-8, so step 4 rejects it and the character survives unchanged.

  The byte-order mark and all line endings are preserved. The operation is
  idempotent: repaired text contains no lead-byte characters, so a second run
  changes nothing.

.PARAMETER Path
  Files to repair. Relative paths resolve against the repository root. Defaults
  to the two canonical novice guides.

.PARAMETER DryRun
  Report what would change without writing to disk.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ci\Repair-DocEncoding.ps1 -DryRun

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ci\Repair-DocEncoding.ps1

.NOTES
  Exit codes: 0 success (including "nothing to do"), 1 failure.
#>
[CmdletBinding()]
param(
    [string[]]$Path = @(
        'docs\guides\WINDOWS_NOVICE_USABILITY_GUIDE.md',
        'docs\guides\LINUX_NOVICE_USABILITY_GUIDE.md'
    ),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Strict codecs. The exception fallbacks are the whole safety mechanism: they
# turn "this run is not mojibake" into a catchable error instead of a silent
# substitution with '?' or U+FFFD.
$Cp1252 = [Text.Encoding]::GetEncoding(
    1252,
    (New-Object Text.EncoderExceptionFallback),
    (New-Object Text.DecoderExceptionFallback))
$Utf8Strict = [Text.Encoding]::GetEncoding(
    'utf-8',
    (New-Object Text.EncoderExceptionFallback),
    (New-Object Text.DecoderExceptionFallback))
$Utf8NoBom = New-Object Text.UTF8Encoding($false)

function Get-MojibakeRunLength {
    <#
      Returns the expected run length if $Char is a plausible UTF-8 lead byte
      seen through Windows-1252, otherwise 0.

      0xC0 and 0xC1 are excluded: they only ever introduce overlong encodings,
      which strict UTF-8 rejects anyway. 0xF5-0xFF are excluded: above U+10FFFF.
    #>
    param([char]$Char)
    $code = [int]$Char
    if ($code -ge 0xC2 -and $code -le 0xDF) { return 2 }
    if ($code -ge 0xE0 -and $code -le 0xEF) { return 3 }
    if ($code -ge 0xF0 -and $code -le 0xF4) { return 4 }
    return 0
}

function Convert-MojibakeRun {
    <#
      Attempts the cp1252 -> UTF-8 round trip on a single candidate run.
      Returns the repaired string, or $null if this run is not mojibake.
    #>
    param([string]$Run)

    try {
        $bytes = $Cp1252.GetBytes($Run)
    } catch {
        # A character in the run has no Windows-1252 representation, so it
        # cannot have come from a Windows-1252 misread.
        return $null
    }

    # Windows-1252 is single byte. Anything else means the run is not a
    # byte-for-character mapping and must not be touched.
    if ($bytes.Length -ne $Run.Length) { return $null }

    try {
        $decoded = $Utf8Strict.GetString($bytes)
    } catch {
        # Not well-formed UTF-8. This is the branch that protects real
        # punctuation such as a genuine em dash.
        return $null
    }

    # The run must collapse to exactly one code point: one char, or two for a
    # surrogate pair from a 4-byte sequence.
    if ($decoded.Length -eq 1) {
        if ([char]::IsSurrogate($decoded[0])) { return $null }
    } elseif ($decoded.Length -eq 2) {
        if (-not [char]::IsSurrogatePair($decoded[0], $decoded[1])) { return $null }
    } else {
        return $null
    }

    # Refuse to emit C1 controls. Well-formed UTF-8 can encode them, but their
    # presence means the source was not really mojibake, and writing them would
    # trade visible corruption for invisible corruption.
    if ($decoded.Length -eq 1) {
        $code = [int]$decoded[0]
        if ($code -ge 0x80 -and $code -le 0x9F) { return $null }
    }

    return $decoded
}

function Convert-MojibakeText {
    param([string]$Text, [ref]$Replacements)

    $sb = New-Object Text.StringBuilder($Text.Length)
    $counts = @{}
    $i = 0

    while ($i -lt $Text.Length) {
        $runLength = Get-MojibakeRunLength $Text[$i]

        if ($runLength -gt 0 -and ($i + $runLength) -le $Text.Length) {
            $run = $Text.Substring($i, $runLength)
            $repaired = Convert-MojibakeRun $run

            if ($null -ne $repaired) {
                [void]$sb.Append($repaired)
                $key = '{0} -> U+{1:X4}' -f $run, [int]$repaired[0]
                if ($counts.ContainsKey($key)) { $counts[$key]++ } else { $counts[$key] = 1 }
                $i += $runLength
                continue
            }
        }

        [void]$sb.Append($Text[$i])
        $i++
    }

    $Replacements.Value = $counts
    return $sb.ToString()
}

function Get-SuspiciousCharacterReport {
    param([string]$Text)
    $found = @{}
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int]$ch
        if (($code -ge 0x80 -and $code -le 0x9F) -or $code -eq 0x00E2) {
            if ($found.ContainsKey($code)) { $found[$code]++ } else { $found[$code] = 1 }
        }
    }
    return $found
}

# --- Main ---------------------------------------------------------------------
$totalReplacements = 0
$filesChanged = 0
$failed = $false

foreach ($relative in $Path) {
    $full = if ([IO.Path]::IsPathRooted($relative)) { $relative } else { Join-Path $RepoRoot $relative }

    if (-not (Test-Path -LiteralPath $full)) {
        Write-Host "SKIP  $relative (not found)" -ForegroundColor Yellow
        $failed = $true
        continue
    }

    $bytes = [IO.File]::ReadAllBytes($full)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $body = if ($hasBom) { $bytes[3..($bytes.Length - 1)] } else { $bytes }

    try {
        $text = $Utf8Strict.GetString($body)
    } catch {
        Write-Host "FAIL  $relative is not valid UTF-8; refusing to touch it." -ForegroundColor Red
        $failed = $true
        continue
    }

    $crlfBefore = [regex]::Matches($text, "`r`n").Count
    $lfBefore = [regex]::Matches($text, "(?<!`r)`n").Count

    $counts = $null
    $repaired = Convert-MojibakeText -Text $text -Replacements ([ref]$counts)
    $fileReplacements = 0
    foreach ($v in $counts.Values) { $fileReplacements += $v }

    $crlfAfter = [regex]::Matches($repaired, "`r`n").Count
    $lfAfter = [regex]::Matches($repaired, "(?<!`r)`n").Count

    Write-Host ""
    Write-Host "=== $relative ===" -ForegroundColor Cyan
    Write-Host ("  BOM: {0}   line endings: CRLF {1} -> {2}, bare LF {3} -> {4}" -f `
        $(if ($hasBom) { 'preserved' } else { 'none' }), $crlfBefore, $crlfAfter, $lfBefore, $lfAfter)

    if ($crlfBefore -ne $crlfAfter -or $lfBefore -ne $lfAfter) {
        Write-Host "  FAIL: line endings changed. Not writing." -ForegroundColor Red
        $failed = $true
        continue
    }

    if ($fileReplacements -eq 0) {
        Write-Host "  Nothing to repair." -ForegroundColor Green
        continue
    }

    Write-Host "  Replacements: $fileReplacements" -ForegroundColor Green
    $counts.GetEnumerator() | Sort-Object -Property @{Expression = { $_.Value }; Descending = $true } | ForEach-Object {
        Write-Host ("    {0,-24} x{1}" -f $_.Key, $_.Value)
    }

    $residue = Get-SuspiciousCharacterReport $repaired
    if ($residue.Count -gt 0) {
        Write-Host "  WARNING: suspicious characters remain after repair:" -ForegroundColor Yellow
        $residue.GetEnumerator() | Sort-Object Name | ForEach-Object {
            Write-Host ("    U+{0:X4} x{1}" -f $_.Name, $_.Value) -ForegroundColor Yellow
        }
    }

    $totalReplacements += $fileReplacements
    $filesChanged++

    if ($DryRun) {
        Write-Host "  DRY RUN: not written." -ForegroundColor Yellow
        continue
    }

    $outBytes = New-Object 'System.Collections.Generic.List[byte]'
    if ($hasBom) { $outBytes.AddRange([byte[]]@(0xEF, 0xBB, 0xBF)) }
    $outBytes.AddRange($Utf8NoBom.GetBytes($repaired))
    [IO.File]::WriteAllBytes($full, $outBytes.ToArray())
    Write-Host "  Written." -ForegroundColor Green
}

Write-Host ""
if ($failed) {
    Write-Host "FAIL: one or more files could not be processed." -ForegroundColor Red
    exit 1
}
$verb = if ($DryRun) { 'would repair' } else { 'repaired' }
Write-Host "PASS: $verb $totalReplacements sequence(s) across $filesChanged file(s)." -ForegroundColor Green
exit 0
