param (
    [Parameter(Mandatory)][string]$PbipDir,
    [Parameter(Mandatory)][string]$To,
    [string[]]$From,
    [string[]]$Exclude,
    [switch]$Backup,
    [switch]$WhatIf
)

# --- Validate target color format ---
if ($To -notmatch '^#[0-9A-Fa-f]{6}$') {
    Write-Error "Invalid color format for -To: '$To'. Expected 6-digit hex, e.g. '#DC143C'."
    exit 1
}

# --- Validate source colors format (if provided) ---
if ($From) {
    foreach ($c in $From) {
        if ($c -notmatch '^#[0-9A-Fa-f]{6}$') {
            Write-Error "Invalid color format in -From: '$c'. Expected 6-digit hex, e.g. '#0078D4'."
            exit 1
        }
    }
}

# --- Locate all .Report folders (supports multiple reports in one project) ---
$reportDirs = Get-ChildItem $PbipDir -Filter "*.Report" -Directory
if (-not $reportDirs) { Write-Error "No .Report folder found in: $PbipDir"; exit 1 }

$toUpper = $To.ToUpper()
$totalChanged = 0
$totalFiles = 0

foreach ($reportDir in $reportDirs) {
    $svgDir = Join-Path $reportDir.FullName "StaticResources\RegisteredResources"
    if (-not (Test-Path $svgDir)) {
        Write-Warning "RegisteredResources not found in: $($reportDir.FullName) — skipping."
        continue
    }

    $files = Get-ChildItem $svgDir -Filter "*.svg"
    $totalFiles += $files.Count

    # --- Build set of colors to exclude ---
    $excludeSet = @{}
    if ($Exclude) { foreach ($e in $Exclude) { $excludeSet[$e.ToUpper()] = $true } }
    $excludeSet[$toUpper] = $true   # never replace the target color itself

    # --- Determine source colors ---
    $hexRegex = [regex]::new('#[0-9A-Fa-f]{6}')
    if ($From -and $From.Count -gt 0) {
        $sourceColors = $From | ForEach-Object { $_.ToUpper() } | Where-Object { -not $excludeSet.ContainsKey($_) }
    } else {
        $detected = @{}
        foreach ($f in $files) {
            $text = [System.IO.File]::ReadAllText($f.FullName)
            foreach ($m in $hexRegex.Matches($text)) {
                $c = $m.Value.ToUpper()
                if (-not $excludeSet.ContainsKey($c)) { $detected[$c] = $true }
            }
        }
        $sourceColors = $detected.Keys
        if ($sourceColors.Count -eq 0) {
            Write-Host "[$($reportDir.Name)] No colors to replace."
            continue
        }
        Write-Host "[$($reportDir.Name)] Auto-detected: $($sourceColors -join ', ')"
    }

    # --- Optional backup ---
    if ($Backup -and -not $WhatIf) {
        $backupDir = Join-Path $svgDir "_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Path $backupDir | Out-Null
        foreach ($f in $files) {
            Copy-Item $f.FullName -Destination $backupDir
        }
        Write-Host "[$($reportDir.Name)] Backup saved to: $backupDir"
    }

    # --- Replace colors ---
    $changed = 0
    foreach ($f in $files) {
        $content = [System.IO.File]::ReadAllText($f.FullName)
        $newContent = $content
        foreach ($color in $sourceColors) {
            $newContent = $newContent -ireplace [regex]::Escape($color), $To
        }
        if ($content -ne $newContent) {
            if ($WhatIf) {
                Write-Host "  [WhatIf] Would update: $($f.Name)"
            } else {
                [System.IO.File]::WriteAllText($f.FullName, $newContent, [System.Text.Encoding]::UTF8)
            }
            $changed++
        }
    }
    $totalChanged += $changed

    $action = if ($WhatIf) { "Would update" } else { "Updated" }
    Write-Host "[$($reportDir.Name)] $action $changed/$($files.Count) SVGs (-> $To)"
}

if ($WhatIf) {
    Write-Host ""
    Write-Host "[WhatIf] Total: $totalChanged/$totalFiles SVGs would be modified. No files were changed."
} else {
    Write-Host ""
    Write-Host "Done. Total: $totalChanged/$totalFiles SVGs updated (-> $To)"
}
