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
# Without the guard #RRGGBBAA matches as #RRGGBB with two characters left dangling,
# so an 8-digit color is silently rewritten keeping the old alpha.
$script:HexTokenPattern =
    '#(?:[0-9A-Fa-f]{8}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{4}|[0-9A-Fa-f]{3})(?![0-9A-Fa-f])'

# In SVG a '#' also introduces a FRAGMENT REFERENCE - url(#grad), href="#mask".
# Ids like "fff", "abc" or "0078D4" are ordinary SVGO output, and rewriting one
# leaves a live reference pointing at nothing while its id attribute stays put.
#
# Matched as SPANS rather than excluded with lookbehinds: the reference has too
# many legal spellings for a fixed-width lookbehind to cover them all -
# url('#a'), url( #a ), href = "#a", xlink:href='#a'. Anything inside one of
# these spans is an id, not a color.
# The quote is optional and may also arrive XML-escaped: inside a double-quoted
# attribute, url('#a') is often written url(&apos;#a&apos;).
#
# The id character classes stop at '&' and whitespace as well as at the quotes.
# Without that, an entity-quoted href has no closing delimiter the class
# recognises, so the span runs on past the attribute and can swallow a real
# color further down the line - excluding it from being rewritten at all.
$script:FragmentRefPattern =
    '(?i)(?:url\s*\(\s*(?:["'']|&apos;|&quot;)?\s*#[^)"''\s&]+' +
    '|(?:xlink:)?href\s*=\s*(?:["'']|&apos;|&quot;)\s*#[^"''\s>&]*)'

# Inside a <style> block, CSS has two uses for '#' and only one is a color:
#
#     #fff:hover > path { fill: #0078D4 }
#     ^^^^ selector                ^^^^^^^ color
#
# Three rules were tried and are recorded here as insufficient, so nobody reaches
# for them again:
#   1. matching selector shapes (#a{, #a,#b, #a:hover, #a .child, #a > path,
#      #a[attr=v]) never converges - there is always another shape.
#   2. "previous non-whitespace char is ':'" flips the error instead of removing
#      it: it SKIPS real colors in box-shadow: 0 0 2px #fff, var(--x, #fff) and
#      linear-gradient(#fff,#000), so files get reported as updated while their
#      colors stay put.
#   3. depth plus backward scan over the raw text - right in principle, but it
#      counts braces and semicolons living inside strings and url(), so
#      content:"}" or a data: URL with a ';' throws the calculation off.
#
# What works is MASK FIRST, SCAN ONCE. Comment, string and url() bodies are
# replaced by spaces of the same length, so every index in the document stays
# valid, and then a single left-to-right pass records the ranges where a
# declaration value is open. A token is a color when it survived masking and its
# index falls inside one of those ranges. One pass per block instead of a rescan
# per token, which also removes the quadratic cost on minified stylesheets.
$script:StyleBlockPattern = '(?is)<style\b[^>]*>(.*?)</style>'

# Regions of an SVG that carry TEXT, not paint. A hex string in a comment, a
# description or a script is prose or code, and rewriting it changes something
# the user never asked to change while the rendered image looks identical.
#
# Note the deliberate limit: outside these regions and outside <style>, ANY hex
# token is treated as a color. That is what makes the tool work on the attribute
# soup real icons are made of, and it is documented in the skill README rather
# than narrowed by guesswork about which attributes may carry paint.
$script:NonPaintPattern =
    '(?is)<!--.*?-->|<script\b[^>]*>.*?</script>|<desc\b[^>]*>.*?</desc>' +
    '|<title\b[^>]*>.*?</title>|<metadata\b[^>]*>.*?</metadata>'

function Get-CssValueRange {
    <#
    .SYNOPSIS
      Mask a style block and return its declaration-value ranges.
    .OUTPUTS
      Hashtable with Masked (same-length text) and Ranges (array of @(start,end)),
      both in coordinates local to the block.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Css)

    $chars = $Css.ToCharArray()
    $n = $chars.Length
    $i = 0

    # --- Pass 1: blank comment, string and url() bodies ---------------------
    while ($i -lt $n) {
        $c = $chars[$i]

        if ($c -eq [char]0x2F -and $i + 1 -lt $n -and $chars[$i + 1] -eq [char]0x2A) {
            $j = $i + 2
            while ($j + 1 -lt $n -and -not ($chars[$j] -eq [char]0x2A -and $chars[$j + 1] -eq [char]0x2F)) { $j++ }
            $j = [Math]::Min($j + 2, $n)
            for ($k = $i; $k -lt $j; $k++) { $chars[$k] = ' ' }
            $i = $j
            continue
        }

        if ($c -eq [char]0x22 -or $c -eq [char]0x27) {
            $quote = $c
            $j = $i + 1
            while ($j -lt $n -and $chars[$j] -ne $quote) {
                if ($chars[$j] -eq [char]0x5C -and $j + 1 -lt $n) { $j++ }
                $j++
            }
            # Blank the BODY, keep the quotes so the structure still reads.
            for ($k = $i + 1; $k -lt [Math]::Min($j, $n); $k++) { $chars[$k] = ' ' }
            $i = [Math]::Min($j + 1, $n)
            continue
        }

        # url( ... ): its body is a URL, and a '#' there is a fragment, not a color
        if (($c -eq 'u' -or $c -eq 'U') -and $i + 4 -le $n -and
            ((-join $chars[$i..($i + 3)]) -match '(?i)^url\(')) {
            $j = $i + 4
            while ($j -lt $n -and [char]::IsWhiteSpace($chars[$j])) { $j++ }
            if ($j -lt $n -and ($chars[$j] -eq [char]0x22 -or $chars[$j] -eq [char]0x27)) {
                # A quoted URL body may legally contain ')': url("icons/foo)#a")
                # Scan to the closing QUOTE first, then on to the paren.
                $q = $chars[$j]
                $j++
                while ($j -lt $n -and $chars[$j] -ne $q) {
                    if ($chars[$j] -eq [char]0x5C -and $j + 1 -lt $n) { $j++ }
                    $j++
                }
            }
            while ($j -lt $n -and $chars[$j] -ne ')') {
                # An unquoted URL may escape its closing paren: url(foo\)#id)
                if ($chars[$j] -eq [char]0x5C -and $j + 1 -lt $n) { $j++ }
                $j++
            }
            for ($k = $i + 4; $k -lt [Math]::Min($j, $n); $k++) { $chars[$k] = ' ' }
            $i = [Math]::Min($j + 1, $n)
            continue
        }

        $i++
    }

    $masked = -join $chars

    # --- Pass 2: one walk recording where a declaration value is open -------
    $ranges = [System.Collections.Generic.List[object]]::new()
    $blocks = New-Object System.Collections.Generic.Stack[bool]   # $true = at-rule block
    $valueStart = -1
    $valueBrace = 0     # braces opened INSIDE the value that is currently open
    $valueIsCustom = $false
    $preludeStart = 0   # where the current selector / at-rule prelude began
    for ($i = 0; $i -lt $n; $i++) {
        $c = $masked[$i]
        if ($c -eq '{') {
            # A custom property may legally carry a balanced block as its value:
            #   :root { --palette: {#ABCDEF}; fill: #000 }
            # Treating that brace as a rule boundary would close the declaration
            # and hide the color inside it.
            if ($valueStart -ge 0 -and $valueIsCustom) { $valueBrace++ }
            elseif ($valueStart -ge 0) {
                # A '{' arrived while a value looked open, and this is not a custom
                # property. CSS nesting: 'g { &:hover #A12345 { ... } }' - the colon
                # of ':hover' opened a value that was really a selector. Retract it,
                # or the id gets rewritten and the rule stops matching anything.
                $valueStart = -1
                $blocks.Push($false)
                $preludeStart = $i + 1
            }
            else {
                # Is this an at-rule block? '@media(...){ a:hover #ABC { } }' has
                # depth 1 while still in SELECTOR territory, so depth alone says
                # yes to the ':' of ':hover' and invents a declaration value.
                $prelude = $masked.Substring($preludeStart, $i - $preludeStart).TrimStart()
                # Not every at-rule is a grouping at-rule. @font-face, @property,
                # @page and friends hold DECLARATIONS, so a color in
                # '@property --brand{initial-value:#0078D4}' is a real color.
                $isGroupingAtRule = $prelude.StartsWith('@') -and
                    ($prelude -notmatch '(?i)^@(font-face|page|property|counter-style|font-palette-values|viewport)')
                $blocks.Push($isGroupingAtRule)
                $preludeStart = $i + 1
            }
        }
        elseif ($c -eq '}') {
            if ($valueBrace -gt 0) { $valueBrace-- }
            else {
                if ($valueStart -ge 0) { $ranges.Add(@($valueStart, $i)); $valueStart = -1 }
                if ($blocks.Count -gt 0) { [void]$blocks.Pop() }
                $preludeStart = $i + 1
            }
        }
        elseif ($c -eq ';') {
            if ($valueStart -ge 0 -and $valueBrace -eq 0) { $ranges.Add(@($valueStart, $i)); $valueStart = -1 }
            if ($valueStart -lt 0) { $preludeStart = $i + 1 }
        }
        elseif ($c -eq ':' -and $valueStart -lt 0 -and
                $blocks.Count -gt 0 -and -not $blocks.Peek()) {
            # Only inside a declaration block, never inside an at-rule block and
            # never at depth 0 - both of those are selector territory.
            $valueStart = $i + 1
            # Remember whether this is a custom property: only those may legally
            # carry a braced value, so only those get to keep it (see '{' above).
            $nameEnd = $i - 1
            while ($nameEnd -ge 0 -and [char]::IsWhiteSpace($masked[$nameEnd])) { $nameEnd-- }
            $nameStart = $nameEnd
            while ($nameStart -ge 0 -and ($masked[$nameStart] -eq '-' -or
                   [char]::IsLetterOrDigit($masked[$nameStart]))) { $nameStart-- }
            $name = if ($nameEnd -ge $nameStart + 1) { $masked.Substring($nameStart + 1, $nameEnd - $nameStart) } else { '' }
            $valueIsCustom = $name.StartsWith('--')
        }
    }
    if ($valueStart -ge 0) { $ranges.Add(@($valueStart, $n)) }

    return @{ Masked = $masked; Ranges = $ranges }
}

function Get-ColorTokenMatch {
    <#
    .SYNOPSIS
      Every hex color token in the text, minus the ones that are fragment ids.
    .OUTPUTS
      System.Text.RegularExpressions.Match objects, in document order.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    # Each style block is masked and scanned ONCE, not re-scanned per token.
    # Lists, not '+=' on arrays: '+=' rebuilds the whole array every iteration,
    # which turns a minified icon with many tokens into a quadratic walk.
    $styleInfo = [System.Collections.Generic.List[object]]::new()
    foreach ($r in [regex]::Matches($Text, $script:StyleBlockPattern)) {
        # Group 1 is the CSS itself. Passing $r.Value would include the '<style ...>'
        # tag, and then the first rule's prelude starts with '<' instead of '@' -
        # which is exactly how an at-rule stops being recognised as one.
        $css = $r.Groups[1]
        $styleInfo.Add(@{ Start = $css.Index; End = ($css.Index + $css.Length); Info = (Get-CssValueRange -Css $css.Value) })
    }

    $refSpans = [System.Collections.Generic.List[object]]::new()
    foreach ($r in [regex]::Matches($Text, $script:NonPaintPattern)) {
        $refSpans.Add(@($r.Index, ($r.Index + $r.Length)))
    }
    foreach ($r in [regex]::Matches($Text, $script:FragmentRefPattern)) {
        # Parentheses required: PowerShell's comma binds tighter than +, so
        # @($a, $a + $b) parses as ($a, $a) + $b and yields THREE elements.
        # That silently made every span empty and excluded nothing.
        $refSpans.Add(@($r.Index, ($r.Index + $r.Length)))
    }

    $keep = [System.Collections.Generic.List[object]]::new()
    foreach ($m in [regex]::Matches($Text, $script:HexTokenPattern)) {
        $inside = $false
        foreach ($span in $refSpans) {
            if ($m.Index -ge $span[0] -and $m.Index -lt $span[1]) { $inside = $true; break }
        }

        if (-not $inside) {
            foreach ($block in $styleInfo) {
                if ($m.Index -ge $block.Start -and $m.Index -lt $block.End) {
                    $local = $m.Index - $block.Start
                    # Masked away (comment, string body, url body), or outside every
                    # declaration-value range: not a color either way.
                    if ($block.Info.Masked[$local] -ne '#') { $inside = $true }
                    else {
                        $inValue = $false
                        foreach ($range in $block.Info.Ranges) {
                            if ($local -ge $range[0] -and $local -lt $range[1]) { $inValue = $true; break }
                        }
                        if (-not $inValue) { $inside = $true }
                    }
                    break
                }
            }
        }

        if (-not $inside) { $keep.Add($m) }
    }
    # No leading comma: ',@()' returns an array CONTAINING an empty array, and the
    # caller then iterates one bogus element. Callers wrap with @() where they need
    # an array; a plain return unrolls correctly for both foreach and @().
    return $keep.ToArray()
}

# Color notations this tool can see but deliberately does NOT rewrite. Reported so
# the user knows they were left alone, instead of finding out in Power BI.
$script:UnsupportedPatterns = [ordered]@{
    'rgb()/rgba()' = '(?i)\brgba?\s*\('
    'currentColor' = '(?i)\bcurrentColor\b'
    # Both the attribute form (fill="red") and the inline-style form
    # (style="fill:red"). Still not a CSS parser: a <style> block is out of reach.
    # The denylist carries every CSS-wide and SVG paint keyword, plus a guard for
    # function calls: var(--brand) and context-fill are not named colors, and
    # reporting them makes the closing warning misleading.
    'named color'  = '(?i)(?<![A-Za-z0-9_-])(?:fill|stroke|stop-color|flood-color|lighting-color)\s*[:=]\s*["'']?\s*' +
                     '(?!none|inherit|initial|unset|revert|transparent|currentColor|context-fill|context-stroke|url\(|#)' +
                     '[A-Za-z][A-Za-z-]{2,}(?!\s*\()'
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

    # Prose is masked out first, exactly as it is for hex tokens. Otherwise the
    # word 'currentColor' in a <desc> makes the script warn that colors were left
    # unrewritten when none were.
    # A char array, not repeated Remove/Insert: strings are immutable, so masking
    # N regions of a large file that way allocates N whole copies of it.
    $paintChars = $Text.ToCharArray()
    foreach ($r in [regex]::Matches($Text, $script:NonPaintPattern)) {
        for ($k = $r.Index; $k -lt $r.Index + $r.Length; $k++) { $paintChars[$k] = ' ' }
    }
    $paint = -join $paintChars
    # Style blocks get the SAME masking hex detection uses. Otherwise 'rgb(' or
    # 'currentColor' written inside a CSS comment, a CSS string or a url() body
    # is counted as a color left unrewritten, and the closing warning is wrong.
    foreach ($r in [regex]::Matches($paint, $script:StyleBlockPattern)) {
        $css = $r.Groups[1]
        $info = Get-CssValueRange -Css $css.Value
        # Keep ONLY the declaration values. A selector is not paint, so
        # 'path[fill=red]{fill:#0078D4}' must not report a named color: nothing
        # was left unrewritten there.
        $keepChars = (' ' * $info.Masked.Length).ToCharArray()
        foreach ($range in $info.Ranges) {
            for ($k = $range[0]; $k -lt $range[1]; $k++) { $keepChars[$k] = $info.Masked[$k] }
        }
        # The property name sits just before its value and the pattern needs it,
        # so carry back the run of name characters preceding each range.
        foreach ($range in $info.Ranges) {
            $k = $range[0] - 1
            while ($k -ge 0 -and ($info.Masked[$k] -eq ':' -or [char]::IsLetter($info.Masked[$k]) -or
                                  $info.Masked[$k] -eq '-' -or [char]::IsWhiteSpace($info.Masked[$k]))) {
                $keepChars[$k] = $info.Masked[$k]
                if ($info.Masked[$k] -eq ':' -and $k -lt $range[0] - 1) { break }
                $k--
            }
        }
        $paint = $paint.Remove($css.Index, $css.Length).Insert($css.Index, (-join $keepChars))
    }

    $found = @{}
    foreach ($name in $script:UnsupportedPatterns.Keys) {
        $count = ([regex]::Matches($paint, $script:UnsupportedPatterns[$name])).Count
        if ($count -gt 0) { $found[$name] = $count }
    }
    return $found
}

function Get-SvgFile {
    <#
    .SYNOPSIS
      Every .svg in a folder, whatever the case of the extension.
    .DESCRIPTION
      Get-ChildItem -Filter '*.svg' is case-insensitive on Windows and case-
      SENSITIVE on Linux, where CI runs. An icon named ICON.SVG would simply not
      exist as far as the tool was concerned - reported as 0/0, never recolored.
    #>
    param([Parameter(Mandatory)][string]$Path)
    # -LiteralPath: a project folder called 'MyReport[1]' is a wildcard to
    # -Path, and the whole project silently reads as empty.
    return @(Get-ChildItem -LiteralPath $Path -File | Where-Object { $_.Extension -ieq '.svg' })
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

$script:Utf8NoBom   = New-Object System.Text.UTF8Encoding($false)
$script:Utf8WithBom = New-Object System.Text.UTF8Encoding($true)

function Get-FileEncodingKind {
    <#
    .SYNOPSIS
      Classify a file by its byte-order mark: Utf8Bom, Utf8NoBom, or Utf16.
    .DESCRIPTION
      Imposing one encoding on every file it touches is how this tool put a BOM
      into every icon in the first place. Reading the mark and writing the same
      one back means a recolor changes colors and nothing else.
    #>
    param([Parameter(Mandatory)][string]$Path)

    # The WHOLE file, not a sample. Icon SVGs are small, and a 512-byte window
    # both misses an invalid byte at offset 600 and can cut a codepoint in half,
    # which would fail a perfectly good UTF-8 file.
    $sample = [System.IO.File]::ReadAllBytes($Path)
    $read = $sample.Length
    $head = $sample

    $hasUtf8Bom = ($read -ge 3 -and $head[0] -eq 0xEF -and $head[1] -eq 0xBB -and $head[2] -eq 0xBF)
    if ($read -ge 2 -and (($head[0] -eq 0xFF -and $head[1] -eq 0xFE) -or ($head[0] -eq 0xFE -and $head[1] -eq 0xFF))) { return 'Utf16' }

    # The strict decode runs for BOM files too, BEFORE trusting the mark. A BOM
    # says what the author intended, not what the bytes are: EF BB BF followed by
    # a stray 0xE9 is still invalid UTF-8, and returning early on the mark would
    # let ReadAllText substitute a replacement character that the write makes
    # permanent.
    try {
        $strict = New-Object System.Text.UTF8Encoding($false, $true)
        # $sample[3..2] on a 3-byte file is a REVERSE slice, not an empty one: it
        # hands back bytes 3 and 2, and the stray 0xBF then fails the decode. A
        # file that is only a BOM is valid, empty UTF-8.
        $body = if (-not $hasUtf8Bom) { $sample }
                elseif ($sample.Length -gt 3) { $sample[3..($sample.Length - 1)] }
                else { [byte[]]@() }
        if ($body.Length -gt 0) { [void]$strict.GetString($body) }
    } catch {
        return 'Other'
    }

    if ($hasUtf8Bom) { return 'Utf8Bom' }

    # UTF-16 without a BOM still has to be caught, or ReadAllText decodes it as
    # UTF-8 and the file goes back out re-encoded. Two cheap signals: interleaved
    # NUL bytes, which ASCII-range UTF-16 is full of, and the XML declaration.
    if ($sample.Length -ge 4) {
        $probe = [Math]::Min($sample.Length, 512)
        $nulls = 0
        for ($b = 0; $b -lt $probe; $b++) { if ($sample[$b] -eq 0) { $nulls++ } }
        if (($nulls / $probe) -gt 0.2) { return 'Utf16' }
    }
    $ascii = [System.Text.Encoding]::ASCII.GetString($sample, 0, [Math]::Min($sample.Length, 512))
    if ($ascii -match '(?i)<\?xml[^>]*encoding\s*=\s*["'']utf-16') { return 'Utf16' }

    # An XML declaration naming anything other than UTF-8 means ReadAllText would
    # decode the file wrongly and WriteAllText would then save that damage.
    $declared = [regex]::Match($ascii, '(?i)<\?xml[^>]*encoding\s*=\s*["'']([^"'']+)')
    if ($declared.Success -and $declared.Groups[1].Value -notmatch '(?i)^utf-?8$') { return 'Other' }

    return 'Utf8NoBom'
}
