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

function Assert-ReviewJson([string]$Json, [string]$SchemaPath) {
  if ([string]::IsNullOrWhiteSpace($Json)) { throw 'Review JSON is empty.' }
  try { $document = $Json | ConvertFrom-Json } catch { throw "Review JSON is invalid: $($_.Exception.Message)" }
  if (-not $SchemaPath -or -not (Test-Path -LiteralPath $SchemaPath)) { throw 'Review JSON schema is missing.' }
  $schema = Get-Content -LiteralPath $SchemaPath -Raw | ConvertFrom-Json
  Test-ReviewJsonSchemaNode $document $schema '$'
}

function Test-ReviewJsonSchemaNode([object]$Value, [object]$Schema, [string]$Path) {
  if ($null -ne $Schema.const -and $Value -ne $Schema.const) { throw "Schema const mismatch at $Path." }
  if ($null -ne $Schema.enum -and @($Schema.enum) -notcontains $Value) { throw "Schema enum mismatch at $Path." }
  if ($Schema.type -eq 'object') {
    if ($null -eq $Value -or $Value -isnot [pscustomobject]) { throw "Schema expected an object at $Path." }
    $properties = @($Schema.properties.PSObject.Properties.Name)
    foreach ($required in @($Schema.required)) {
      if ($null -eq $Value.PSObject.Properties[$required]) { throw "Schema required property missing at $Path.$required." }
    }
    foreach ($property in $Value.PSObject.Properties) {
      if ($Schema.additionalProperties -eq $false -and $properties -notcontains $property.Name) { throw "Schema disallows property at $Path.$($property.Name)." }
      if ($properties -contains $property.Name) { Test-ReviewJsonSchemaNode $property.Value $Schema.properties.$($property.Name) "$Path.$($property.Name)" }
    }
  } elseif ($Schema.type -eq 'array') {
    if ($Value -isnot [array]) { throw "Schema expected an array at $Path." }
    foreach ($item in $Value) { Test-ReviewJsonSchemaNode $item $Schema.items "$Path[]" }
  } elseif ($Schema.type -eq 'string') {
    if ($Value -isnot [string]) { throw "Schema expected a string at $Path." }
    if ($null -ne $Schema.maxLength -and $Value.Length -gt [int]$Schema.maxLength) { throw "Schema string is too long at $Path." }
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

function Write-ReviewManifest([string]$Path, [string[]]$Manifest) {
  Set-Content -LiteralPath $Path -Value ($Manifest -join "`n") -Encoding UTF8
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

function Get-ReviewFindings([string]$Markdown) {
  $lines = $Markdown -split '\r?\n'
  $findings = @()
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $heading = [regex]::Match($lines[$i], '(?i)^###\s+\[(critical|high|medium|low|info)\]\s+(.+)$')
    if (-not $heading.Success) { continue }
    $block = @()
    for ($j = $i + 1; $j -lt $lines.Count -and $lines[$j] -notmatch '^###\s+\[' -and $lines[$j] -notmatch '^##\s+'; $j++) { $block += $lines[$j] }
    $blockText = $block -join "`n"
    $location = [regex]::Match($blockText, '(?m)^-\s+\*\*Location:\*\*\s+(.+)$')
    $why = [regex]::Match($blockText, '(?m)^-\s+\*\*Why it matters:\*\*\s+(.+)$')
    $evidence = [regex]::Match($blockText, '(?m)^-\s+\*\*Evidence:\*\*\s+(.+)$')
    $fix = [regex]::Match($blockText, '(?m)^-\s+\*\*Suggested fix:\*\*\s+(.+)$')
    if ($location.Success -and $why.Success -and $evidence.Success -and $fix.Success) {
      $findings += [ordered]@{
        severity = $heading.Groups[1].Value.ToLowerInvariant()
        title = $heading.Groups[2].Value.Trim()
        location = $location.Groups[1].Value.Trim()
        evidence = ($why.Groups[1].Value.Trim() + ' ' + $evidence.Groups[1].Value.Trim()).Trim()
        suggested_fix = $fix.Groups[1].Value.Trim()
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
  $result = @()
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $heading = [regex]::Match($lines[$i], '(?i)^###\s+\[(critical|high|medium|low|info)\]\s+(.+)$')
    if (-not $heading.Success) { $result += $lines[$i]; continue }
    $j = $i + 1
    while ($j -lt $lines.Count -and $lines[$j] -notmatch '^###\s+\[' -and $lines[$j] -notmatch '^##\s+') { $j++ }
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
  $declared = @([regex]::Matches($Markdown, '(?im)^###\s+\[(critical|high|medium|low|info)\]\s+')).Count
  if ($declared -ne @($Findings).Count) { throw "Review contains $declared declared findings but only $(@($Findings).Count) valid findings." }
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
