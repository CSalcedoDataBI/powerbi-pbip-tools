param (
    [Parameter(Mandatory)][string]$PbipDir
)

# --- Locate all .Report folders (supports multiple reports in one project) ---
$reportDirs = Get-ChildItem $PbipDir -Filter "*.Report" -Directory
if (-not $reportDirs) { Write-Error "No .Report folder found in: $PbipDir"; exit 1 }

$hexRegex = [regex]::new('#[0-9A-Fa-f]{6}')
$processedReports = 0

foreach ($reportDir in $reportDirs) {
    $svgDir = Join-Path $reportDir.FullName "StaticResources\RegisteredResources"
    if (-not (Test-Path $svgDir)) {
        Write-Warning "RegisteredResources not found in: $($reportDir.FullName) - skipping."
        continue
    }

    $processedReports++

    # --- Scan SVGs for hex colors ---
    $files = Get-ChildItem $svgDir -Filter "*.svg"
    $colorCount = @{}

    foreach ($f in $files) {
        $text = [System.IO.File]::ReadAllText($f.FullName)
        $hexMatches = $hexRegex.Matches($text)
        $seen = @{}
        foreach ($m in $hexMatches) {
            $c = $m.Value.ToUpper()
            if (-not $seen.ContainsKey($c)) {
                $seen[$c] = $true
                if ($colorCount.ContainsKey($c)) { $colorCount[$c]++ }
                else { $colorCount[$c] = 1 }
            }
        }
    }

    # --- Output ---
    Write-Host "Report : $($reportDir.Name)"
    Write-Host "Folder : $svgDir"
    Write-Host "SVGs   : $($files.Count) scanned"
    Write-Host "Colors : $($colorCount.Count) unique hex colors found"
    Write-Host ""

    foreach ($kv in $colorCount.GetEnumerator() | Sort-Object Value -Descending) {
        Write-Host ("  {0}  ({1} files)" -f $kv.Key, $kv.Value)
    }
    Write-Host ""
}

# Same reason as recolor.ps1: a clean exit after scanning nothing is a false
# success, and this script is meant to be read by the next command in a pipeline.
if ($processedReports -eq 0) {
    Write-Error "No RegisteredResources folder found in any .Report under: $PbipDir"
    exit 1
}
