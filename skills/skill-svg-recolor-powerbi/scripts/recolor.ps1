<#
.SYNOPSIS
  Batch-recolor the SVG icons of a Power BI PBIP project.

.DESCRIPTION
  Rewrites hex colors in StaticResources/RegisteredResources across every
  .Report folder. Replacement is token-wise: each color token in the file is
  matched whole and compared by canonical value, so a 6-digit color can never
  eat the first six digits of an 8-digit one.

.PARAMETER PbipDir
  Root of the PBIP project.

.PARAMETER To
  Target color. Any of #RGB, #RGBA, #RRGGBB, #RRGGBBAA.

.PARAMETER From
  Source colors. Omit to recolor every color found.

.PARAMETER Exclude
  Colors to leave alone.

.PARAMETER Backup
  Copy the originals before writing. Backups go OUTSIDE the PBIP project.

.PARAMETER BackupRoot
  Where -Backup writes. Defaults to the system temp directory, deliberately not
  inside the project: a backup under RegisteredResources gets committed by
  accident and would become an input to a future recursive scan.

.PARAMETER WhatIf
  Dry run: list what would change and write nothing.

.EXAMPLE
  .\recolor.ps1 -PbipDir ".\MyProject" -To "#DC143C" -WhatIf
  .\recolor.ps1 -PbipDir ".\MyProject" -From "#0078D4" -To "#DC143C" -Backup
#>
param (
    [Parameter(Mandatory)][string]$PbipDir,
    [Parameter(Mandatory)][string]$To,
    [string[]]$From,
    [string[]]$Exclude,
    [switch]$Backup,
    [string]$BackupRoot,
    [switch]$WhatIf,
    # Default 'Resources' on purpose: every existing invocation keeps meaning
    # exactly what it meant. Widening the default would have silently started
    # writing to .tmdl for people who only ever asked about icons.
    [ValidateSet('Resources', 'Dax', 'Visuals', 'All')][string]$Scope = 'Resources'
)

# Import-Module, not dot-sourcing: the patterns and encodings stay inside the
# modules instead of landing in this script's scope, where a host runspace could
# collide with them. -Force so an edited module is picked up in the same session.
$moduleDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'modules'
Import-Module (Join-Path $moduleDir 'ColorTokens.psm1') -Force
Import-Module (Join-Path $moduleDir 'PbipIo.psm1') -Force
Import-Module (Join-Path $moduleDir 'SvgPayload.psm1') -Force

# --- Validate color arguments ---
if (-not (Test-HexColor -Value $To)) {
    Write-Error "Invalid color format for -To: '$To'. Expected hex, e.g. '#DC143C'."
    exit 1
}
# Two plain loops, deliberately not one clever loop over name/value pairs.
# @('From', $From) does not iterate the way it reads: $c ends up bound to the
# whole array stringified, so '-From "#0078D4","#FFFFFF"' - the documented way to
# pass several colors - was rejected as invalid.
foreach ($c in $From) {
    if (-not (Test-HexColor -Value $c)) {
        Write-Error "Invalid color format in -From: '$c'. Expected hex, e.g. '#0078D4'."
        exit 1
    }
}
# -Exclude is validated too: one that silently fails to match is a color the
# user believed was protected and was not.
foreach ($c in $Exclude) {
    if (-not (Test-HexColor -Value $c)) {
        Write-Error "Invalid color format in -Exclude: '$c'. Expected hex, e.g. '#FFFFFF'."
        exit 1
    }
}

# --- What this run is allowed to touch ---
$doResources = $Scope -in @('Resources', 'All')
$doDax       = $Scope -in @('Dax', 'All')
$doVisuals   = $Scope -in @('Visuals', 'All')

# A .tmdl file is not an icon, it is the model. A bad substitution in an .svg
# spoils a picture; the same mistake here stops the report from opening. So the
# net is not optional: either preview it, or have a copy on disk first.
if ($doDax -and -not $WhatIf -and -not $Backup) {
    Write-Error ("-Scope $Scope writes to .tmdl files, which are the semantic model itself. " +
                 "Re-run with -WhatIf to see what would change, or with -Backup to keep a copy. " +
                 "Nothing has been modified.")
    exit 1
}

# --- Locate all .Report folders (supports multiple reports in one project) ---
# -LiteralPath throughout: brackets in a folder name are wildcards to -Path.
$reportDirs = if ($doResources) { @(Get-ChildItem -LiteralPath $PbipDir -Filter "*.Report" -Directory) } else { @() }
if ($doResources -and -not $reportDirs) { Write-Error "No .Report folder found in: $PbipDir"; exit 1 }

if (-not $BackupRoot) { $BackupRoot = [System.IO.Path]::GetTempPath() }

$toCanonical  = Get-CanonicalHex -Token $To
$totalChanged = 0
$totalFiles = 0
$processedReports = 0
$writeFailures = 0
$standaloneColors = @{}
$standaloneFiles  = @{}
$payloadFilesChanged = 0
$payloadFilesSeen    = 0
$payloadColorsChanged = 0
$unsupportedSeen = @{}
$scannedForUnsupported = @{}
$filesWithUnsupported = @{}

# Two passes on purpose. Everything that can refuse - discovery, encoding,
# and every requested backup - happens for ALL reports before the first byte is
# written. Doing the backup inside the write loop meant report A could be
# recolored and report B's backup then fail, leaving the project half-changed
# with the run reporting a backup failure.
$plan = [System.Collections.Generic.List[object]]::new()

foreach ($reportDir in $reportDirs) {
    # The file-level link guard below is not enough on its own: a JUNCTION named
    # 'External.Report' inside the project points at a folder elsewhere, and the
    # SVGs it contains are ordinary files - not reparse points - so every one of
    # them would be rewritten outside the project.
    if ($reportDir.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        Write-Warning "Skipped (linked .Report, writes would land outside the project): $($reportDir.Name)"
        continue
    }

    $svgDir = Join-PbipPath -ReportDir $reportDir.FullName
    if (-not (Test-Path -LiteralPath $svgDir)) {
        Write-Warning "RegisteredResources not found in: $($reportDir.FullName) - skipping."
        continue
    }

    $processedReports++
    $allFiles = Get-SvgFile -Path $svgDir
    $totalFiles += $allFiles.Count

    # Encoding is settled ONCE, before anything reads a byte. Doing it later meant
    # a BOM-less UTF-16 file was scanned as UTF-8 garbage, reported "no colors",
    # and skipped by the early exit before its warning could ever print.
    $files = @()
    $encodingOf = @{}
    foreach ($f in $allFiles) {
        # A symlink or junction inside RegisteredResources points somewhere this
        # tool never promised to touch, and WriteAllText follows it: the write
        # lands outside the project while the run reports 1/1 modified. Reading
        # through one is harmless, so detect-colors still does; writing is not.
        if ($f.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Warning "  Skipped (link, writes would land outside the project): $($f.Name)"
            continue
        }

        $kind = Get-FileEncodingKind -Path $f.FullName
        if ($kind -eq 'Utf16' -or $kind -eq 'Other') {
            Write-Warning "  Skipped (not UTF-8, would be re-encoded): $($f.Name)"
            continue
        }
        $encodingOf[$f.FullName] = $kind
        $files += $f
    }

    # --- Build the set of colors to leave alone ---
    $excludeSet = @{}
    foreach ($e in $Exclude) { $excludeSet[(Get-CanonicalHex -Token $e)] = $true }
    $excludeSet[$toCanonical] = $true   # never replace the target color itself

    # --- Determine source colors (canonical, so #FFF and #FFFFFF are one color) ---
    if ($From -and $From.Count -gt 0) {
        $sourceSet = @{}
        foreach ($c in $From) {
            $canonical = Get-CanonicalHex -Token $c
            if (-not $excludeSet.ContainsKey($canonical)) { $sourceSet[$canonical] = $true }
        }
    } else {
        $sourceSet = @{}
        foreach ($f in $files) {
            $text = [System.IO.File]::ReadAllText($f.FullName)
            foreach ($m in (Get-ColorTokenMatch -Text $text)) {
                $canonical = Get-CanonicalHex -Token $m.Value
                if (-not $excludeSet.ContainsKey($canonical)) { $sourceSet[$canonical] = $true }
            }
            # Collected BEFORE the early exit below. A report whose colors are all
            # rgb() or currentColor has nothing to rewrite - and that is precisely
            # when the user most needs to be told why nothing happened.
            foreach ($kv in (Get-UnsupportedNotation -Text $text).GetEnumerator()) {
                if ($unsupportedSeen.ContainsKey($kv.Key)) { $unsupportedSeen[$kv.Key] += $kv.Value }
                else { $unsupportedSeen[$kv.Key] = $kv.Value }
                $filesWithUnsupported[$f.FullName] = $true
            }
            $scannedForUnsupported[$f.FullName] = $true
        }
        if ($sourceSet.Count -eq 0) {
            Write-Host "[$($reportDir.Name)] No colors to replace."
            continue
        }
        Write-Host "[$($reportDir.Name)] Auto-detected: $(($sourceSet.Keys | Sort-Object) -join ', ')"
    }

    # --- Optional backup ---
    if ($Backup -and -not $WhatIf) {
        $backupDir = Join-Path $BackupRoot "pbip-recolor-backup_$($reportDir.Name)_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        # Fatal on purpose. This script rewrites the user's files in place, and
        # New-Item / Copy-Item only raise non-terminating errors by default: a
        # backup that quietly failed would let the loop below overwrite the
        # originals anyway. That is worse than having no -Backup at all, because
        # the user asked for a net and would proceed believing they had one.
        try {
            New-Item -ItemType Directory -Path $backupDir -ErrorAction Stop | Out-Null
            foreach ($f in $files) {
                Copy-Item -LiteralPath $f.FullName -Destination $backupDir -ErrorAction Stop
            }
        } catch {
            Write-Error "[$($reportDir.Name)] Backup failed - NOTHING has been modified yet, in any report. $($_.Exception.Message)"
            exit 1
        }
        Write-Host "[$($reportDir.Name)] Backup saved to: $backupDir"
    }

    # AllFileCount travels WITH the entry. $allFiles belongs to pass 1; reading
    # it in pass 2 gets whatever the LAST report left in it, so every report
    # printed the last one's denominator.
    $plan.Add(@{ Report = $reportDir; Files = $files; EncodingOf = $encodingOf
                 SourceSet = $sourceSet; AllFileCount = $allFiles.Count })
}

# ---- Payloads: SVGs that live inside .tmdl and visual.json --------------------
# Same two-pass discipline as above. Discovery and backup for every host file
# happen here, before pass 2 writes its first byte, so a project can never end up
# with the icons recolored and the model's backup having failed.
$payloadPlan = [System.Collections.Generic.List[object]]::new()
$payloadKinds = @()
if ($doDax)     { $payloadKinds += 'Dax' }
if ($doVisuals) { $payloadKinds += 'Visual' }

foreach ($kind in $payloadKinds) {
    foreach ($hostFile in (Get-PayloadHostFile -PbipDir $PbipDir -Kind $kind)) {
        if ($hostFile.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Warning "  Skipped (link, writes would land outside the project): $($hostFile.Name)"
            continue
        }
        $encKind = Get-FileEncodingKind -Path $hostFile.FullName
        if ($encKind -eq 'Utf16' -or $encKind -eq 'Other') {
            Write-Warning "  Skipped (not UTF-8, would be re-encoded): $($hostFile.Name)"
            continue
        }

        $text = [System.IO.File]::ReadAllText($hostFile.FullName)
        $payloads = @(Get-SvgPayload -Text $text -Kind $kind)
        if ($payloads.Count -eq 0) { continue }

        $payloadFilesSeen++
        # Colors that sit in their own literal next to an SVG payload: the
        # dynamic-icon pattern. Not rewritten - see Get-StandaloneColorLiteral -
        # but named at the end, because a run that changed the file and left the
        # icon blue is the failure this scope was added to remove.
        if ($kind -eq 'Dax') {
            foreach ($c in (Get-StandaloneColorLiteral -Text $text -Payload $payloads)) {
                $standaloneColors[$c] = $true
                $standaloneFiles[$hostFile.FullName] = $true
            }
        }
        $payloadPlan.Add(@{ File = $hostFile; Kind = $kind; EncodingKind = $encKind
                            Text = $text; Payloads = $payloads })
    }
}

# Which colors to replace inside payloads. Computed here, over the payloads
# themselves, rather than reusing a report's set: an embedded SVG can carry a
# color that appears in no loose .svg at all - that is the whole point of #13 -
# and inheriting the folder's set would leave exactly those untouched.
$payloadExclude = @{}
foreach ($e in $Exclude) { $payloadExclude[(Get-CanonicalHex -Token $e)] = $true }
$payloadExclude[$toCanonical] = $true
$payloadSourceSet = @{}
if ($From -and $From.Count -gt 0) {
    foreach ($c in $From) {
        $canonical = Get-CanonicalHex -Token $c
        if (-not $payloadExclude.ContainsKey($canonical)) { $payloadSourceSet[$canonical] = $true }
    }
} else {
    foreach ($entry in $payloadPlan) {
        foreach ($payload in $entry.Payloads) {
            foreach ($m in (Get-ColorTokenMatch -Text $payload.Svg)) {
                $canonical = Get-CanonicalHex -Token $m.Value
                if (-not $payloadExclude.ContainsKey($canonical)) { $payloadSourceSet[$canonical] = $true }
            }
        }
    }
    if ($payloadPlan.Count -gt 0 -and $payloadSourceSet.Count -gt 0) {
        Write-Host "[embedded] Auto-detected: $(($payloadSourceSet.Keys | Sort-Object) -join ', ')"
    }
}

if ($payloadPlan.Count -gt 0 -and $Backup -and -not $WhatIf) {
    $payloadBackup = Join-Path $BackupRoot "pbip-recolor-backup_payloads_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    try {
        New-Item -ItemType Directory -Path $payloadBackup -ErrorAction Stop | Out-Null
        foreach ($entry in $payloadPlan) {
            # Flattened with the source folder in the name: visual.json is the same
            # file name in every visual, and Copy-Item would overwrite the previous
            # one, leaving a "backup" holding a single file out of nine.
            $rel = $entry.File.FullName.Substring($PbipDir.Length).TrimStart('\', '/')
            $safe = ($rel -replace '[\\/]', '__')
            Copy-Item -LiteralPath $entry.File.FullName -Destination (Join-Path $payloadBackup $safe) -ErrorAction Stop
        }
    } catch {
        Write-Error "Backup of embedded-SVG files failed - NOTHING has been modified yet. $($_.Exception.Message)"
        exit 1
    }
    Write-Host "Backup of $($payloadPlan.Count) embedded-SVG file(s) saved to: $payloadBackup"
}

# ---- Pass 2: nothing below here can refuse; every backup is already on disk --
foreach ($entry in $plan) {
    $reportDir = $entry.Report
    $files     = $entry.Files
    $encodingOf = $entry.EncodingOf
    $sourceSet = $entry.SourceSet

    $changed = 0
    foreach ($f in $files) {
        $content = [System.IO.File]::ReadAllText($f.FullName)

        # Token-wise, never a blind substring replace: each match is a complete
        # color token, compared by canonical value and swapped whole. That is what
        # keeps #RRGGBBAA from being rewritten as a 6-digit color plus a stray
        # alpha, and what lets #FFF be recognised as #FFFFFF.
        # Rebuilt from the right-hand side so earlier match indexes stay valid.
        # Only tokens Get-ColorTokenMatch returned are candidates, so a hex-looking
        # fragment id inside url(...) or href="..." is never one of them.
        $newContent = $content
        $candidates = @(Get-ColorTokenMatch -Text $content)
        for ($i = $candidates.Count - 1; $i -ge 0; $i--) {
            $m = $candidates[$i]
            if ($sourceSet.ContainsKey((Get-CanonicalHex -Token $m.Value))) {
                $newContent = $newContent.Remove($m.Index, $m.Length).Insert($m.Index, $To)
            }
        }

        if (-not $scannedForUnsupported.ContainsKey($f.FullName)) {
            foreach ($kv in (Get-UnsupportedNotation -Text $content).GetEnumerator()) {
                if ($unsupportedSeen.ContainsKey($kv.Key)) { $unsupportedSeen[$kv.Key] += $kv.Value }
                else { $unsupportedSeen[$kv.Key] = $kv.Value }
                $filesWithUnsupported[$f.FullName] = $true
            }
        }

        if ($content -ne $newContent) {
            if ($WhatIf) {
                Write-Host "  [WhatIf] Would modify: $($f.Name)"
            } else {
                # Write back the SAME encoding the file arrived in.
                # [System.Text.Encoding]::UTF8 always prepends a BOM, which is how
                # every icon this tool touched ended up with one.
                $encoding = Get-Utf8Encoding -Kind $encodingOf[$f.FullName]
                try {
                    [System.IO.File]::WriteAllText($f.FullName, $newContent, $encoding)
                } catch {
                    # A read-only or locked file used to throw here, be printed as a
                    # loose error, and STILL be counted as modified - the run then
                    # reported 3/3 and exited 0 having changed two files.
                    Write-Warning "  Could not write $($f.Name): $($_.Exception.Message)"
                    $writeFailures++
                    continue
                }
            }
            $changed++
        }
    }
    $totalChanged += $changed

    # Same word as the summary: this counts files MODIFIED, not files that came
    # out fully recolored.
    $action = if ($WhatIf) { "Would modify" } else { "Modified" }
    Write-Host "[$($reportDir.Name)] $action $changed/$($entry.AllFileCount) SVGs (-> $To)"
}

foreach ($entry in $payloadPlan) {
    $text = $entry.Text
    $changedHere = 0

    foreach ($payload in $entry.Payloads) {
        # ColorTokens runs on the DECODED SVG, so url(#id), CSS id selectors and
        # 8-digit hex are judged by the same code that judges a loose .svg - not
        # by a second, weaker rule written against a percent-encoded string.
        $svg = $payload.Svg
        $newSvg = $svg
        $candidates = @(Get-ColorTokenMatch -Text $svg)
        for ($i = $candidates.Count - 1; $i -ge 0; $i--) {
            $m = $candidates[$i]
            $canonical = Get-CanonicalHex -Token $m.Value
            if ($payloadSourceSet.ContainsKey($canonical)) {
                $newSvg = $newSvg.Remove($m.Index, $m.Length).Insert($m.Index, $To)
                $changedHere++
            }
        }
        $payload.NewSvg = $newSvg

        foreach ($kv in (Get-UnsupportedNotation -Text $svg).GetEnumerator()) {
            if ($unsupportedSeen.ContainsKey($kv.Key)) { $unsupportedSeen[$kv.Key] += $kv.Value }
            else { $unsupportedSeen[$kv.Key] = $kv.Value }
            $filesWithUnsupported[$entry.File.FullName] = $true
        }
    }

    if ($changedHere -eq 0) { continue }

    $newText = Join-SvgPayload -Text $text -Payload $entry.Payloads
    if ($newText -eq $text) { continue }

    $label = if ($entry.Kind -eq 'Dax') { 'DAX' } else { 'visual' }
    if ($WhatIf) {
        Write-Host "  [WhatIf] Would modify ($label): $($entry.File.Name) - $changedHere color(s)"
    } else {
        try {
            [System.IO.File]::WriteAllText($entry.File.FullName, $newText, (Get-Utf8Encoding -Kind $entry.EncodingKind))
        } catch {
            Write-Warning "  Could not write $($entry.File.Name): $($_.Exception.Message)"
            $writeFailures++
            continue
        }
        Write-Host "  Modified ($label): $($entry.File.Name) - $changedHere color(s)"
    }
    $payloadFilesChanged++
    $payloadColorsChanged += $changedHere
}

# Every .Report was skipped for lack of RegisteredResources: nothing was even
# looked at. Exiting 0 with "0/0 SVGs updated" reads as success to a human and
# to any script calling this one.
if ($doResources -and $processedReports -eq 0) {
    Write-Error "No RegisteredResources folder found in any .Report under: $PbipDir"
    exit 1
}

Write-Host ""
if ($WhatIf) {
    Write-Host "[WhatIf] Total: $totalChanged/$totalFiles SVGs would be modified. No files were changed."
} else {
    # "updated" would read as "fully recolored". This counts files this run
    # MODIFIED; a file can be modified and still hold a color this tool does
    # not rewrite, which the warning below then names.
    Write-Host "Done. Total: $totalChanged/$totalFiles SVGs modified (-> $To)"
}

# Say out loud what was left behind. Reporting "184/184 updated" while icons keep
# their old color because they use rgb() or currentColor is the failure this warns
# about - the user would otherwise find out by opening Power BI.
# A failed write is not a smaller success. Saying so in the exit code matters
# most for the caller that never reads the output.
if ($writeFailures -gt 0) {
    Write-Host ""
    Write-Error "$writeFailures file(s) could not be written (see the warnings above). Nothing else was rolled back."
    exit 1
}

if ($standaloneColors.Count -gt 0) {
    Write-Host ""
    Write-Warning ("{0} color literal(s) sit beside an SVG in {1} DAX file(s) and were NOT rewritten:" -f `
                   $standaloneColors.Count, $standaloneFiles.Count)
    Write-Host ("    " + (($standaloneColors.Keys | Sort-Object) -join ', '))
    Write-Host "    They are their own literal, not part of the SVG - the dynamic-icon pattern,"
    Write-Host "    e.g. VAR Color = IF(..., '%230078D4', ...). Rewriting them would mean deciding"
    Write-Host "    that any color-shaped string in the model feeds an icon. Change them by hand if"
    Write-Host "    they do."
}

if ($unsupportedSeen.Count -gt 0) {
    Write-Host ""
    Write-Warning ("Some colors were NOT rewritten in {0} file(s), because this tool only replaces hex notation:" -f $filesWithUnsupported.Count)
    foreach ($kv in $unsupportedSeen.GetEnumerator() | Sort-Object Value -Descending) {
        Write-Host ("  {0}  ({1} occurrences)" -f $kv.Key, $kv.Value)
    }
    Write-Host "  Run detect-colors.ps1 to see which files they are in."
}
