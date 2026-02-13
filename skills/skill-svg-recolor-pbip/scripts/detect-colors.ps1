param (
    [Parameter(Mandatory)][string]$PbipDir
)

# --- Locate RegisteredResources ---
$reportDir = Get-ChildItem $PbipDir -Filter "*.Report" -Directory | Select-Object -First 1
if (-not $reportDir) { Write-Error "No .Report folder found in: $PbipDir"; exit 1 }

$svgDir = Join-Path $reportDir.FullName "StaticResources\RegisteredResources"
if (-not (Test-Path $svgDir)) { Write-Error "Path not found: $svgDir"; exit 1 }

# --- Scan SVGs for hex colors ---
$files = Get-ChildItem $svgDir -Filter "*.svg"
$colorCount = @{}
$regex = [regex]::new('#[0-9A-Fa-f]{6}')

foreach ($f in $files) {
    $text = [System.IO.File]::ReadAllText($f.FullName)
    $matches = $regex.Matches($text)
    $seen = @{}
    foreach ($m in $matches) {
        $c = $m.Value.ToUpper()
        if (-not $seen.ContainsKey($c)) {
            $seen[$c] = $true
            if ($colorCount.ContainsKey($c)) { $colorCount[$c]++ }
            else { $colorCount[$c] = 1 }
        }
    }
}

# --- Output ---
Write-Host "Carpeta: $svgDir"
Write-Host "$($files.Count) SVGs escaneados"
Write-Host "Colores encontrados: $($colorCount.Count)"

foreach ($kv in $colorCount.GetEnumerator() | Sort-Object Value -Descending) {
    Write-Host ("  {0}  ({1} archivos)" -f $kv.Key, $kv.Value)
}
