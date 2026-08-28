<#
.SYNOPSIS
  Shared color-token helpers for detect-colors.ps1 and recolor.ps1.

.DESCRIPTION
  Dot-sourced by both scripts so detection and replacement can never drift apart.
  Keeping one pattern in one file is the point: the bug this replaced came from
  the two scripts each carrying their own copy of a 6-digit-only regex.
#>

# Every hex form an SVG may carry, LONGEST FIRST, with a trailing guard.
#
# The order and the guard are both load-bearing. Without them, #RRGGBBAA matches
# as #RRGGBB with two characters left dangling, so an 8-digit color is silently
# rewritten to a different color that keeps the old alpha.
$script:HexTokenPattern =
    '#(?:[0-9A-Fa-f]{8}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{4}|[0-9A-Fa-f]{3})(?![0-9A-Fa-f])'

# Color notations this tool can see but deliberately does NOT rewrite. Reported so
# the user knows they were left alone, instead of finding out in Power BI.
$script:UnsupportedPatterns = [ordered]@{
    'rgb()/rgba()' = '(?i)\brgba?\s*\('
    'currentColor' = '(?i)\bcurrentColor\b'
    'named color'  = '(?i)(?:fill|stroke|stop-color|flood-color|lighting-color)\s*=\s*"\s*(?!none|inherit|transparent|currentColor|url\()[A-Za-z]{3,}\s*"'
}

function Get-CanonicalHex {
    <#
    .SYNOPSIS
      Normalize a hex token to uppercase #RRGGBB or #RRGGBBAA.
    .DESCRIPTION
      #FFF and #FFFFFF are the same color written two ways, so they must compare
      equal. #RRGGBB and #RRGGBBAA are NOT the same color and must not.
    #>
    param([Parameter(Mandatory)][string]$Token)

    $digits = $Token.Substring(1).ToUpper()
    switch ($digits.Length) {
        3 { $digits = ($digits[0].ToString() * 2) + ($digits[1].ToString() * 2) + ($digits[2].ToString() * 2) }
        4 { $digits = ($digits[0].ToString() * 2) + ($digits[1].ToString() * 2) + ($digits[2].ToString() * 2) + ($digits[3].ToString() * 2) }
    }
    return '#' + $digits
}

function Test-HexColor {
    <# Accepts any of the four written forms; used to validate -To/-From/-Exclude. #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    return $Value -match '^#(?:[0-9A-Fa-f]{8}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{4}|[0-9A-Fa-f]{3})$'
}

function Get-UnsupportedNotation {
    <#
    .SYNOPSIS
      Which non-hex color notations appear in a piece of SVG text.
    .OUTPUTS
      Hashtable of notation name -> match count. Empty when the text is hex-only.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    $found = @{}
    foreach ($name in $script:UnsupportedPatterns.Keys) {
        $count = ([regex]::Matches($Text, $script:UnsupportedPatterns[$name])).Count
        if ($count -gt 0) { $found[$name] = $count }
    }
    return $found
}

function Join-PbipPath {
    <#
    .SYNOPSIS
      Build the RegisteredResources path without a hardcoded separator.
    .DESCRIPTION
      Nested calls rather than Join-Path's multi-argument form, which needs
      PowerShell 6+; the README promises 5.1.
    #>
    param([Parameter(Mandatory)][string]$ReportDir)
    return (Join-Path (Join-Path $ReportDir 'StaticResources') 'RegisteredResources')
}

# UTF-8 without BOM. [System.Text.Encoding]::UTF8 emits one, which silently
# rewrote the encoding of every icon the tool touched.
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
