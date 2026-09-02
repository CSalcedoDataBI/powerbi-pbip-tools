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

    # Nombrar el archivo, no solo contarlo: el aviso existe para que el usuario
    # vaya a cambiar esos literales a mano, y "1 DAX file(s)" en un modelo de
    # cuarenta tablas no lleva a ninguna parte.
    Test-Check -Name 'pero lo AVISA, con el color Y el archivo' `
        -Ok ($out -match 'NOT rewritten' -and $out -match '#D13438' -and $out -match 'in: Icons\.tmdl') `
        -Detail 'el aviso nombra color y archivo'

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

    # --- el color destino puede tener OTRA longitud ---------------------------
    # Todas las comprobaciones de arriba usan '#DC143C', que mide lo mismo que
    # '#0078D4'. Con esa longitud, un re-encodificado por indice pasa igual - y
    # era incorrecto. -To acepta 3, 4, 6 y 8 digitos: en cuanto la sustitucion
    # cambia el largo, los indices posteriores se desplazan. Medido antes del
    # arreglo, con -To '#fff':
    #     url(%23grad)       ->  url(#grad)
    #     stroke='%230078D4' ->  stroke='#fff'
    # Un '#' crudo corta el data URI en el fragmento y el icono deja de pintarse.
    foreach ($target in @('#fff', '#11223344')) {
        $root = Copy-Fixture
        & pwsh -NoProfile -File $recolor -PbipDir $root -To $target -Scope All -Backup *>&1 | Out-Null
        $t = Get-Tmdl -Root $root
        # Anclado en 'linearGradient', que aparece una sola vez: el archivo tiene
        # DOS literales con data:image/svg+xml y un patron mas laxo puede engancharse
        # al otro. Y el detalle imprime SIEMPRE lo que se midio - un fallo que solo
        # dice "ningun # crudo" no deja diagnosticar nada.
        $badge = ([regex]::Match($t, "data:image/svg\+xml[^
]*linearGradient[^
]*")).Value
        $bare = [regex]::Matches($badge, '#').Count
        $expected = $target.TrimStart('#')
        $ok = $badge.Length -gt 0 -and $bare -eq 0 -and
              $badge -match "url\(%23grad\)" -and
              $badge -match "stroke='%23$expected'" -and
              $badge -match "stop-color='%23$expected'"
        Test-Check -Name "con -To $target el payload sigue percent-encoded" `
            -Ok $ok -Detail "'#' crudos: $bare | $badge"
    }

    # --- una ruta relativa no puede destrozar el backup -----------------------
    # El nombre del backup se construye con la ruta RELATIVA al proyecto. Cortar
    # un FullName absoluto por la longitud de un -PbipDir relativo corta en el
    # offset equivocado: './DynamicIcons' producia 'obal__AppData__Local__...',
    # partido a mitad de palabra.
    $root = Copy-Fixture
    $parent = Split-Path $root -Parent
    Push-Location $parent
    try {
        $relOut = (& pwsh -NoProfile -File $recolor -PbipDir './DynamicIcons' -To '#DC143C' `
                     -Scope All -Backup *>&1 | Out-String)
    } finally { Pop-Location }
    $relBackup = ([regex]::Match($relOut, 'embedded-SVG file\(s\) saved to: (?<p>.+)')).Groups['p'].Value.Trim()
    $script:tempPaths += $relBackup
    $relNames = if ($relBackup -and (Test-Path -LiteralPath $relBackup)) {
        @((Get-ChildItem -LiteralPath $relBackup -File).Name)
    } else { @() }
    $allRelative = $relNames.Count -eq 3 -and
                   -not (@($relNames | Where-Object { $_ -notmatch '^DynamicIcons\.' }).Count)
    Test-Check -Name 'con -PbipDir relativo el backup conserva nombres legibles' `
        -Ok $allRelative `
        -Detail (($relNames | Sort-Object) -join ' | ')

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
