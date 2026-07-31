function ConvertTo-RedactedText([string]$Text) {
  if ($null -eq $Text) { return '' }
  $patterns = @(
    '(?i)(OPENAI_API_KEY|API_KEY|TOKEN|PASSWORD|SECRET)\s*[:=]\s*[^\s,;]+' ,
    '(?i)Bearer\s+[A-Za-z0-9._~-]+' ,
    'sk-[A-Za-z0-9_-]{12,}'
  )
  foreach ($pattern in $patterns) { $Text = [regex]::Replace($Text, $pattern, { param($m) ($m.Value -replace '[:=].*$', ': [REDACTED]') -replace '(?i)(Bearer)\s+.*$', '$1 [REDACTED]' -replace 'sk-[A-Za-z0-9_-]{12,}', '[REDACTED]' }) }
  return $Text
}

function Get-FailureClass([int]$ExitCode, [bool]$TimedOut = $false, [bool]$OutputLimit = $false) {
  if ($TimedOut) { return 'timeout' }
  if ($OutputLimit) { return 'output_limit' }
  switch ($ExitCode) { 0 { 'none' } 2 { 'usage' } 3 { 'prerequisite' } 4 { 'codex' } 5 { 'contract' } default { 'failed' } }
}
