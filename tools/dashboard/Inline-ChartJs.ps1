<#
.SYNOPSIS
  Make a generated dashboard work without internet by inlining Chart.js into it.

.DESCRIPTION
  template.html loads Chart.js from a CDN, so a dashboard opened on a plane, or
  on a corporate network that blocks CDNs, renders nothing at all: the script
  dies on its first reference to Chart, taking the KPI cards and the title down
  with the charts. This replaces that <script src="..."> with the library
  itself, from the copy vendored in this repo, plus its MIT notice.

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
# Normalised once, so every later [System.IO.File] call sees the same absolute
# path. Test-Path resolves '~' and relative paths through the PowerShell provider;
# [System.IO.File] resolves them against the process working directory, and the
# two do not always agree - measured: ReadAllBytes('~/x') throws where Test-Path
# on the same string returns true. No test pins this, because I could not make
# the mismatch reproduce through the script's own invocation; it is here to
# remove the dependency on which of the two is doing the resolving.
$Path        = (Resolve-Path -LiteralPath $Path).ProviderPath
$LibraryPath = (Resolve-Path -LiteralPath $LibraryPath).ProviderPath

$marker = 'inlined by Inline-ChartJs.ps1'
# ReadAllText drops a BOM silently. This tool changes one script tag and nothing
# else, so a file that arrived with a BOM leaves with one.
$firstBytes = [System.IO.File]::ReadAllBytes($Path) | Select-Object -First 3
$hasBom = $firstBytes.Count -eq 3 -and
          $firstBytes[0] -eq 0xEF -and $firstBytes[1] -eq 0xBB -and $firstBytes[2] -eq 0xBF
$html = [System.IO.File]::ReadAllText($Path)

# The CDN tag is what gets replaced. Matching the URL rather than a special
# comment means a dashboard generated before this script existed converts too.
# src does not have to come first: the published Chart.js snippets carry defer,
# integrity and crossorigin, and requiring src to lead would silently convert
# nothing on a file that plainly loads Chart.js from a CDN.
#
# The filename is anchored to a path segment rather than matched as a substring.
# 'chart' anywhere in the URL would also claim highcharts.js and flowchart.js -
# deleting a dependency the page needs and injecting Chart.js in its place.
#
# Unquoted too, for the same reason the warning scan reads unquoted attributes:
# <script src=https://.../chart.umd.min.js></script> is valid HTML, and refusing
# to convert it would leave the page loading Chart.js from the network while the
# script reports there was nothing to inline.
$chartFile = '/chart(?:\.umd)?(?:\.min)?\.js'
$cdnTag = '(?is)<script\b[^>]*?\bsrc\s*=\s*(?:' +
          "[`"']https?://[^`"']*$chartFile(?:\?[^`"']*)?[`"']" + '|' +
          "https?://[^\s>`"']*$chartFile(?:\?[^\s>`"']*)?" + ')' +
          '[^>]*>\s*</script>'
$cdnTags = @([regex]::Matches($html, $cdnTag))
$hasMarker = $html.Contains($marker)

# "Already done" has to mean the file is in that state, not merely that the
# marker text appears somewhere in it. A dashboard carries arbitrary titles and
# data: if one happened to contain the marker string, trusting it on its own
# would report success over a file with no library and no license notice. So the
# marker only counts when the notice it is supposed to accompany is there too.
$noticeLine = 'The above copyright notice and this permission notice shall be included'
$hasNotice  = $html.Contains($noticeLine)
# Evidence that the library is actually embedded, not just that the file talks
# about it: the header this repo puts on the vendored bundle.
$hasBundle  = $html.Contains('/*! Chart.js v')

if ($hasMarker -and $hasNotice -and $hasBundle -and $cdnTags.Count -eq 0) {
    Write-Host "Already standalone: $([System.IO.Path]::GetFileName($Path))"
    exit 0
}
if ($hasMarker -and $cdnTags.Count -gt 0) {
    Write-Error ("$Path carries the marker but still loads Chart.js from a CDN. Either the " +
                 'conversion was interrupted, or the marker text came from the dashboard ' +
                 'content. Refusing to guess which.')
    exit 1
}
if ($hasMarker -and -not ($hasNotice -and $hasBundle)) {
    Write-Error ("$Path carries the marker but not the license notice and bundle that always " +
                 'go with it. Either it was edited after conversion, or the marker text came ' +
                 'from the dashboard content. Refusing to call it converted.')
    exit 1
}
if ($cdnTags.Count -eq 0) {
    Write-Error "No Chart.js CDN tag found in $Path - nothing to inline."
    exit 1
}

$lib = [System.IO.File]::ReadAllText($LibraryPath)
$version = ([regex]::Match($lib, 'version="([0-9][0-9.]*)"')).Groups[1].Value
if (-not $version) { $version = 'unknown' }

# Every dashboard produced from here on is itself a redistribution of Chart.js,
# so it has to carry the MIT notice - a bare "MIT" line would not satisfy the one
# condition the license sets. A missing license file is fatal, not a warning: the
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
foreach ($check in @(@{ n = 'The library'; t = $lib }, @{ n = 'The license text'; t = $license })) {
    if ($check.t -match '(?i)</script') {
        Write-Error "$($check.n) contains a literal '</script' and cannot be inlined verbatim."
        exit 1
    }
}
if ($license.Contains('*/')) {
    Write-Error "The license text contains '*/' and would close the comment banner early."
    exit 1
}

$banner = ($license -split "`n" | ForEach-Object { (' * ' + $_).TrimEnd() }) -join "`n"
$inline = @"
<script>
/*!
 * Chart.js v$version - bundled so this dashboard renders with no network access.
 * Source: https://www.chartjs.org/  -  https://github.com/chartjs/Chart.js
 *
$banner
 *
 * $marker
 */
$lib
</script>
"@

# Spliced by index, never with -replace: a minified bundle is full of '$', and
# -replace reads those in the replacement string as capture-group references.
# Back to front, so each edit leaves the earlier indexes valid. A second CDN tag
# would be a second network dependency for a library already embedded, so the
# extras are dropped rather than duplicated.
$before = (Get-Item -LiteralPath $Path).Length
$out = $html
for ($i = $cdnTags.Count - 1; $i -ge 0; $i--) {
    $m = $cdnTags[$i]
    $replacement = if ($i -eq 0) { $inline } else { '' }
    $out = $out.Remove($m.Index, $m.Length).Insert($m.Index, $replacement)
}
# Written beside the target and renamed over it, never straight into it. A write
# that dies halfway - disk full, the process killed - would otherwise leave the
# dashboard truncated with no copy to go back to.
$tmp = "$Path.inlining.tmp"
try {
    [System.IO.File]::WriteAllText($tmp, $out, (New-Object System.Text.UTF8Encoding($hasBom)))
    Move-Item -LiteralPath $tmp -Destination $Path -Force
} catch {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    throw
}
$after = (Get-Item -LiteralPath $Path).Length

Write-Host "Inlined Chart.js v$version into $([System.IO.Path]::GetFileName($Path))"
if ($cdnTags.Count -gt 1) {
    Write-Host "  Removed $($cdnTags.Count - 1) further Chart.js CDN tag(s) made redundant by it."
}
Write-Host ("  {0:N0} -> {1:N0} bytes." -f $before, $after)

# Removing the Chart.js tag is not the same as the file being offline: a dashboard
# may pull in something else. Report what is actually left rather than letting the
# caller infer a guarantee this script cannot make.
#
# The unquoted alternative is not pedantry: HTML allows <img src=https://...> and
# a scan that only understood quotes would print "no external references remain"
# over a file that still needs the network - the exact claim this exists to avoid.
#
# What this does NOT see, and the message therefore does not promise: a URL built
# or fetched by the page's own JavaScript. Reading that would mean interpreting
# the script, which is a different job from the one here.
# The URL is matched anywhere inside the attribute value, not only at its start:
# a srcset legitimately reads "local.png 1x, https://cdn/2x.png 2x", and anchoring
# to the start would miss the remote candidate. Over-reporting here is a warning
# the reader can dismiss; under-reporting is a false "no external references".
$attrRef = '(?is)<(?:script|link|img|iframe|video|audio|source|embed|object|track)\b[^>]*' +
           '\b(?:src|href|srcset|data|poster)\s*=\s*' +
           '(?:"[^"]*https?://[^"]*"|''[^'']*https?://[^'']*''|https?://[^\s>]+)'
$cssRef  = '(?i)(?:@import\s+(?:url\s*\(\s*)?["'']?https?://|url\s*\(\s*["'']?https?://)'
$remaining = @([regex]::Matches($out, $attrRef)) + @([regex]::Matches($out, $cssRef))
if ($remaining.Count -eq 0) {
    Write-Host '  No external references left in the markup or CSS.'
} else {
    Write-Host "  WARNING: $($remaining.Count) other external reference(s) remain, so it is not fully offline:"
    $remaining | Select-Object -First 5 | ForEach-Object { Write-Host "    $($_.Value.Trim())" }
}
