<#
.SYNOPSIS
  Behavioural tests for tools/dashboard/Inline-ChartJs.ps1.

.DESCRIPTION
  The script's whole job is a licensing guarantee: every dashboard it converts
  must carry the Chart.js MIT notice, and it must never report success while
  leaving a CDN tag behind. Both failure modes are silent - the page still looks
  right on a machine with internet - so they are pinned here rather than left to
  a manual look.

  Every assertion reads the produced file, never the script's own printed output.

.EXAMPLE
  pwsh tests/inline-chartjs-test.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$inliner  = Join-Path $repoRoot 'tools/dashboard/Inline-ChartJs.ps1'
$vendor   = Join-Path $repoRoot 'tools/dashboard/vendor'

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

# Same discipline as color-tokens-test.ps1: register exact paths, never glob the
# temp directory on cleanup.
$script:tempPaths = @()
function Get-ScopedTempPath {
    param([Parameter(Mandatory)][string]$Prefix)
    $p = Join-Path ([System.IO.Path]::GetTempPath()) "$Prefix-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    $script:tempPaths += $p
    return $p
}

$CDN = '<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>'

$work = Get-ScopedTempPath -Prefix 'inline-chartjs'
Write-Host "=== Inline-ChartJs tests ===" -ForegroundColor Cyan
Write-Host "  Fixture: $work`n"

try {
    New-Item -ItemType Directory -Path $work -Force | Out-Null

    # A dashboard is only what the script cares about: a CDN tag and some text.
    # The '$&' and '$1' are deliberate - a -replace based implementation would
    # read them as capture-group references and corrupt the output.
    function Get-Dashboard {
        param([string]$Head = '', [int]$CdnTags = 1)
        $tags = (1..[Math]::Max($CdnTags, 0) | ForEach-Object { $CDN }) -join "`n"
        if ($CdnTags -le 0) { $tags = '' }
        return "<html><head>$Head`n$tags</head><body><p>cost is `$1 per `$& unit</p></body></html>"
    }

    function Invoke-Inliner {
        param([string]$File, [string[]]$Extra = @())
        $out = & pwsh -NoProfile -File $inliner -Path $File @Extra *>&1 | Out-String
        return [pscustomobject]@{ Output = $out; ExitCode = $LASTEXITCODE }
    }

    # --- happy path -----------------------------------------------------------
    $f = Join-Path $work 'happy.html'
    [System.IO.File]::WriteAllText($f, (Get-Dashboard))
    $r = Invoke-Inliner -File $f
    $t = [System.IO.File]::ReadAllText($f)

    Test-Check -Name 'inlina la libreria y sale con 0' `
        -Ok ($r.ExitCode -eq 0 -and $t.Length -gt 150000) `
        -Detail "exit $($r.ExitCode), $($t.Length) bytes"

    Test-Check -Name 'no queda ninguna referencia externa' `
        -Ok (-not ($t -match '(?i)<script\s+src\s*=\s*"https?://')) `
        -Detail 'sin <script src="http...">'

    # The point of the whole change: MIT requires the notice to travel with the
    # copy, and every generated dashboard IS a copy.
    Test-Check -Name 'el aviso MIT completo viaja dentro del HTML' `
        -Ok ($t.Contains('Permission is hereby granted') -and
             $t.Contains('Copyright (c) 2014-2022 Chart.js Contributors') -and
             $t.Contains('The above copyright notice and this permission notice shall be included')) `
        -Detail 'copyright + permiso + clausula de inclusion'

    # Si la licencia se derramara fuera del comentario, su texto quedaria como
    # JavaScript y la pagina moriria con un SyntaxError. La prueba: el primer
    # '*/' despues del '/*!' tiene que venir DESPUES del texto de la licencia.
    $bannerStart = $t.IndexOf('/*!')
    $bannerEnd   = if ($bannerStart -ge 0) { $t.IndexOf('*/', $bannerStart) } else { -1 }
    $licenseAt   = $t.IndexOf('Permission is hereby granted')
    Test-Check -Name 'la licencia queda dentro del comentario, no derramada en el JS' `
        -Ok ($bannerStart -ge 0 -and $bannerEnd -gt $licenseAt -and $licenseAt -gt $bannerStart) `
        -Detail "/*! en $bannerStart, licencia en $licenseAt, cierre en $bannerEnd"

    # A -replace implementation would have eaten these.
    Test-Check -Name 'el splice no interpreta $& ni $1 del documento' `
        -Ok ($t.Contains('cost is $1 per $& unit')) `
        -Detail 'texto del dashboard intacto'

    # --- idempotencia ---------------------------------------------------------
    $sizeBefore = (Get-Item $f).Length
    $r2 = Invoke-Inliner -File $f
    Test-Check -Name 'la segunda corrida no toca el archivo' `
        -Ok ($r2.ExitCode -eq 0 -and (Get-Item $f).Length -eq $sizeBefore) `
        -Detail "exit $($r2.ExitCode), tamano igual"

    # --- el marcador no basta: tiene que coincidir con el estado real ---------
    # Un dashboard lleva titulos y datos arbitrarios. Si uno contuviera el texto
    # del marcador, confiar solo en el dejaria el CDN puesto Y sin aviso MIT,
    # en silencio y reportando exito.
    $f2 = Join-Path $work 'marcador-falso.html'
    [System.IO.File]::WriteAllText($f2, (Get-Dashboard -Head '<title>inlined by Inline-ChartJs.ps1</title>'))
    $r3 = Invoke-Inliner -File $f2
    $t2 = [System.IO.File]::ReadAllText($f2)
    Test-Check -Name 'marcador presente + CDN presente = error, no falso OK' `
        -Ok ($r3.ExitCode -ne 0 -and $t2.Contains($CDN) -and
             -not $t2.Contains('Permission is hereby granted')) `
        -Detail "exit $($r3.ExitCode), archivo sin tocar"

    # --- mas de una etiqueta CDN ---------------------------------------------
    # Reemplazar solo la primera dejaria una dependencia de red viva mientras el
    # script reporta que el archivo ya es autonomo.
    $f3 = Join-Path $work 'dos-tags.html'
    [System.IO.File]::WriteAllText($f3, (Get-Dashboard -CdnTags 2))
    $r4 = Invoke-Inliner -File $f3
    $t3 = [System.IO.File]::ReadAllText($f3)
    Test-Check -Name 'quita todas las etiquetas CDN, no solo la primera' `
        -Ok ($r4.ExitCode -eq 0 -and -not $t3.Contains('cdn.jsdelivr.net')) `
        -Detail 'ninguna cdn.jsdelivr.net sobrevive'
    Test-Check -Name 'y embebe la libreria una sola vez' `
        -Ok (([regex]::Matches($t3, [regex]::Escape('inlined by Inline-ChartJs.ps1'))).Count -eq 1) `
        -Detail 'un solo bloque inlinado'

    # --- otras referencias externas ------------------------------------------
    # Quitar Chart.js no es lo mismo que estar offline. El script debe decir lo
    # que queda en vez de dejar inferir una garantia que no puede dar.
    $f4 = Join-Path $work 'otra-externa.html'
    [System.IO.File]::WriteAllText($f4,
        (Get-Dashboard -Head '<link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Inter">'))
    $r5 = Invoke-Inliner -File $f4
    Test-Check -Name 'avisa de las referencias externas que NO puede quitar' `
        -Ok ($r5.ExitCode -eq 0 -and $r5.Output -match 'WARNING' -and
             $r5.Output -match 'fonts\.googleapis\.com' -and
             $r5.Output -notmatch 'No external references remain') `
        -Detail 'no afirma offline cuando no lo es'

    # --- sin licencia no se publica ------------------------------------------
    # Preferible fallar a redistribuir codigo ajeno con el aviso quitado.
    $fakeVendor = Join-Path $work 'vendor-sin-licencia'
    New-Item -ItemType Directory -Path $fakeVendor -Force | Out-Null
    Copy-Item (Join-Path $vendor 'chart.umd.min.js') $fakeVendor
    $f5 = Join-Path $work 'sin-licencia.html'
    [System.IO.File]::WriteAllText($f5, (Get-Dashboard))
    $r6 = Invoke-Inliner -File $f5 -Extra @('-LibraryPath', (Join-Path $fakeVendor 'chart.umd.min.js'))
    $t5 = [System.IO.File]::ReadAllText($f5)
    Test-Check -Name 'sin chart.js.LICENSE.txt se niega a escribir' `
        -Ok ($r6.ExitCode -ne 0 -and $t5.Contains($CDN)) `
        -Detail "exit $($r6.ExitCode), archivo sin tocar"

    # --- nada que inlinar -----------------------------------------------------
    $f6 = Join-Path $work 'sin-cdn.html'
    [System.IO.File]::WriteAllText($f6, (Get-Dashboard -CdnTags 0))
    $r7 = Invoke-Inliner -File $f6
    Test-Check -Name 'un archivo sin etiqueta CDN falla en vez de fingir exito' `
        -Ok ($r7.ExitCode -ne 0) -Detail "exit $($r7.ExitCode)"
}
finally {
    foreach ($p in $script:tempPaths) {
        if ($p -and (Test-Path $p)) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host "INLINE-CHARTJS TESTS FAILED - $($failures.Count): $($failures -join '; ')" -ForegroundColor Red
    exit 1
}
Write-Host "INLINE-CHARTJS TESTS PASSED" -ForegroundColor Green
exit 0
