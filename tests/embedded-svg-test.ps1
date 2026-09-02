<#
.SYNOPSIS
  Behavioural tests for -Scope Dax / Visuals: SVGs that live inside .tmdl and
  visual.json rather than in a folder of .svg files.

.DESCRIPTION
  The failure this scope exists to remove is silent: a user recolors a project,
  is told "184/184 updated", opens Power BI and the icons are still blue, because
  those icons came from a DAX measure. The tests therefore care as much about
  what is NOT rewritten - DAX logic, fragment references, prose that mentions a
  hex - as about what is.

  Runs against a throwaway copy of examples/DynamicIcons. Every assertion reads
  the produced files, never the scripts' printed counts.

.EXAMPLE
  pwsh tests/embedded-svg-test.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$scripts  = Join-Path $repoRoot 'skills/skill-svg-recolor-powerbi/scripts'
$modules  = Join-Path $repoRoot 'skills/skill-svg-recolor-powerbi/modules'
$recolor  = Join-Path $scripts 'recolor.ps1'
$detect   = Join-Path $scripts 'detect-colors.ps1'
$fixture  = Join-Path $repoRoot 'examples/DynamicIcons'

$failures = @()
function Test-Check {
    param([string]$Name, [bool]$Ok, [string]$Detail)
    if ($Ok) {
        Write-Host "  PASS  $Name" -ForegroundColor Green
        if ($Detail) { Write-Host "        $Detail" -ForegroundColor DarkGray }
    } else {
        Write-Host "  FAIL  $Name" -ForegroundColor Red
        Write-Host "        $Detail" -ForegroundColor Red
        $script:failures += $Name
    }
}

$script:tempPaths = @()
function Get-ScopedTempPath {
    param([Parameter(Mandatory)][string]$Prefix)
    $p = Join-Path ([System.IO.Path]::GetTempPath()) "$Prefix-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    $script:tempPaths += $p
    return $p
}

# A fresh copy per scenario: these tests write to the model, and a shared copy
# would make each one depend on the order of the ones before it.
# Copy-, not New-: it copies a folder that already exists, and a New- verb would
# also make PSScriptAnalyzer demand ShouldProcess for a test helper.
function Copy-Fixture {
    $dir = Get-ScopedTempPath -Prefix 'embedded-svg'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Copy-Item -LiteralPath $fixture -Destination $dir -Recurse -Force
    return (Join-Path $dir 'DynamicIcons')
}

function Get-Tmdl { param($Root) return [System.IO.File]::ReadAllText(
    (Join-Path $Root 'DynamicIcons.SemanticModel/definition/tables/Icons.tmdl')) }
function Get-VisualJson { param($Root, $V = 'v1') return [System.IO.File]::ReadAllText(
    (Join-Path $Root "DynamicIcons.Report/definition/pages/pg1/visuals/$V/visual.json")) }

Write-Host "=== Embedded-SVG tests (-Scope Dax / Visuals) ===" -ForegroundColor Cyan
Write-Host "  Fixture: $fixture`n"

try {
    Import-Module (Join-Path $modules 'ColorTokens.psm1') -Force
    Import-Module (Join-Path $modules 'SvgPayload.psm1') -Force

    # --- el default no cambio -------------------------------------------------
    # Cualquier invocacion que ya existia tiene que seguir significando lo mismo.
    # Un default mas amplio habria empezado a escribir en el modelo a gente que
    # solo pregunto por iconos.
    $root = Copy-Fixture
    $tmdlBefore = Get-Tmdl -Root $root
    $jsonBefore = Get-VisualJson -Root $root
    # Con -Backup a proposito: sin el, un default de 'All' tambien dejaria los
    # archivos intactos - pero porque el freno del .tmdl aborta la corrida, no
    # porque el scope sea el correcto. La comprobacion pasaria por el motivo
    # equivocado y no detectaria un default ensanchado por accidente.
    & pwsh -NoProfile -File $recolor -PbipDir $root -To '#DC143C' -Backup *>&1 | Out-Null
    Test-Check -Name 'el scope por defecto no toca el modelo ni los visuales' `
        -Ok ((Get-Tmdl -Root $root) -eq $tmdlBefore -and (Get-VisualJson -Root $root) -eq $jsonBefore) `
        -Detail 'sin -Scope, Resources: .tmdl y visual.json byte a byte iguales'

    # --- el freno del .tmdl ---------------------------------------------------
    # Escribir en el modelo sin red no es una opcion: un fallo ahi no estropea un
    # icono, impide abrir el informe.
    $root = Copy-Fixture
    $tmdlBefore = Get-Tmdl -Root $root
    & pwsh -NoProfile -File $recolor -PbipDir $root -To '#DC143C' -Scope Dax *>&1 | Out-Null
    $gateExit = $LASTEXITCODE
    Test-Check -Name '-Scope Dax sin -Backup ni -WhatIf se niega y no escribe' `
        -Ok ($gateExit -ne 0 -and (Get-Tmdl -Root $root) -eq $tmdlBefore) `
        -Detail "exit $gateExit, .tmdl intacto"

    # --- -WhatIf no escribe ---------------------------------------------------
    $root = Copy-Fixture
    $tmdlBefore = Get-Tmdl -Root $root
    $jsonBefore = Get-VisualJson -Root $root
    & pwsh -NoProfile -File $recolor -PbipDir $root -To '#DC143C' -Scope All -WhatIf *>&1 | Out-Null
    Test-Check -Name '-WhatIf no escribe ni en el modelo ni en el visual' `
        -Ok ((Get-Tmdl -Root $root) -eq $tmdlBefore -and (Get-VisualJson -Root $root) -eq $jsonBefore) `
        -Detail 'ambos byte a byte iguales'

    # --- la pasada real -------------------------------------------------------
    $root = Copy-Fixture
    $out = (& pwsh -NoProfile -File $recolor -PbipDir $root -To '#DC143C' -Scope All -Backup *>&1 | Out-String)
    $tmdl = Get-Tmdl -Root $root

    Test-Check -Name 'recolorea el SVG que vive dentro de una medida DAX' `
        -Ok ($tmdl -match "stop-color='%23DC143C'" -and $tmdl -match "stroke='%23DC143C'") `
        -Detail 'los dos colores del payload, re-codificados como %23'

    # url(%23grad) es una referencia a un fragmento, no un color. Que ColorTokens
    # lo sepa es el motivo de decodificar el payload antes de mirarlo, en vez de
    # escribir una segunda regla contra la cadena percent-encoded.
    Test-Check -Name 'no toca url(%23grad), que es una referencia y no un color' `
        -Ok ($tmdl -match "fill='url\(%23grad\)'") `
        -Detail 'el gradiente sigue apuntando a su id'

    # El patron de icono dinamico deja el color en su propio literal. Reescribirlo
    # seria decidir que cualquier cadena con forma de color alimenta un icono.
    Test-Check -Name 'no reescribe el color del IF, que esta fuera del payload' `
        -Ok ($tmdl -match '"%230078D4", "%23D13438"') `
        -Detail 'la logica DAX conserva sus dos colores'

    Test-Check -Name 'pero lo AVISA, en vez de callarselo' `
        -Ok ($out -match 'NOT rewritten' -and $out -match '#D13438') `
        -Detail 'el aviso nombra los colores que quedaron fuera'

    Test-Check -Name 'no toca un hex que solo es texto en una medida' `
        -Ok ($tmdl -match 'Brand primary is #0078D4 - do not change') `
        -Detail 'la medida Palette Note intacta'

    # Lo que rodea al payload es el modelo. Si cambia algo mas que el color, el
    # informe puede no abrir.
    $logicBefore = ($tmdlBefore -split "`n" | Where-Object { $_ -notmatch 'svg' }) -join "`n"
    $logicAfter  = ($tmdl -split "`n" | Where-Object { $_ -notmatch 'svg' }) -join "`n"
    Test-Check -Name 'ninguna linea sin SVG del .tmdl cambio' `
        -Ok ($logicBefore -eq $logicAfter) `
        -Detail 'particiones, lineageTags, columnas y comentarios iguales'

    # --- visual.json ----------------------------------------------------------
    $json = Get-VisualJson -Root $root
    $payload = @(Get-SvgPayload -Text $json -Kind Visual)
    Test-Check -Name 'decodifica el base64, recolorea y lo vuelve a codificar' `
        -Ok ($payload.Count -eq 1 -and $payload[0].Svg -match '#DC143C' -and $payload[0].Svg -notmatch '#0078D4') `
        -Detail $payload[0].Svg

    Test-Check -Name 'y dentro del base64 tampoco toca url(#g)' `
        -Ok ($payload[0].Svg -match 'url\(#g\)') `
        -Detail 'la referencia al gradiente sobrevive al viaje de ida y vuelta'

    $parsed = $null
    try { $parsed = $json | ConvertFrom-Json } catch { $parsed = $null }
    Test-Check -Name 'el visual.json sigue siendo JSON valido' `
        -Ok ($null -ne $parsed) -Detail 'ConvertFrom-Json lo acepta'

    Test-Check -Name "y el titulo con '#1' no se confundio con un color" `
        -Ok ($json -match 'Ventas #1 del trimestre') `
        -Detail 'texto del visual intacto'

    # --- el backup existe y no se pisa a si mismo -----------------------------
    # visual.json se llama igual en cada visual: un Copy-Item plano dejaria un
    # "backup" con un solo archivo de los tres.
    $backupLine = ([regex]::Match($out, 'embedded-SVG file\(s\) saved to: (?<p>.+)')).Groups['p'].Value.Trim()
    $script:tempPaths += $backupLine
    $backupFiles = if ($backupLine -and (Test-Path -LiteralPath $backupLine)) {
        @(Get-ChildItem -LiteralPath $backupLine -File)
    } else { @() }
    Test-Check -Name 'el backup guarda los tres anfitriones sin pisarse' `
        -Ok ($backupFiles.Count -eq 3) `
        -Detail "$($backupFiles.Count) archivo(s): $(($backupFiles.Name | Sort-Object) -join ', ')"

    # --- idempotencia ---------------------------------------------------------
    $tmdlOnce = Get-Tmdl -Root $root
    $jsonOnce = Get-VisualJson -Root $root
    & pwsh -NoProfile -File $recolor -PbipDir $root -To '#DC143C' -Scope All -Backup *>&1 | Out-Null
    Test-Check -Name 'una segunda pasada al mismo color no cambia nada' `
        -Ok ((Get-Tmdl -Root $root) -eq $tmdlOnce -and (Get-VisualJson -Root $root) -eq $jsonOnce) `
        -Detail 'el base64 no se reescribe por reescribirse'

    # --- detect ve lo mismo que recolor reescribe -----------------------------
    $root = Copy-Fixture
    $det = (& pwsh -NoProfile -File $detect -PbipDir $root -Scope All *>&1 | Out-String)
    Test-Check -Name 'detect-colors informa de las tres fuentes' `
        -Ok ($det -match 'DAX measures' -and $det -match 'visual\.json' -and $det -match 'RegisteredResources') `
        -Detail 'carpeta, modelo y visuales'

    $detDefault = (& pwsh -NoProfile -File $detect -PbipDir $root *>&1 | Out-String)
    Test-Check -Name 'y sin -Scope no inventa fuentes que no miro' `
        -Ok ($detDefault -notmatch 'DAX measures' -and $detDefault -notmatch 'visual\.json') `
        -Detail 'el default sigue siendo solo la carpeta'
}
finally {
    foreach ($p in $script:tempPaths) {
        if ($p -and (Test-Path -LiteralPath $p)) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host "EMBEDDED-SVG TESTS FAILED - $($failures.Count): $($failures -join '; ')" -ForegroundColor Red
    exit 1
}
Write-Host "EMBEDDED-SVG TESTS PASSED" -ForegroundColor Green
exit 0
