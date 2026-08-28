<#
.SYNOPSIS
  Smoke test for the skill-svg-recolor-powerbi scripts against a real PBIP project.

.DESCRIPTION
  Copies a PBIP project to a temp folder and drives detect-colors.ps1 + recolor.ps1
  against the copy, so the repo's own examples are never modified.

  Checks, in order:
    1. detect-colors.ps1 exits 0 and reports at least one #RRGGBB color.
    2. recolor.ps1 changes MORE than 0 files.
    3. A second identical run changes EXACTLY 0 files (idempotency).
    4. detect-colors.ps1 now reports the target color and no longer the source.

  Check 3 is the one worth having: a recolor that keeps "changing" files it already
  changed means the write is not converging, and that is invisible from the output.

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
function Check($name, [bool]$ok, $detail) {
    if ($ok) { Write-Host "  PASS  $name" -ForegroundColor Green }
    else {
        Write-Host "  FAIL  $name" -ForegroundColor Red
        Write-Host "        $detail" -ForegroundColor Red
        $script:failures += $name
    }
    if ($detail -and $ok) { Write-Host "        $detail" -ForegroundColor DarkGray }
}

# Work on a throwaway copy: the test must never touch the repo's examples.
$work = Join-Path ([System.IO.Path]::GetTempPath()) "pbip-smoke-$([guid]::NewGuid().ToString('N').Substring(0,8))"
Write-Host "=== Smoke test  svg-recolor ===" -ForegroundColor Cyan
Write-Host "  Origen : $PbipDir"
Write-Host "  Copia  : $work`n"
Copy-Item -Path $PbipDir -Destination $work -Recurse -Force

try {
    # --- 1. detect-colors reports at least one color -------------------------
    # NOTE: *>&1 (not 2>&1). Both scripts report through Write-Host, which writes to
    # the information stream and is invisible to a plain 2>&1 capture. That is exactly
    # what PSAvoidUsingWriteHost warns about, and it silently broke this test once.
    $out1 = & $detect -PbipDir $work *>&1 | Out-String
    $detectOk = $LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE
    # @() is load-bearing: with a single match the pipeline returns a STRING, and
    # $colors[0] would then be the character '#' instead of the color.
    $colors = @([regex]::Matches($out1, '(?m)^\s+(#[0-9A-Fa-f]{6})\s') | ForEach-Object { $_.Groups[1].Value.ToUpper() })
    Check 'detect-colors termina bien' $detectOk "exit=$LASTEXITCODE"
    Check 'detect-colors encuentra al menos un color' ($colors.Count -gt 0) "encontrados: $($colors -join ', ')"
    if ($colors.Count -eq 0) { throw 'Sin colores detectados: el resto del test no tiene sentido.' }

    $source = $colors[0]
    if ($source -eq $TargetColor.ToUpper()) { throw "El color objetivo $TargetColor ya esta en el proyecto; elige otro." }

    # --- 2. recolor changes more than 0 files --------------------------------
    $out2 = & $recolor -PbipDir $work -From $source -To $TargetColor *>&1 | Out-String
    $m2 = [regex]::Match($out2, '(\d+)\s*/\s*(\d+)\s+SVGs')
    $changed1 = if ($m2.Success) { [int]$m2.Groups[1].Value } else { -1 }
    Check 'recolor cambia mas de 0 archivos' ($changed1 -gt 0) "$source -> $TargetColor : $changed1 archivo(s)"

    # --- 3. idempotency: the same run again changes nothing -------------------
    $out3 = & $recolor -PbipDir $work -From $source -To $TargetColor *>&1 | Out-String
    $m3 = [regex]::Match($out3, '(\d+)\s*/\s*(\d+)\s+SVGs')
    $changed2 = if ($m3.Success) { [int]$m3.Groups[1].Value } else { -1 }
    Check 'segunda pasada identica cambia 0 archivos' ($changed2 -eq 0) "segunda pasada: $changed2 archivo(s)"

    # --- 4. the color actually moved -----------------------------------------
    $out4 = & $detect -PbipDir $work *>&1 | Out-String
    $after = @([regex]::Matches($out4, '(?m)^\s+(#[0-9A-Fa-f]{6})\s') | ForEach-Object { $_.Groups[1].Value.ToUpper() })
    Check 'el color objetivo esta presente despues' ($after -contains $TargetColor.ToUpper()) "ahora: $($after -join ', ')"
    Check 'el color de origen ya no esta' (-not ($after -contains $source)) "$source ausente: $(-not ($after -contains $source))"
}
finally {
    if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host "SMOKE TEST FAILED - $($failures.Count) check(s): $($failures -join '; ')" -ForegroundColor Red
    exit 1
}
Write-Host "SMOKE TEST PASSED - 6/6 checks" -ForegroundColor Green
exit 0
