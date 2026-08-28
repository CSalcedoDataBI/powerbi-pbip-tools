<#
.SYNOPSIS
  Report every color used by the SVG icons of a Power BI PBIP project.

.DESCRIPTION
  Scans StaticResources/RegisteredResources in every .Report folder and reports
  the hex colors found, plus any color notation this tool does not rewrite.

.PARAMETER PbipDir
  Root of the PBIP project (the folder holding the .Report directories).

.PARAMETER PassThru
  Also emit the result as objects on the success stream, for scripting.
  Without it the script only prints the human-readable report.

.EXAMPLE
  .\detect-colors.ps1 -PbipDir "C:\MyProject"
  .\detect-colors.ps1 -PbipDir "C:\MyProject" -PassThru | Where-Object FileCount -gt 10
#>
param (
    [Parameter(Mandatory)][string]$PbipDir,
    [switch]$PassThru
)

. (Join-Path $PSScriptRoot 'ColorTokens.ps1')

# --- Locate all .Report folders (supports multiple reports in one project) ---
$reportDirs = Get-ChildItem $PbipDir -Filter "*.Report" -Directory
if (-not $reportDirs) { Write-Error "No .Report folder found in: $PbipDir"; exit 1 }

$processedReports = 0
$results = @()

foreach ($reportDir in $reportDirs) {
    $svgDir = Join-PbipPath -ReportDir $reportDir.FullName
    if (-not (Test-Path $svgDir)) {
        Write-Warning "RegisteredResources not found in: $($reportDir.FullName) - skipping."
        continue
    }

    $processedReports++

    # --- Scan SVGs for color tokens ---
    $allFiles = Get-SvgFile -Path $svgDir
    # Same as recolor.ps1: settle encoding before reading, so a UTF-16 file is
    # reported as skipped instead of scanned as garbage.
    $files = @()
    foreach ($f in $allFiles) {
        if ((Get-FileEncodingKind -Path $f.FullName) -in @('Utf16', 'Other')) {
            Write-Warning "  Skipped (not UTF-8): $($f.Name)"
            continue
        }
        $files += $f
    }
    $colorCount = @{}
    $unsupported = @{}
    $unsupportedFiles = @{}

    foreach ($f in $files) {
        $text = [System.IO.File]::ReadAllText($f.FullName)

        # Count each color once per file, so the number reads as "files using it".
        $seen = @{}
        foreach ($m in (Get-ColorTokenMatch -Text $text)) {
            $c = Get-CanonicalHex -Token $m.Value
            if (-not $seen.ContainsKey($c)) {
                $seen[$c] = $true
                if ($colorCount.ContainsKey($c)) { $colorCount[$c]++ } else { $colorCount[$c] = 1 }
            }
        }

        foreach ($kv in (Get-UnsupportedNotation -Text $text).GetEnumerator()) {
            if ($unsupported.ContainsKey($kv.Key)) { $unsupported[$kv.Key] += $kv.Value }
            else { $unsupported[$kv.Key] = $kv.Value }
            if (-not $unsupportedFiles.ContainsKey($kv.Key)) { $unsupportedFiles[$kv.Key] = @() }
            $unsupportedFiles[$kv.Key] += $f.Name
        }
    }

    # --- Output ---
    Write-Host "Report : $($reportDir.Name)"
    Write-Host "Folder : $svgDir"
    Write-Host "SVGs   : $($files.Count) scanned ($($allFiles.Count) found)"
    Write-Host "Colors : $($colorCount.Count) unique hex colors found"
    Write-Host ""

    foreach ($kv in $colorCount.GetEnumerator() | Sort-Object Value -Descending) {
        Write-Host ("  {0}  ({1} files)" -f $kv.Key, $kv.Value)
        $results += [pscustomobject]@{
            Report    = $reportDir.Name
            Color     = $kv.Key
            FileCount = $kv.Value
        }
    }

    # Colors this tool will not rewrite. Saying so here is the whole point: the
    # alternative is the user running recolor, reading "184/184 updated", and
    # finding untouched icons in Power BI with nothing to explain why.
    if ($unsupported.Count -gt 0) {
        Write-Host ""
        Write-Host "  Not rewritable by recolor.ps1 (reported only):"
        foreach ($kv in $unsupported.GetEnumerator() | Sort-Object Value -Descending) {
            $where = @($unsupportedFiles[$kv.Key] | Sort-Object -Unique)
            # Naming the files is the point: recolor.ps1 tells the user to come
            # here to find out WHICH icons kept their color, so an aggregate
            # count would make that instruction a dead end.
            $shown = if ($where.Count -gt 4) { ($where[0..3] -join ', ') + ", +$($where.Count - 4) more" }
                     else { $where -join ', ' }
            Write-Host ("    {0}  ({1} occurrences in {2} file(s): {3})" -f $kv.Key, $kv.Value, $where.Count, $shown)
        }
    }
    Write-Host ""
}

# Every .Report was skipped for lack of RegisteredResources: nothing was even
# looked at. Exiting 0 here would read as success to a human and to a caller.
if ($processedReports -eq 0) {
    Write-Error "No RegisteredResources folder found in any .Report under: $PbipDir"
    exit 1
}

# Objects go to the success stream so a caller can consume them without parsing
# the printed report. The report itself stays where Write-Host puts it, on the
# information stream - capturable with 6>&1, though not with 2>&1.
if ($PassThru) { $results }
