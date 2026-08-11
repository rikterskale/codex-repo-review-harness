function ConvertTo-RedactedText([string]$Text) {
  if ($null -eq $Text) { return '' }
  $patterns = @(
    '(?i)(OPENAI_API_KEY|API_KEY|TOKEN|PASSWORD|SECRET)\s*[:=]\s*[^\s,;]+' ,
    '(?i)Bearer\s+[A-Za-z0-9._~-]+' ,
    '(?i)(?:sk|ghp|gho|ghs|ghr)[_-][A-Za-z0-9_-]{12,}',
    '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
  )
  foreach ($pattern in $patterns) {
    $Text = [regex]::Replace($Text, $pattern, {
      param($m)
      if ($m.Value -match '(?i)^Bearer\s+') { return 'Bearer [REDACTED]' }
      if ($m.Value -match '(?i)^-----BEGIN') { return '[REDACTED PRIVATE KEY]' }
      if ($m.Value -match '[:=]') { return (($m.Value -replace '[:=].*$', ': [REDACTED]')) }
      return '[REDACTED]'
    })
  }
  return $Text
}

function ConvertTo-ReviewJsonPortableValue([object]$Value) {
  # PowerShell 7's ConvertFrom-Json coerces ISO-8601 strings into [datetime] (or
  # [datetimeoffset]); Windows PowerShell 5.1 leaves them as [string]. Without
  # this normalisation the same JSON validates differently depending on the host,
  # so CI (pwsh) and the local runner (Windows PowerShell) disagree. Converting
  # back to a round-trip string keeps the schema's string constraints applicable
  # instead of silently skipping them.
  if ($null -eq $Value) { return $null }
  if ($Value -is [string]) { return $Value }
  if ($Value -is [datetime]) { return $Value.ToString('o', [Globalization.CultureInfo]::InvariantCulture) }
  if ($Value -is [datetimeoffset]) { return $Value.ToString('o', [Globalization.CultureInfo]::InvariantCulture) }
  # The leading comma stops PowerShell unrolling the result: without it an empty
  # array is returned as nothing, which the caller sees as $null.
  if ($Value -is [array]) { return ,@($Value | ForEach-Object { ConvertTo-ReviewJsonPortableValue $_ }) }
  if ($Value -is [pscustomobject]) {
    foreach ($property in @($Value.PSObject.Properties)) {
      $property.Value = ConvertTo-ReviewJsonPortableValue $property.Value
    }
    return $Value
  }
  return $Value
}

function Assert-ReviewJson([string]$Json, [string]$SchemaPath) {
  if ([string]::IsNullOrWhiteSpace($Json)) { throw 'Review JSON is empty.' }
  try { $document = $Json | ConvertFrom-Json } catch { throw "Review JSON is invalid: $($_.Exception.Message)" }
  if (-not $SchemaPath -or -not (Test-Path -LiteralPath $SchemaPath)) { throw 'Review JSON schema is missing.' }
  $document = ConvertTo-ReviewJsonPortableValue $document
  $schema = Get-Content -LiteralPath $SchemaPath -Raw | ConvertFrom-Json
  Test-ReviewJsonSchemaNode $document $schema '$'
}

function Get-ReviewJsonSchemaTypeName([object]$Value) {
  if ($null -eq $Value) { return 'null' }
  if ($Value -is [bool]) { return 'boolean' }
  if ($Value -is [string]) { return 'string' }
  if ($Value -is [array]) { return 'array' }
  if ($Value -is [pscustomobject]) { return 'object' }
  if ($Value -is [long] -or $Value -is [int] -or $Value -is [short] -or $Value -is [byte]) { return 'integer' }
  if ($Value -is [decimal] -or $Value -is [double] -or $Value -is [single]) {
    if ([math]::Floor([double]$Value) -eq [double]$Value) { return 'integer' }
    return 'number'
  }
  return $Value.GetType().Name
}

function Test-ReviewJsonSchemaNode([object]$Value, [object]$Schema, [string]$Path) {
  if ($null -ne $Schema.const -and $Value -ne $Schema.const) { throw "Schema const mismatch at ${Path}: expected '$($Schema.const)', got '$Value'." }
  if ($null -ne $Schema.enum -and @($Schema.enum) -notcontains $Value) { throw "Schema enum mismatch at ${Path}: '$Value' is not one of [$(@($Schema.enum) -join ', ')]." }
  $expectedTypes = @()
  if ($null -ne $Schema.type) { $expectedTypes = @($Schema.type) }
  if ($expectedTypes.Count -gt 0) {
    $actual = Get-ReviewJsonSchemaTypeName $Value
    $ok = $false
    foreach ($t in $expectedTypes) {
      if ($actual -eq $t) { $ok = $true; break }
      if ($t -eq 'number' -and $actual -eq 'integer') { $ok = $true; break }
    }
    if (-not $ok) { throw "Schema type mismatch at ${Path}: expected $($expectedTypes -join '|'), got $actual." }
  }
  if ($null -ne $Schema.oneOf) {
    $passing = 0
    foreach ($sub in @($Schema.oneOf)) { try { Test-ReviewJsonSchemaNode $Value $sub $Path; $passing++ } catch { } }
    if ($passing -ne 1) { throw "Schema oneOf mismatch at ${Path}: matched $passing subschemas (expected 1)." }
  }
  if ($null -ne $Schema.anyOf) {
    $passing = 0
    foreach ($sub in @($Schema.anyOf)) { try { Test-ReviewJsonSchemaNode $Value $sub $Path; $passing++; break } catch { } }
    if ($passing -eq 0) { throw "Schema anyOf mismatch at ${Path}: no subschema matched." }
  }
  if ($null -ne $Schema.allOf) {
    foreach ($sub in @($Schema.allOf)) { Test-ReviewJsonSchemaNode $Value $sub $Path }
  }
  if (($expectedTypes -contains 'object') -or ($expectedTypes.Count -eq 0 -and $Value -is [pscustomobject])) {
    if ($Value -is [pscustomobject]) {
      $properties = if ($null -ne $Schema.properties) { @($Schema.properties.PSObject.Properties.Name) } else { @() }
      foreach ($required in @($Schema.required)) {
        if ($null -eq $Value.PSObject.Properties[$required]) { throw "Schema required property missing at ${Path}: '${required}'." }
      }
      foreach ($property in $Value.PSObject.Properties) {
        $propPath = "${Path}.$($property.Name)"
        if ($properties -contains $property.Name) {
          Test-ReviewJsonSchemaNode $property.Value $Schema.properties.$($property.Name) $propPath
        } elseif ($Schema.additionalProperties -eq $false) {
          throw "Schema disallows property at ${propPath}."
        } elseif ($null -ne $Schema.additionalProperties -and $Schema.additionalProperties -isnot [bool]) {
          Test-ReviewJsonSchemaNode $property.Value $Schema.additionalProperties $propPath
        }
      }
    }
  }
  if (($expectedTypes -contains 'array') -or ($expectedTypes.Count -eq 0 -and $Value -is [array])) {
    if ($Value -is [array]) {
      if ($null -ne $Schema.maxItems -and $Value.Count -gt [int]$Schema.maxItems) { throw "Schema maxItems exceeded at ${Path}: $($Value.Count) > $($Schema.maxItems)." }
      if ($null -ne $Schema.minItems -and $Value.Count -lt [int]$Schema.minItems) { throw "Schema minItems not met at ${Path}: $($Value.Count) < $($Schema.minItems)." }
      if ($null -ne $Schema.items) {
        for ($i = 0; $i -lt $Value.Count; $i++) { Test-ReviewJsonSchemaNode $Value[$i] $Schema.items "${Path}[$i]" }
      }
    }
  }
  if (($expectedTypes -contains 'string') -or ($expectedTypes.Count -eq 0 -and $Value -is [string])) {
    if ($Value -is [string]) {
      if ($null -ne $Schema.maxLength -and $Value.Length -gt [int]$Schema.maxLength) { throw "Schema maxLength exceeded at ${Path}: length $($Value.Length) > $($Schema.maxLength)." }
      if ($null -ne $Schema.minLength -and $Value.Length -lt [int]$Schema.minLength) { throw "Schema minLength not met at ${Path}: length $($Value.Length) < $($Schema.minLength)." }
      if ($null -ne $Schema.pattern -and $Value -notmatch [string]$Schema.pattern) { throw "Schema pattern mismatch at ${Path}: value does not match /$([string]$Schema.pattern)/." }
    }
  }
  if (($expectedTypes -contains 'integer' -or $expectedTypes -contains 'number')) {
    if ($null -ne $Schema.minimum -and [double]$Value -lt [double]$Schema.minimum) { throw "Schema minimum not met at ${Path}: $Value < $($Schema.minimum)." }
    if ($null -ne $Schema.maximum -and [double]$Value -gt [double]$Schema.maximum) { throw "Schema maximum exceeded at ${Path}: $Value > $($Schema.maximum)." }
  }
}

function ConvertTo-ReviewGlobRegex([string]$Pattern) {
  $escaped = [regex]::Escape(($Pattern -replace '\\','/'))
  return '^' + $escaped.Replace('\*\*', '.*').Replace('\*', '[^/]*').Replace('\?', '[^/]') + '$'
}

function Test-ReviewPathPattern([string]$Path, [string]$Pattern) {
  return $Path -match (ConvertTo-ReviewGlobRegex $Pattern)
}

function Get-ReviewFileManifest([string]$RepositoryRoot, [object]$Config) {
  $paths = @(git -c core.excludesfile=NUL -C $RepositoryRoot ls-files --cached --others --exclude-standard 2>$null | ForEach-Object { $_.Trim() -replace '\\','/' } | Where-Object { $_ })
  $includes = @($Config.include_paths | Where-Object { $_ })
  $excludes = @($Config.exclude_paths | Where-Object { $_ })
  $selected = foreach ($path in $paths) {
    $included = ($includes.Count -eq 0) -or (@($includes | Where-Object { Test-ReviewPathPattern $path $_ }).Count -gt 0)
    $excluded = @($excludes | Where-Object { Test-ReviewPathPattern $path $_ }).Count -gt 0
    if ($included -and -not $excluded) { $path }
  }
  return @($selected | Sort-Object -Unique)
}

function Write-ReviewUtf8([string]$Path, [string]$Content) {
  $encoding = New-Object System.Text.UTF8Encoding($false, $true)
  [IO.File]::WriteAllBytes($Path, $encoding.GetBytes([string]$Content))
}

function Write-ReviewManifest([string]$Path, [string[]]$Manifest) {
  Write-ReviewUtf8 $Path (($Manifest -join "`n") + "`n")
}

function Limit-ReviewUtf8([string]$Text, [int]$MaxBytes, [string]$Suffix = '') {
  $encoding = New-Object System.Text.UTF8Encoding($false, $true)
  if ($encoding.GetByteCount($Text) -le $MaxBytes) { return $Text }
  $suffixBytes = $encoding.GetByteCount($Suffix)
  if ($suffixBytes -gt $MaxBytes) { throw 'UTF-8 truncation suffix exceeds the output limit.' }
  $source = $encoding.GetBytes($Text)
  for ($length = $MaxBytes - $suffixBytes; $length -ge 0; $length--) {
    try { return $encoding.GetString($source, 0, $length) + $Suffix } catch { }
  }
  throw 'Unable to produce valid UTF-8 output within the limit.'
}

function Get-ReviewConfig([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "Missing review configuration: $Path" }
  $text = Get-Content -LiteralPath $Path -Raw
  function Scalar([string]$Name, [string]$Default = '') {
    $pattern = '(?m)^' + [regex]::Escape($Name) + '\s*:\s*["'']?([^"''\r\n#]+)'
    $match = [regex]::Match($text, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return $Default
  }
  function List([string]$Name) {
    $pattern = '(?ms)^' + [regex]::Escape($Name) + '\s*:\s*\r?\n(?<items>(?:\s+-\s+[^\r\n]*\r?\n)*)'
    $match = [regex]::Match($text, $pattern)
    if (-not $match.Success) { return @() }
    return @([regex]::Matches($match.Groups['items'].Value, '(?m)^\s+-\s+([^#\r\n]+)') | ForEach-Object { $_.Groups[1].Value.Trim().Trim('"').Trim("'") })
  }
  $reportMatch = [regex]::Match($text, '(?ms)^report:\s*\r?\n(?<block>(?:\s+[^\r\n]*\r?\n)*)')
  $reportText = if ($reportMatch.Success) { $reportMatch.Groups['block'].Value } else { '' }
  function ReportScalar([string]$Name, [string]$Default = '') {
    $pattern = '(?m)^\s+' + [regex]::Escape($Name) + '\s*:\s*["'']?([^"''\r\n#]+)'
    $match = [regex]::Match($reportText, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return $Default
  }
  $extraMatch = [regex]::Match($text, '(?ms)^extra_instructions:\s*\|\s*\r?\n(?<block>(?:\s+[^\r\n]*(?:\r?\n|$))*)')
  $extra = if ($extraMatch.Success) { ($extraMatch.Groups['block'].Value -replace '(?m)^\s{2}', '').Trim() } else { '' }
  return [ordered]@{
    base_branch = Scalar 'base_branch' 'main'
    sandbox = Scalar 'sandbox' 'read-only'
    min_severity = Scalar 'min_severity' 'medium'
    model = Scalar 'model' ''
    focus_areas = List 'focus_areas'
    include_paths = List 'include_paths'
    exclude_paths = List 'exclude_paths'
    extra_instructions = $extra
    report = [ordered]@{
      output_dir = ReportScalar 'output_dir' 'reports'
      include_summary = ReportScalar 'include_summary' 'true'
      max_findings = [int](ReportScalar 'max_findings' '50')
    }
  }
}

function Get-ReviewNonCodeLines([string]$Markdown) {
  # Returns a boolean array parallel to the split lines: $true where the line
  # is prose (outside a fenced code block), $false inside a fence. Fences are
  # opened and closed by lines whose first non-whitespace run is ``` or ~~~,
  # regardless of the language tag that follows.
  $lines = $Markdown -split '\r?\n'
  $inFence = $false
  $fenceMark = ''
  $mask = New-Object 'bool[]' $lines.Count
  for ($k = 0; $k -lt $lines.Count; $k++) {
    $stripped = $lines[$k].TrimStart()
    $fenceMatch = [regex]::Match($stripped, '^(`{3,}|~{3,})')
    if ($fenceMatch.Success) {
      if (-not $inFence) {
        $inFence = $true
        $fenceMark = $fenceMatch.Groups[1].Value.Substring(0, 1)
      } elseif ($stripped.StartsWith($fenceMark * 3)) {
        $inFence = $false
      }
      $mask[$k] = $false
      continue
    }
    $mask[$k] = -not $inFence
  }
  return ,$mask
}

function Get-ReviewFindings([string]$Markdown) {
  $lines = $Markdown -split '\r?\n'
  $prose = Get-ReviewNonCodeLines $Markdown
  $findings = @()
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if (-not $prose[$i]) { continue }
    $heading = [regex]::Match($lines[$i], '(?i)^###\s+\[(critical|high|medium|low|info)\]\s+(.+)$')
    if (-not $heading.Success) { continue }
    $block = @()
    for ($j = $i + 1; $j -lt $lines.Count -and -not (($prose[$j]) -and ($lines[$j] -match '^###\s+\[' -or $lines[$j] -match '^##\s+')); $j++) {
      if ($prose[$j]) { $block += $lines[$j] }
    }
    $blockText = $block -join "`n"
    $location = [regex]::Match($blockText, '(?m)^-\s+\*\*Location\*\*\s*:\s*(.+)$|^-\s+\*\*Location:\*\*\s+(.+)$')
    $why = [regex]::Match($blockText, '(?m)^-\s+\*\*Why it matters\*\*\s*:\s*(.+)$|^-\s+\*\*Why it matters:\*\*\s+(.+)$')
    $evidence = [regex]::Match($blockText, '(?m)^-\s+\*\*Evidence\*\*\s*:\s*(.+)$|^-\s+\*\*Evidence:\*\*\s+(.+)$')
    $fix = [regex]::Match($blockText, '(?m)^-\s+\*\*Suggested fix\*\*\s*:\s*(.+)$|^-\s+\*\*Suggested fix:\*\*\s+(.+)$')
    if ($location.Success -and $why.Success -and $evidence.Success -and $fix.Success) {
      $locationValue = if ($location.Groups[1].Success) { $location.Groups[1].Value } else { $location.Groups[2].Value }
      $whyValue = if ($why.Groups[1].Success) { $why.Groups[1].Value } else { $why.Groups[2].Value }
      $evidenceValue = if ($evidence.Groups[1].Success) { $evidence.Groups[1].Value } else { $evidence.Groups[2].Value }
      $fixValue = if ($fix.Groups[1].Success) { $fix.Groups[1].Value } else { $fix.Groups[2].Value }
      $findings += [ordered]@{
        severity = $heading.Groups[1].Value.ToLowerInvariant()
        title = $heading.Groups[2].Value.Trim()
        location = $locationValue.Trim()
        evidence = ($whyValue.Trim() + ' ' + $evidenceValue.Trim()).Trim()
        suggested_fix = $fixValue.Trim()
      }
    }
    $i = $j - 1
  }
  return @($findings)
}

function Assert-ReviewMarkdown([string]$Markdown) {
  foreach ($heading in @('## Executive Summary', '## Findings', '## Positive Observations', '## Recommended Next Actions')) {
    if ($Markdown -notmatch [regex]::Escape($heading)) { throw "Review Markdown is missing required section: $heading" }
  }
  if ($Markdown -notmatch '(?m)^# Codex Repository Review Report\s*$') { throw 'Review Markdown has an invalid title.' }
}

function Filter-ReviewMarkdown([string]$Markdown, [object[]]$AllowedFindings) {
  $allowed = @{}
  foreach ($finding in @($AllowedFindings)) { $allowed[($finding.severity + '|' + $finding.title)] = $true }
  $lines = $Markdown -split '\r?\n'
  $prose = Get-ReviewNonCodeLines $Markdown
  $result = @()
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $heading = if ($prose[$i]) { [regex]::Match($lines[$i], '(?i)^###\s+\[(critical|high|medium|low|info)\]\s+(.+)$') } else { $null }
    if ($null -eq $heading -or -not $heading.Success) { $result += $lines[$i]; continue }
    $j = $i + 1
    while ($j -lt $lines.Count -and -not (($prose[$j]) -and ($lines[$j] -match '^###\s+\[' -or $lines[$j] -match '^##\s+'))) { $j++ }
    $key = $heading.Groups[1].Value.ToLowerInvariant() + '|' + $heading.Groups[2].Value.Trim()
    if ($allowed.ContainsKey($key)) { $result += $lines[$i..($j - 1)] }
    $i = $j - 1
  }
  return ($result -join "`n")
}

function Assert-ReviewReportConsistency([string]$Markdown, [object[]]$Findings) {
  $markdownFindings = @(Get-ReviewFindings $Markdown)
  if ($markdownFindings.Count -ne @($Findings).Count) { throw 'Markdown and JSON findings counts differ.' }
  for ($i = 0; $i -lt $markdownFindings.Count; $i++) {
    foreach ($field in @('severity','title','location','suggested_fix')) {
      if ($markdownFindings[$i].$field -ne $Findings[$i].$field) { throw "Markdown and JSON findings differ for $field at index $i." }
    }
  }
}

function Test-ReviewSecrets([string]$Text) {
  if ($null -eq $Text) { return $false }
  $candidate = $Text -replace '(?i)(OPENAI_API_KEY|API_KEY|PASSWORD|SECRET)\s*[:=]\s*\[REDACTED\]', ''
  $candidate = $candidate -replace '\[REDACTED(?: PRIVATE KEY)?\]', ''
  return $candidate -match '(?i)(OPENAI_API_KEY|API_KEY|PASSWORD|SECRET)\s*[:=]\s*\S+|(?:sk|ghp|gho|ghs|ghr)[_-][A-Za-z0-9_-]{12,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'
}

function Get-ReviewStatus([object[]]$Findings) {
  if ($null -eq $Findings -or $Findings.Count -eq 0) { return 'passed' }
  return 'findings'
}

function Assert-ReviewFindings([string]$Markdown, [object[]]$Findings) {
  $lines = $Markdown -split '\r?\n'
  $prose = Get-ReviewNonCodeLines $Markdown
  $declaredHeadings = @()
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if (-not $prose[$i]) { continue }
    $m = [regex]::Match($lines[$i], '(?im)^###\s+\[(critical|high|medium|low|info)\]\s+(.+)$')
    if ($m.Success) { $declaredHeadings += [pscustomobject]@{ Severity = $m.Groups[1].Value.ToLowerInvariant(); Title = $m.Groups[2].Value.Trim(); Line = $i + 1 } }
  }
  if ($declaredHeadings.Count -eq @($Findings).Count) { return }
  $parsedKeys = @{}
  foreach ($f in @($Findings)) { $parsedKeys[($f.severity + '|' + $f.title)] = $true }
  $unparsed = @($declaredHeadings | Where-Object { -not $parsedKeys.ContainsKey($_.Severity + '|' + $_.Title) })
  $detail = if ($unparsed.Count -gt 0) {
    ($unparsed | ForEach-Object { "  - line $($_.Line): [$($_.Severity.ToUpper())] $($_.Title) - missing one of **Location:** / **Why it matters:** / **Evidence:** / **Suggested fix:**" }) -join "`n"
  } else { '  (all headings parsed; count mismatch is on the JSON side)' }
  throw "Review contains $($declaredHeadings.Count) declared findings but only $(@($Findings).Count) valid findings. Unparseable headings:`n$detail"
}

# The novice guides make factual claims about the harness surface: the scripts
# users run, the config they edit, the prompts that shape a review, and the
# workflows. Digesting exactly those files is what makes the guides' freshness
# claim checkable.
#
# The guides themselves are excluded, which is the whole point: a guide edit
# cannot change the digest, so the guide and its updated digest fit in one
# commit.
#
# Tests and schemas are included because the guides cite them by name and by
# line: the Linux guide lists individual test scripts as evidence and cites
# schemas/review-report.schema.json line 7 for the report schema version. That
# costs guide churn on test changes, which is the honest price of the guides
# making claims that specific. Templates and .gitignore appear in the guides
# only inside directory listings, so editing a file inside them cannot falsify
# anything, and including them would buy churn without buying correctness.
# An empty Extension list means every file in the directory. GitHub Actions
# accepts both .yml and .yaml, so matching only one of them would let a workflow
# change slip past the freshness check.
function Get-GuideSubjectFile([string]$Root) {
  $relative = New-Object 'System.Collections.Generic.List[string]'
  foreach ($spec in @(
    @{ Directory = 'scripts'; Extension = @('.ps1') },
    @{ Directory = 'tests'; Extension = @('.ps1') },
    @{ Directory = 'schemas'; Extension = @() },
    @{ Directory = 'config'; Extension = @() },
    @{ Directory = 'prompts'; Extension = @() },
    @{ Directory = (Join-Path '.github' 'workflows'); Extension = @('.yml', '.yaml') }
  )) {
    $directory = Join-Path $Root $spec.Directory
    if (-not (Test-Path -LiteralPath $directory)) { continue }
    foreach ($file in @(Get-ChildItem -LiteralPath $directory -Recurse -File)) {
      if (@($spec.Extension).Count -gt 0 -and $file.Extension.ToLowerInvariant() -notin $spec.Extension) { continue }
      $relative.Add($file.FullName.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/'))
    }
  }
  foreach ($file in @('AGENTS.md', 'README.md', 'VERSION')) {
    if (Test-Path -LiteralPath (Join-Path $Root $file)) { $relative.Add($file) }
  }
  $ordered = $relative.ToArray()
  # Ordinal, not culture-aware: Sort-Object would order these differently under
  # different locales and produce a digest that depends on the runner.
  [Array]::Sort($ordered, [StringComparer]::Ordinal)
  return @($ordered)
}

# A BOM and CRLF endings are stripped before hashing. The repository is checked
# out with autocrlf on Windows and without it on Linux, so hashing raw bytes
# would give the two CI runners different digests for identical content.
function Get-GuideDigest([string]$Root) {
  $utf8 = New-Object Text.UTF8Encoding($false)
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    $manifest = New-Object Text.StringBuilder
    foreach ($relative in Get-GuideSubjectFile $Root) {
      $text = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes((Join-Path $Root $relative)))
      if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
      $text = $text -replace "`r`n", "`n"
      $hash = [BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($text))).Replace('-', '').ToLowerInvariant()
      [void]$manifest.Append($relative).Append("`n").Append($hash).Append("`n")
    }
    return [BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes($manifest.ToString()))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

# Rewrites the recorded digest in place, preserving each guide's BOM and line
# endings so the update is a one-line diff.
function Set-GuideDigest([string]$Root, [string]$Digest) {
  $updated = @()
  foreach ($guide in @('WINDOWS_NOVICE_USABILITY_GUIDE.md', 'LINUX_NOVICE_USABILITY_GUIDE.md')) {
    $path = Join-Path $Root (Join-Path 'docs/guides' $guide)
    $bytes = [IO.File]::ReadAllBytes($path)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $text = [Text.Encoding]::UTF8.GetString($bytes)
    if ($hasBom) { $text = $text.Substring(1) }
    # Presence is tested separately from the rewrite: comparing the rewritten
    # text against the original would treat an already-current digest as a
    # missing field, so re-running this script would fail on a clean tree.
    $pattern = '(?m)^(reviewed_digest:\s*")[0-9a-fA-F]{64}(")'
    if (-not [regex]::IsMatch($text, $pattern)) { throw "Guide records no reviewed_digest to update: $guide" }
    $rewritten = [regex]::Replace($text, $pattern, ('${1}' + $Digest + '${2}'))
    $out = New-Object 'System.Collections.Generic.List[byte]'
    if ($hasBom) { $out.AddRange([byte[]]@(0xEF, 0xBB, 0xBF)) }
    $out.AddRange((New-Object Text.UTF8Encoding($false)).GetBytes($rewritten))
    [IO.File]::WriteAllBytes($path, $out.ToArray())
    $updated += $guide
  }
  return $updated
}

function Select-ReviewFindings([object[]]$Findings, [string]$MinimumSeverity) {
  $levels = @{ critical = 0; high = 1; medium = 2; low = 3; info = 4 }
  if (-not $levels.ContainsKey($MinimumSeverity)) { throw "Unsupported minimum severity: $MinimumSeverity" }
  $limit = $levels[$MinimumSeverity]
  return @($Findings | Where-Object { $levels[$_.severity] -le $limit })
}

function Get-FailureClass([int]$ExitCode, [bool]$TimedOut = $false, [bool]$OutputLimit = $false) {
  if ($TimedOut) { return 'timeout' }
  if ($OutputLimit) { return 'output_limit' }
  switch ($ExitCode) { 0 { 'none' } 2 { 'usage' } 3 { 'prerequisite' } 4 { 'codex' } 5 { 'contract' } default { 'failed' } }
}
