param (
    [Parameter(Mandatory)][string]$PbipDir,
    [Parameter(Mandatory)][string]$To,
    [string[]]$From,
    [string[]]$Exclude
)

# --- Locate RegisteredResources ---
$reportDir = Get-ChildItem $PbipDir -Filter "*.Report" -Directory | Select-Object -First 1
if (-not $reportDir) { Write-Error "No .Report folder found in: $PbipDir"; exit 1 }

$svgDir = Join-Path $reportDir.FullName "StaticResources\RegisteredResources"
if (-not (Test-Path $svgDir)) { Write-Error "Path not found: $svgDir"; exit 1 }

$files = Get-ChildItem $svgDir -Filter "*.svg"
$toUpper = $To.ToUpper()

# --- Build set of colors to exclude ---
$excludeSet = @{}
if ($Exclude) { foreach ($e in $Exclude) { $excludeSet[$e.ToUpper()] = $true } }
$excludeSet[$toUpper] = $true   # never replace the target color itself

# --- Determine source colors ---
if ($From -and $From.Count -gt 0) {
    $sourceColors = $From | ForEach-Object { $_.ToUpper() } | Where-Object { -not $excludeSet.ContainsKey($_) }
} else {
    $regex = [regex]::new('#[0-9A-Fa-f]{6}')
    $detected = @{}
    foreach ($f in $files) {
        $text = [System.IO.File]::ReadAllText($f.FullName)
        foreach ($m in $regex.Matches($text)) {
            $c = $m.Value.ToUpper()
            if (-not $excludeSet.ContainsKey($c)) { $detected[$c] = $true }
        }
    }
    $sourceColors = $detected.Keys
    if ($sourceColors.Count -eq 0) {
        Write-Host "No hay colores para reemplazar."
        exit 0
    }
    Write-Host "Auto-detectados: $($sourceColors -join ', ')"
}

# --- Replace colors ---
$changed = 0
foreach ($f in $files) {
    $content2 = [System.IO.File]::ReadAllText($f.FullName)
    $newContent = $content2
    foreach ($color in $sourceColors) {
        $newContent = $newContent -ireplace [regex]::Escape($color), $To
    }
    if ($content2 -ne $newContent) {
        [System.IO.File]::WriteAllText($f.FullName, $newContent, [System.Text.Encoding]::UTF8)
        $changed++
    }
}

Write-Host "$changed/$($files.Count) SVGs actualizados (-> $To)"
