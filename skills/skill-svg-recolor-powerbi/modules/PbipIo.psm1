<#
.SYNOPSIS
  Locating and classifying files inside a PBIP project, without changing them.

.DESCRIPTION
  Split out of ColorTokens, where these lived only because it was the one shared
  file that existed. Nothing here knows what a color is: it answers where the
  SVGs are and how a file is encoded, which is the same question whether the
  caller is recoloring, auditing, or doing something not yet written.

  A module, not a dot-sourced script - see ColorTokens.psm1 for why.
#>

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

function Get-Utf8Encoding {
    <#
    .SYNOPSIS
      The UTF8Encoding matching a kind returned by Get-FileEncodingKind.
    .DESCRIPTION
      A function rather than the two module-level variables it replaces. Those
      reached callers only because dot-sourcing leaked them; under Import-Module
      they would simply not exist there, and a caller reaching for $Utf8NoBom
      would get $null and write with whatever the default encoding is - on
      Windows PowerShell 5.1 that is UTF-16, i.e. every icon corrupted. A
      function fails loudly instead: an unknown kind is a parameter error.
    #>
    param([Parameter(Mandatory)][ValidateSet('Utf8Bom', 'Utf8NoBom')][string]$Kind)
    return (New-Object System.Text.UTF8Encoding($Kind -eq 'Utf8Bom'))
}

function Get-BackupPath {
    <#
    .SYNOPSIS
      A backup directory name that two runs in the same second cannot share.
    .DESCRIPTION
      The timestamp alone was not enough. Two invocations landing in the same
      second produced the same path, New-Item threw "already exists", and the
      run stopped with "Backup failed - NOTHING has been modified yet". Measured:
      on a fast machine (Linux CI) a test loop recoloring two fixtures back to
      back hit it every time; on a slower one it never did, which is exactly how
      a defect like this survives.

      The fix is a short random suffix, not New-Item -Force: -Force would reuse
      the existing directory and quietly mix two different runs' backups into
      one folder, which is worse than failing - the user would restore a mixture.
    #>
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Name
    )
    $stamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    # El GUID entero, no un prefijo. Seis caracteres son 24 bits: bastan para
    # que dos corridas casi nunca choquen, y 'casi nunca' es la misma clase de
    # respuesta que dio el timestamp por segundo. Un nombre largo en la carpeta
    # temporal no le cuesta nada a nadie.
    $unique = [guid]::NewGuid().ToString('N')
    return (Join-Path $Root "pbip-recolor-backup_${Name}_${stamp}_${unique}")
}

Export-ModuleMember -Function Get-SvgFile, Join-PbipPath, Get-FileEncodingKind, Get-Utf8Encoding, Get-BackupPath
