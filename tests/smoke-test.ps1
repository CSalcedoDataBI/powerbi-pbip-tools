<#
.SYNOPSIS
  Smoke test for the skill-svg-recolor-powerbi scripts against a real PBIP project.

.DESCRIPTION
  Copies a PBIP project to a temp folder and drives detect-colors.ps1 + recolor.ps1
  against the copy, so the repo's own examples are never modified.

  Checks:
    1. detect-colors.ps1 runs without throwing and reports at least one #RRGGBB.
    2. What it reports matches the files on disk (ground truth, not self-report).
    3. recolor.ps1 rewrites the files, verified ON DISK.
    4. A second identical run leaves the SVG tree byte-identical (idempotency).
    5. A -From color that is not present leaves the tree byte-identical.
    6. detect-colors.ps1 afterwards reports the target and not the source.

  Every assertion about what changed reads the files, never the scripts' own
  printed counts. A smoke test that believes the thing it is testing proves
  nothing when that thing is what is broken - a recolor that rewrote files and
  printed "0 SVGs actualizados" would pass a report-reading check.

  This is SMOKE coverage, not behavioral coverage: the error paths of both
  scripts (missing .Report, missing RegisteredResources, malformed hex) are
  deliberately out of scope here.

.PARAMETER PbipDir
  PBIP project to test against. Defaults to examples/Demo in this repo.

.PARAMETER TargetColor
  Color to recolor to. Must not already be present in the project.

.EXAMPLE
  pwsh tests/smoke-test.ps1
  pwsh tests/smoke-test.ps1 -PbipDir "./examples/DAX-User-Defined-Functions"
#>
[CmdletBinding()]
param(
    [string]$PbipDir,
    [ValidatePattern('^#[0-9A-Fa-f]{6}$')]
    [string]$TargetColor = '#00FF7F'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
if (-not $PbipDir) { $PbipDir = Join-Path $repoRoot 'examples/Demo' }

$scripts = Join-Path $repoRoot 'skills/skill-svg-recolor-powerbi/scripts'
$detect  = Join-Path $scripts 'detect-colors.ps1'
$recolor = Join-Path $scripts 'recolor.ps1'

foreach ($p in @($detect, $recolor, $PbipDir)) {
    if (-not (Test-Path $p)) { throw "No existe: $p" }
}

$failures = @()
function Test-Check {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    if ($Ok) {
        Write-Host "  PASS  $Name" -ForegroundColor Green
        if ($Detail) { Write-Host "        $Detail" -ForegroundColor DarkGray }
    }
    else {
        Write-Host "  FAIL  $Name" -ForegroundColor Red
        Write-Host "        $Detail" -ForegroundColor Red
        $script:failures += $Name
    }
}

# Ground truth: how many .svg files under the project actually contain this color.
function Get-FileCountWithColor {
    param([string]$Root, [string]$Color)
    $n = 0
    foreach ($f in (Get-ChildItem $Root -Recurse -Filter '*.svg' -File)) {
        if ([System.IO.File]::ReadAllText($f.FullName) -match [regex]::Escape($Color)) { $n++ }
    }
    return $n
}

# Fingerprint of every SVG's CONTENT under the project. Two runs that leave this
# equal changed nothing on disk, whatever the script printed about itself.
function Get-TreeHash {
    param([string]$Root)
    $sb = [System.Text.StringBuilder]::new()
    foreach ($f in (Get-ChildItem $Root -Recurse -Filter '*.svg' -File | Sort-Object FullName)) {
        [void]$sb.AppendLine($f.FullName.Substring($Root.Length))
        [void]$sb.AppendLine((Get-FileHash $f.FullName -Algorithm SHA256).Hash)
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($sb.ToString())
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '') }
    finally { $sha.Dispose() }
}

# Parse the color lines out of detect-colors' report.
function Get-ReportedColor {
    param([string]$Text)
    # The leading comma is load-bearing TWICE over: `return @(...)` UNROLLS the array
    # on the way out, so a single match comes back as a String and $colors[0] would be
    # the character '#'. `,@(...)` returns the array itself.
    return ,@([regex]::Matches($Text, '(?m)^\s+(#[0-9A-Fa-f]{6})\s') |
        ForEach-Object { $_.Groups[1].Value.ToUpper() })
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) "pbip-smoke-$([guid]::NewGuid().ToString('N').Substring(0,8))"
Write-Host "=== Smoke test  svg-recolor ===" -ForegroundColor Cyan
Write-Host "  Origen : $PbipDir"
Write-Host "  Copia  : $work`n"

try {
    # Inside the try: with ErrorActionPreference=Stop a failed copy would otherwise
    # terminate the script before finally{} exists, leaking a half-copied temp dir.
    Copy-Item -Path $PbipDir -Destination $work -Recurse -Force

    # --- 1. detect-colors runs and reports colors ----------------------------
    # NOTE: *>&1, not 2>&1. Both scripts report through Write-Host, which writes to
    # the information stream and is invisible to a plain 2>&1 capture. That is exactly
    # what PSAvoidUsingWriteHost warns about, and it silently broke this test once.
    $threw = $null
    try { $out1 = & $detect -PbipDir $work *>&1 | Out-String }
    catch { $threw = $_.Exception.Message; $out1 = '' }
    Test-Check -Name 'detect-colors corre sin lanzar excepcion' -Ok ($null -eq $threw) -Detail "error: $threw"

    $colors = Get-ReportedColor -Text $out1
    Test-Check -Name 'detect-colors reporta al menos un color' -Ok ($colors.Count -gt 0) -Detail "reportados: $($colors -join ', ')"
    if ($colors.Count -eq 0) { throw 'Sin colores detectados: el resto del test no tiene sentido.' }

    $source = $colors[0]
    # -contains, not -eq against $colors[0]: the target colliding with ANY color already
    # present breaks check 3's arithmetic, not just a collision with the source.
    if ($colors -contains $TargetColor.ToUpper()) {
        throw "El color objetivo $TargetColor ya esta en el proyecto ($($colors -join ', ')); elige otro."
    }

    # --- 2. the report matches the disk --------------------------------------
    $onDisk = Get-FileCountWithColor -Root $work -Color $source
    $reported = [int]([regex]::Match($out1, [regex]::Escape($source) + '\s+\((\d+)').Groups[1].Value)
    Test-Check -Name 'lo reportado coincide con los archivos en disco' -Ok ($onDisk -eq $reported -and $onDisk -gt 0) -Detail `
        "$source -> reportado $reported / en disco $onDisk"

    # --- 3. recolor changes files, verified ON DISK --------------------------
    & $recolor -PbipDir $work -From $source -To $TargetColor *>&1 | Out-Null
    $srcAfter = Get-FileCountWithColor -Root $work -Color $source
    $tgtAfter = Get-FileCountWithColor -Root $work -Color $TargetColor
    Test-Check -Name 'recolor reescribe los archivos en disco' -Ok ($tgtAfter -eq $onDisk -and $srcAfter -eq 0) -Detail `
        "objetivo en $tgtAfter archivo(s), origen queda en $srcAfter"

    # --- 4. idempotency, verified ON DISK -------------------------------------
    # The script's own "0 / N SVGs" line is not evidence here: if it rewrote files
    # and printed 0, trusting the print is exactly the failure this check is for.
    $hashBefore = Get-TreeHash -Root $work
    & $recolor -PbipDir $work -From $source -To $TargetColor *>&1 | Out-Null
    $hashAfter = Get-TreeHash -Root $work
    Test-Check -Name 'segunda pasada identica no toca ningun archivo' -Ok ($hashBefore -eq $hashAfter) `
        -Detail "hash del arbol $(if ($hashBefore -eq $hashAfter) { 'identico' } else { 'CAMBIO' })"

    # --- 5. a -From that is not present must be a no-op -----------------------
    # The sentinel is chosen from what is actually absent, so this check can never be
    # skipped: a hardcoded one that turned up in the fixture would silently vanish.
    $present = Get-ReportedColor -Text (& $detect -PbipDir $work *>&1 | Out-String)
    $absent = @('#123456', '#ABCDEF', '#010203', '#FEDCBA') |
        Where-Object { $_ -notin $present } | Select-Object -First 1
    Test-Check -Name 'hay un color ausente con el que probar el no-op' -Ok ($null -ne $absent) `
        -Detail "centinela: $absent"
    if ($absent) {
        $hashBefore2 = Get-TreeHash -Root $work
        & $recolor -PbipDir $work -From $absent -To '#654321' *>&1 | Out-Null
        Test-Check -Name '-From con un color ausente no toca ningun archivo' `
            -Ok ($hashBefore2 -eq (Get-TreeHash -Root $work)) -Detail "centinela $absent"
    }

    # --- 6. detect-colors reflects the new state ------------------------------
    $out6 = & $detect -PbipDir $work *>&1 | Out-String
    $after = Get-ReportedColor -Text $out6
    Test-Check -Name 'detect-colors refleja el color nuevo y no el viejo' `
        -Ok (($after -contains $TargetColor.ToUpper()) -and -not ($after -contains $source)) `
        -Detail "ahora: $($after -join ', ')"
}
finally {
    if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host "SMOKE TEST FAILED - $($failures.Count) check(s): $($failures -join '; ')" -ForegroundColor Red
    exit 1
}
Write-Host "SMOKE TEST PASSED" -ForegroundColor Green
exit 0
