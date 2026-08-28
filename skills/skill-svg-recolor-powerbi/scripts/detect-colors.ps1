param (
    [Parameter(Mandatory)][string]$PbipDir
)

# --- Locate all .Report folders (supports multiple reports in one project) ---
$reportDirs = Get-ChildItem $PbipDir -Filter "*.Report" -Directory
if (-not $reportDirs) { Write-Error "No .Report folder found in: $PbipDir"; exit 1 }

$hexRegex = [regex]::new('#[0-9A-Fa-f]{6}')

foreach ($reportDir in $reportDirs) {
    $svgDir = Join-Path $reportDir.FullName "StaticResources\RegisteredResources"
    if (-not (Test-Path $svgDir)) {
        Write-Warning "RegisteredResources not found in: $($reportDir.FullName) - skipping."
        continue
    }

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
