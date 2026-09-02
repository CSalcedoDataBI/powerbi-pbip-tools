<#
.SYNOPSIS
  Finding SVGs that live inside files that are not SVGs.

.DESCRIPTION
  A Power BI project carries icons in three places, and only one of them is a
  folder of .svg files:

    1. StaticResources/RegisteredResources/*.svg   - loose files, handled by PbipIo
    2. a DAX measure returning "data:image/svg+xml;utf8,<svg ...>"  (*.tmdl)
    3. a base64 data URI pasted into a report visual                (visual.json)

  Cases 2 and 3 are why a user could recolor a project, be told "184/184", open
  Power BI and still see blue icons: those colors were never in the folder.

  This module answers one question - where, inside a host file, is there an SVG,
  and how is it encoded - and then puts the recolored payloads back exactly where
  they were. It deliberately knows nothing about what a color is; that is
  ColorTokens' job, and running it on the DECODED payload means every construct
  it already gets right (url(#id), CSS id selectors, 8-digit hex) is got right
  here too, rather than reimplemented against a percent-encoded string.

  What it will not do: touch a single byte outside a payload. A .tmdl file is
  the model. A bad substitution there does not spoil an icon, it stops the report
  from opening.
#>

# A double-quoted TMDL/DAX string literal, with "" as the escaped quote. Anything
# outside one of these is DAX logic - table names, operators, IF branches - and is
# never a candidate, however much it may look like a color.
$script:DaxLiteralPattern = '"(?:[^"]|"")*"'

# A JSON string value. Same idea: the payload always lives inside one.
$script:JsonStringPattern = '"(?:[^"\\]|\\.)*"'

# What marks a literal as carrying an SVG. Either an inline document or a data
# URI naming the type - both forms appear in the wild.
$script:SvgMarkerPattern = '(?i)<svg[\s>]|data:image/svg\+xml'

$script:Base64UriPattern = '(?i)data:image/svg\+xml[^,"]*;base64,(?<b64>[A-Za-z0-9+/=\s]+)'

function ConvertFrom-PercentHash {
    <#
    .SYNOPSIS
      Turn %23 back into '#' so ColorTokens can read the payload.
    .DESCRIPTION
      Inside a data URI a color is written %230078D4, because a bare '#' would
      start the fragment and truncate the URI.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    return $Text.Replace('%23', '#')
}

function ConvertTo-PercentHash {
    <#
    .SYNOPSIS
      Re-encode every '#' in a payload that arrived percent-encoded.
    .DESCRIPTION
      Every '#', not a remembered subset. An earlier version kept a per-character
      map of which hashes had been encoded, and it was wrong the moment a
      replacement changed the string's length: -To accepts 3, 4, 6 and 8-digit
      hex, so recoloring #0078D4 to #fff shifted every later index by three and
      the map re-encoded the wrong characters. Measured before the fix:

          url(%23grad)  ->  url(#grad)      the gradient reference, broken
          stroke='%230078D4' -> stroke='#fff'

      A bare '#' truncates the data URI at the fragment, so those icons stop
      rendering - the failure this whole scope exists to prevent.

      Encoding all of them is not a guess: in a URI a '#' cannot appear unescaped,
      so in a well-formed percent-encoded payload every '#' came from a %23. The
      one input where that does not hold - a payload mixing %23 with a raw '#' -
      is refused rather than normalised; see Get-SvgPayload.
    #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    return $Text.Replace('#', '%23')
}

function Get-SvgPayload {
    <#
    .SYNOPSIS
      Every SVG embedded in a host file, decoded and located.
    .DESCRIPTION
      Returns one object per payload with Index/Length into the ORIGINAL text,
      the decoded Svg, and how to put it back. Kind selects the host grammar:
      'Dax' for .tmdl, 'Visual' for visual.json.

      Ordered by Index, so a caller splicing back to front can walk the array in
      reverse and keep every earlier index valid.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][ValidateSet('Dax', 'Visual')][string]$Kind
    )

    $literalPattern = if ($Kind -eq 'Dax') { $script:DaxLiteralPattern } else { $script:JsonStringPattern }
    $out = [System.Collections.Generic.List[object]]::new()

    foreach ($lit in [regex]::Matches($Text, $literalPattern)) {
        if ($lit.Value -notmatch $script:SvgMarkerPattern) { continue }

        # Base64 first: a literal carrying one is entirely that URI, and the
        # percent path below would find nothing in it anyway.
        $b64 = [regex]::Match($lit.Value, $script:Base64UriPattern)
        if ($b64.Success) {
            $raw = $b64.Groups['b64'].Value
            $compact = ($raw -replace '\s', '')
            $svg = $null
            try {
                $bytes = [System.Convert]::FromBase64String($compact)
                $svg = [System.Text.Encoding]::UTF8.GetString($bytes)
            } catch { $svg = $null }
            # Not decodable, or decodes to something that is not an SVG: report
            # nothing rather than write back a re-encoded guess.
            if ($null -eq $svg -or $svg -notmatch '(?i)<svg[\s>]') { continue }

            $out.Add([pscustomobject]@{
                Index      = $lit.Index + $b64.Groups['b64'].Index
                Length     = $b64.Groups['b64'].Length
                Svg        = $svg
                NewSvg     = $svg
                Encoding   = 'Base64'
            })
            continue
        }

        # Plain or percent-encoded: the payload is the literal's body, quotes
        # excluded so a splice can never eat the delimiter.
        $body = $lit.Value.Substring(1, $lit.Value.Length - 2)
        $isPercent = $body.Contains('%23')

        # '%23' holds no '#' of its own, so any literal '#' left in the raw body
        # is a raw one. Mixed with %23 there is no way to tell, after an edit,
        # which hashes should go back escaped - and guessing either way breaks
        # something: a raw '#' truncates the data URI, an over-escaped one changes
        # a byte this tool promised not to touch. Report it and move on.
        if ($isPercent -and $body.Contains('#')) {
            Write-Warning ("Skipped an embedded SVG that mixes %23 with a raw '#': " +
                           "there is no unambiguous way to re-encode it after a change.")
            continue
        }

        $out.Add([pscustomobject]@{
            Index    = $lit.Index + 1
            Length   = $body.Length
            Svg      = (ConvertFrom-PercentHash -Text $body)
            NewSvg   = (ConvertFrom-PercentHash -Text $body)
            Encoding = if ($isPercent) { 'PercentEncoded' } else { 'Plain' }
        })
    }

    return @($out)
}

function Join-SvgPayload {
    <#
    .SYNOPSIS
      Put recolored payloads back into the host text they came from.
    .DESCRIPTION
      Each payload's NewSvg is re-encoded the way it arrived and spliced by index,
      back to front so earlier indexes stay valid. Payloads whose NewSvg is
      unchanged are skipped entirely - re-encoding an untouched base64 blob would
      rewrite it for nothing, and this tool changes colors and nothing else.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Payload
    )

    $out = $Text
    $ordered = @($Payload | Sort-Object Index)
    for ($i = $ordered.Count - 1; $i -ge 0; $i--) {
        $p = $ordered[$i]
        if ($p.NewSvg -eq $p.Svg) { continue }

        $encoded = switch ($p.Encoding) {
            'Base64' { [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($p.NewSvg)) }
            'PercentEncoded' { ConvertTo-PercentHash -Text $p.NewSvg }
            default { $p.NewSvg }
        }
        $out = $out.Remove($p.Index, $p.Length).Insert($p.Index, $encoded)
    }
    return $out
}

function Get-PayloadHostFile {
    <#
    .SYNOPSIS
      The .tmdl or visual.json files of a PBIP project that may carry an SVG.
    .DESCRIPTION
      -LiteralPath and an extension test rather than -Filter, for the same two
      reasons as Get-SvgFile: -Filter is case-sensitive on Linux, and a project
      folder named 'MyReport[1]' is a wildcard to -Path.
    #>
    param(
        [Parameter(Mandatory)][string]$PbipDir,
        [Parameter(Mandatory)][ValidateSet('Dax', 'Visual')][string]$Kind
    )

    if (-not (Test-Path -LiteralPath $PbipDir)) { return @() }

    if ($Kind -eq 'Dax') {
        $roots = @(Get-ChildItem -LiteralPath $PbipDir -Directory | Where-Object { $_.Name -like '*.SemanticModel' })
        $match = { param($f) $f.Extension -ieq '.tmdl' }
    } else {
        $roots = @(Get-ChildItem -LiteralPath $PbipDir -Directory | Where-Object { $_.Name -like '*.Report' })
        $match = { param($f) $f.Name -ieq 'visual.json' }
    }

    $files = [System.Collections.Generic.List[object]]::new()
    foreach ($root in $roots) {
        # A linked root would put writes outside the project, exactly as a linked
        # .Report would - and here the file at the other end is the model.
        if ($root.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Warning "Skipped (linked folder, writes would land outside the project): $($root.Name)"
            continue
        }
        foreach ($f in (Get-ChildItem -LiteralPath $root.FullName -Recurse -File)) {
            if (& $match $f) { $files.Add($f) }
        }
    }
    return @($files)
}

function Get-StandaloneColorLiteral {
    <#
    .SYNOPSIS
      Color literals in a DAX file that are a color and nothing else.
    .DESCRIPTION
      The dynamic-icon pattern splits the color out of the SVG:

          VAR Color = IF ( [Sales] >= [Target], "%230078D4", "%23D13438" )
          VAR Svg   = "data:image/svg+xml;utf8,<svg ... fill='" & Color & "'/>"

      Only the second literal carries an SVG, so only the second is a payload.
      Rewriting the first would mean deciding that any string in the model which
      happens to be a color feeds an icon - and it might be a hex the user shows
      in a tooltip. So they are not touched.

      They ARE reported, because staying quiet about them recreates the exact
      failure this scope exists to fix one level down: the run says it changed
      the file, the user opens Power BI, and the icon is still blue.

      Prose is excluded by construction: the literal must be the color and
      nothing else. "Brand primary is #0078D4" is a sentence, not a setting.

      Only spans outside the given payloads are considered, so a color already
      rewritten inside an SVG is never reported as missed.
    #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Payload
    )

    $found = [System.Collections.Generic.List[string]]::new()
    foreach ($lit in [regex]::Matches($Text, $script:DaxLiteralPattern)) {
        $inPayload = $false
        foreach ($p in $Payload) {
            if ($lit.Index -lt ($p.Index + $p.Length) -and ($lit.Index + $lit.Length) -gt $p.Index) {
                $inPayload = $true; break
            }
        }
        if ($inPayload) { continue }

        $body = $lit.Value.Substring(1, $lit.Value.Length - 2)
        $bare = $body -replace '%23', '#'
        if ($bare -match '^#(?:[0-9A-Fa-f]{8}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{4}|[0-9A-Fa-f]{3})$') {
            $found.Add($bare)
        }
    }
    return @($found)
}

Export-ModuleMember -Function Get-SvgPayload, Join-SvgPayload, Get-PayloadHostFile, Get-StandaloneColorLiteral
