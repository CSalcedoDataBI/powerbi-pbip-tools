<#
.SYNOPSIS
  Make a generated dashboard work without internet by inlining Chart.js into it.

.DESCRIPTION
  template.html loads Chart.js from a CDN, so a dashboard opened on a plane, or
  on a corporate network that blocks CDNs, renders everything EXCEPT its charts.
  This replaces that <script src="..."> with the library itself, from the copy
  vendored in this repo.

  It is a separate step on purpose. The library is 200 KB of minified JavaScript
  and template.html is read and rewritten in full on every run: carrying the blob
  through that would be slow, and one wrong character would break every chart.
  Splicing it in afterwards is mechanical and cannot mis-transcribe.

  Idempotent: running it twice does nothing the second time.

.PARAMETER Path
  The generated .html file to make standalone.

.PARAMETER LibraryPath
  The Chart.js build to inline. Defaults to the copy vendored next to this script.

.EXAMPLE
  pwsh tools/dashboard/Inline-ChartJs.ps1 -Path ~/dashboards/contoso_2025.html
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [string]$LibraryPath
)

$ErrorActionPreference = 'Stop'

if (-not $LibraryPath) { $LibraryPath = Join-Path $PSScriptRoot 'vendor/chart.umd.min.js' }
foreach ($p in @($Path, $LibraryPath)) {
    if (-not (Test-Path -LiteralPath $p)) { Write-Error "Not found: $p"; exit 1 }
}

$marker = 'inlined by Inline-ChartJs.ps1'
$html = [System.IO.File]::ReadAllText($Path)

if ($html.Contains($marker)) {
    Write-Host "Already standalone: $([System.IO.Path]::GetFileName($Path))"
    exit 0
}

# The CDN tag is the marker to replace. Matching the URL rather than a special
# comment means a dashboard generated before this script existed converts too.
$cdnTag = '(?is)<script\s+src\s*=\s*["'']https?://[^"'']*chart[^"'']*\.js["'']\s*>\s*</script>'
$m = [regex]::Match($html, $cdnTag)
if (-not $m.Success) {
    Write-Error "No Chart.js CDN tag found in $Path - nothing to inline."
    exit 1
}

$lib = [System.IO.File]::ReadAllText($LibraryPath)
$version = ([regex]::Match($lib, 'version="([0-9][0-9.]*)"')).Groups[1].Value
if (-not $version) { $version = 'unknown' }

# Every dashboard produced from here on is itself a redistribution of Chart.js,
# so it has to carry the MIT notice - a bare "MIT" line would not satisfy the one
# condition the license sets. Missing license file is fatal, not a warning: the
# alternative is shipping someone else's code with the notice stripped.
$licensePath = Join-Path ([System.IO.Path]::GetDirectoryName($LibraryPath)) 'chart.js.LICENSE.txt'
if (-not (Test-Path -LiteralPath $licensePath)) {
    Write-Error "License not found next to the library: $licensePath"
    exit 1
}
$license = ([System.IO.File]::ReadAllText($licensePath)).Trim()

# A literal '</script' would end the tag early and break the page silently; a '*/'
# in the license would close the banner and spill its text into the JS. Chart.js
# and the MIT text have neither, but a future version bump might.
foreach ($check in @(@{ n = 'the library'; t = $lib }, @{ n = 'the license text'; t = $license })) {
    if ($check.t -match '(?i)</script') {
        Write-Error "$($check.n) contains a literal '</script' and cannot be inlined verbatim."
        exit 1
    }
}
if ($license.Contains('*/')) {
    Write-Error "The license text contains '*/' and would close the comment banner early."
    exit 1
}

$inline = @"
<script>
/*!
 * Chart.js v$version - bundled so this dashboard renders with no network access.
 * Source: https://www.chartjs.org/  -  https://github.com/chartjs/Chart.js
 *
$(($license -split "`n" | ForEach-Object { (' * ' + $_).TrimEnd() }) -join "`n")
 *
 * $marker
 */
$lib
</script>
"@

# Spliced by index, never with -replace: a minified bundle is full of '$', and
# -replace reads those in the replacement string as capture-group references.
$before = (Get-Item -LiteralPath $Path).Length
$out = $html.Remove($m.Index, $m.Length).Insert($m.Index, $inline)
[System.IO.File]::WriteAllText($Path, $out, (New-Object System.Text.UTF8Encoding($false)))
$after = (Get-Item -LiteralPath $Path).Length

Write-Host "Inlined Chart.js v$version into $([System.IO.Path]::GetFileName($Path))"
Write-Host ("  {0:N0} -> {1:N0} bytes. It now renders with no network access." -f $before, $after)
