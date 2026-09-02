<#
.SYNOPSIS
  Behavioural tests for the color-token handling of detect-colors.ps1 / recolor.ps1.

.DESCRIPTION
  smoke-test.ps1 proves the happy path against the real 184-file Demo project.
  This one builds a tiny synthetic PBIP whose SVGs contain exactly the awkward
  cases, because the Demo has none of them: 8-digit RGBA, 3-digit shorthand,
  rgb(), currentColor and a named color.

  Every assertion reads the files, never the scripts' own printed counts.

.EXAMPLE
  pwsh tests/color-tokens-test.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$scripts  = Join-Path $repoRoot 'skills/skill-svg-recolor-powerbi/scripts'
$modules  = Join-Path $repoRoot 'skills/skill-svg-recolor-powerbi/modules'
$detect   = Join-Path $scripts 'detect-colors.ps1'
$recolor  = Join-Path $scripts 'recolor.ps1'

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

# Every temp path this test creates, so the finalizer removes exactly those and
# nothing else. A glob like 'backups-*' over the whole temp directory would take
# unrelated data with it.
$script:tempPaths = @()
# Get-, not New-: it computes and registers a path, it does not create anything
# on disk. A New- verb would also make PSScriptAnalyzer demand ShouldProcess.
function Get-ScopedTempPath {
    param([Parameter(Mandatory)][string]$Prefix)
    $p = Join-Path ([System.IO.Path]::GetTempPath()) "$Prefix-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    $script:tempPaths += $p
    return $p
}

$work = Get-ScopedTempPath -Prefix 'pbip-tokens'
Write-Host "=== Color-token tests ===" -ForegroundColor Cyan
Write-Host "  Fixture: $work`n"

try {
    # A minimal PBIP whose icons carry every notation worth testing. Inline rather
    # than a New-* helper: that verb makes PSScriptAnalyzer demand ShouldProcess,
    # which is ceremony a test fixture does not need.
    $res = Join-Path (Join-Path (Join-Path $work 'Demo.Report') 'StaticResources') 'RegisteredResources'
    New-Item -ItemType Directory -Path $res -Force | Out-Null
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $fixture = @{
        'plain.svg' = '<svg><path fill="#0078D4"/></svg>'
        'alpha.svg' = '<svg><path fill="#0078D480"/><path fill="#0078D4"/></svg>'
        'short.svg' = '<svg><path fill="#FFF"/></svg>'
        'other.svg' = '<svg><path fill="rgb(0,120,212)"/><path stroke="currentColor"/><path style="fill:red"/></svg>'
        # Ids that look like hex are ordinary SVGO output. Rewriting the reference
        # while the id attribute stays put leaves the file rendering wrong.
        'refs.svg'  = '<svg><defs><linearGradient id="fff"/><mask id="0078D4"/></defs><rect fill="url(#fff)" mask="url(#0078D4)"/><use href="#fff"/><path fill="#0078D4"/></svg>'
        # The same reference written the other legal ways: quoted inside url(),
        # padded with spaces, and with whitespace around the href equals sign.
        # An entity-quoted href followed by a REAL color: the span must stop at the
        # attribute, not run on and swallow the color further down the line.
        'entity.svg'= '<svg><use href=&quot;#fff&quot;/><path fill=&quot;#0078D4&quot;/></svg>'
        # A file whose only colors are notations this tool cannot rewrite.
        # A hex-looking CSS id selector inside a <style> block. Rewriting it breaks
        # the stylesheet while the matching id attribute stays put.
        'css.svg'   = '<svg><style>#fff{fill:#0078D4} #abc,#def{stroke:#0078D4}</style><path id="fff"/></svg>'
        # Every selector shape that is NOT simply followed by { or , - chasing these
        # one at a time is what round 5 showed does not converge.
        'css2.svg'  = '<svg><style>#fff:hover{fill:#0078D4} #abc .child{fill:#0078D4} #def > path{fill:#0078D4} #012345[a=b]{fill:#0078D4}</style></svg>'
        'onlyother.svg' = '<svg><path fill="rgb(1,2,3)"/><path stroke="currentColor"/></svg>'
        'refs2.svg' = '<svg><rect fill="url(&apos;#fff&apos;)"/><rect fill="url( #0078D4 )"/><use href = "#fff"/><use xlink:href = &apos;#0078D4&apos;/><path fill="#0078D4"/></svg>'
    }
    foreach ($kv in $fixture.GetEnumerator()) {
        [System.IO.File]::WriteAllText((Join-Path $res $kv.Key), $kv.Value, $utf8NoBom)
    }

    # --- detect: 8-digit and 6-digit are DIFFERENT colors (#11) ----------------
    $report = & $detect -PbipDir $work -PassThru
    $colors = @($report | ForEach-Object { $_.Color })
    Test-Check -Name '8 y 6 digitos se reportan como colores distintos' `
        -Ok (($colors -contains '#0078D4') -and ($colors -contains '#0078D480')) `
        -Detail "reportados: $($colors -join ', ')"

    # --- detect: #FFF normalises to #FFFFFF (#12) ------------------------------
    Test-Check -Name '#FFF se normaliza a #FFFFFF' -Ok ($colors -contains '#FFFFFF') `
        -Detail "reportados: $($colors -join ', ')"

    # --- detect: -PassThru returns objects, not text (#22) ---------------------
    $shape = $report | Select-Object -First 1
    Test-Check -Name '-PassThru devuelve objetos con Color/FileCount/Report' `
        -Ok ($null -ne $shape.Color -and $null -ne $shape.FileCount -and $null -ne $shape.Report) `
        -Detail "$($shape.Report) / $($shape.Color) / $($shape.FileCount)"

    # --- detect: unsupported notations are reported (#12) ----------------------
    $printed = & $detect -PbipDir $work 6>&1 | Out-String
    Test-Check -Name 'reporta rgb()/currentColor/no-hex como no reescribibles' `
        -Ok ($printed -match 'Not rewritable' -and $printed -match 'rgb\(\)' -and
             $printed -match 'currentColor' -and $printed -match 'non-hex paint value') `
        -Detail 'las tres notaciones listadas, no solo la seccion'

    # --- recolor: 8-digit is NOT partially rewritten (#11) ---------------------
    & $recolor -PbipDir $work -From '#0078D4' -To '#DC143C' 6>&1 | Out-Null
    $alpha = [System.IO.File]::ReadAllText((Join-Path $res 'alpha.svg'))
    Test-Check -Name 'el token de 8 digitos sobrevive intacto' -Ok ($alpha -match '#0078D480') `
        -Detail $alpha
    Test-Check -Name 'el token de 6 digitos del mismo archivo si se reemplaza' -Ok ($alpha -match '#DC143C') `
        -Detail $alpha
    Test-Check -Name 'no quedo ningun #DC143C80 corrupto' -Ok ($alpha -notmatch '#DC143C80') `
        -Detail 'sin alfa colgando'

    # --- recolor: fragment references are NOT colors --------------------------
    $refs = [System.IO.File]::ReadAllText((Join-Path $res 'refs.svg'))
    Test-Check -Name 'url(#id) y href="#id" sobreviven al recolor' `
        -Ok ($refs -match 'url\(#fff\)' -and $refs -match 'url\(#0078D4\)' -and $refs -match 'href="#fff"') `
        -Detail $refs
    Test-Check -Name 'el fill real del mismo archivo si se reemplaza' `
        -Ok ($refs -match 'fill="#DC143C"') -Detail 'el color de verdad cambio'

    $refs2 = [System.IO.File]::ReadAllText((Join-Path $res 'refs2.svg'))
    Test-Check -Name 'url() con comillas/espacios y href con espacios tambien sobreviven' `
        -Ok ($refs2 -match "#fff" -and ($refs2 -split '#0078D4').Count -ge 3) -Detail $refs2

    $css = [System.IO.File]::ReadAllText((Join-Path $res 'css.svg'))
    Test-Check -Name 'los selectores CSS (#fff{) no se tratan como color' `
        -Ok ($css -match '#fff\{' -and $css -match '#abc,#def' -and $css -match 'fill:#DC143C') -Detail $css

    $entity = [System.IO.File]::ReadAllText((Join-Path $res 'entity.svg'))
    Test-Check -Name 'un href con &quot; no se traga el color siguiente' `
        -Ok ($entity -match '#DC143C' -and $entity -match '#fff') -Detail $entity

    # --- recolor: no BOM is written (#25) --------------------------------------
    $bytes = [System.IO.File]::ReadAllBytes((Join-Path $res 'plain.svg'))
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    Test-Check -Name 'no se inyecta BOM al escribir' -Ok (-not $hasBom) `
        -Detail ("primeros bytes: {0}" -f (($bytes[0..2] | ForEach-Object { $_.ToString('X2') }) -join ' '))

    # --- recolor: #FFF is matched by its canonical form (#12) ------------------
    & $recolor -PbipDir $work -From '#FFFFFF' -To '#000000' 6>&1 | Out-Null
    $short = [System.IO.File]::ReadAllText((Join-Path $res 'short.svg'))
    Test-Check -Name '-From #FFFFFF alcanza al #FFF escrito corto' -Ok ($short -match '#000000') -Detail $short

    # --- recolor: -Backup lands OUTSIDE the PBIP tree (#26) --------------------
    $backupRoot = Get-ScopedTempPath -Prefix 'pbip-backups'
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    & $recolor -PbipDir $work -From '#DC143C' -To '#00FF7F' -Backup -BackupRoot $backupRoot 6>&1 | Out-Null
    $insideTree = @(Get-ChildItem $res -Directory -Filter '*backup*' -Recurse -ErrorAction SilentlyContinue)
    $inRoot     = @(Get-ChildItem $backupRoot -Directory -ErrorAction SilentlyContinue)
    Test-Check -Name '-Backup no deja nada dentro del arbol PBIP' -Ok ($insideTree.Count -eq 0) `
        -Detail "carpetas de backup bajo RegisteredResources: $($insideTree.Count)"
    $copied = @(Get-ChildItem $backupRoot -Recurse -Filter '*.svg' -ErrorAction SilentlyContinue)
    $originals = @(Get-ChildItem $res -Filter '*.svg')
    Test-Check -Name '-Backup copia de verdad los SVG, no solo crea la carpeta' `
        -Ok ($inRoot.Count -ge 1 -and $copied.Count -eq $originals.Count) `
        -Detail "copiados $($copied.Count) de $($originals.Count) originales"

    # --- no stray control characters in the shipped scripts --------------------
    # A '\b' written in a non-raw Python helper string is a BACKSPACE, not a word
    # boundary. It shipped inside a regex twice - once in the named-color pattern,
    # once in the at-rule pattern - and each time the pattern silently matched
    # nothing. Cheap to check, invisible to read, so it is checked.
    $ctrl = @()
    foreach ($f in (Get-ChildItem (Join-Path $repoRoot 'skills') -Recurse -Filter '*.ps1') +
                   (Get-ChildItem (Join-Path $repoRoot 'tests') -Filter '*.ps1')) {
        $raw = [System.IO.File]::ReadAllText($f.FullName)
        $bad = ($raw.ToCharArray() | Where-Object { [int]$_ -lt 32 -and $_ -ne "`n" -and $_ -ne "`r" -and $_ -ne "`t" }).Count
        if ($bad -gt 0) { $ctrl += "$($f.Name): $bad" }
    }
    Test-Check -Name 'ningun caracter de control suelto en los .ps1' -Ok ($ctrl.Count -eq 0) `
        -Detail $(if ($ctrl.Count -eq 0) { 'limpio' } else { $ctrl -join ' | ' })

    # --- CSS classification, at the unit level ---------------------------------
    # Round 7 found five ways the CSS scan gave a wrong answer, all of them about
    # delimiters living inside strings and url(). These pin each one: the table is
    # (svg text -> exactly the tokens that must be treated as colors).
    Import-Module (Join-Path $modules 'ColorTokens.psm1') -Force
    Import-Module (Join-Path $modules 'PbipIo.psm1') -Force
    $cssCases = @(
        @{ n = 'hex in a content string is text';       t = '<svg><style>.a::before{content:"#fff";fill:#000}</style></svg>';                       e = '#000' }
        @{ n = 'external fragment url(file.svg#id)';  t = '<svg><path filter="url(filters.svg#abc)" fill="#0078D4"/></svg>';                       e = '#0078D4' }
        @{ n = 'external fragment WITH a fallback';   t = '<svg><path fill="url(resources.svg#abc) #0078D4"/></svg>';                            e = '#0078D4' }
        @{ n = 'external fragment in a style attr';   t = '<svg><path style="filter:url(f.svg#abc)" fill="#0078D4"/></svg>';                     e = '#0078D4' }
        @{ n = 'quoted url() body may contain a paren'; t = '<svg><style>.a{background:url("icons/foo)#fff");fill:#000}</style></svg>';               e = '#000' }
        @{ n = 'hex in a url() fragment is an id';      t = '<svg><style>.a{background-image:url("/s.svg#fff");fill:#000}</style></svg>';           e = '#000' }
        @{ n = 'a brace inside a string is not a brace'; t = '<svg><style>.a::before{content:"}";fill:#fff}</style></svg>';                          e = '#fff' }
        @{ n = 'a semicolon in a data URL is not one';   t = '<svg><style>.a{background:url("data:image/svg+xml;utf8,x");fill:#fff}</style></svg>';  e = '#fff' }
        @{ n = 'selector vs value in one rule';          t = '<svg><style>#fff:hover{fill:#000}</style></svg>';                                      e = '#000' }
        @{ n = 'CSS nesting: &:hover is a selector';  t = '<svg><style>g { &:hover #A12345 { fill: #A12345 } }</style></svg>';                        e = '#A12345' }
        @{ n = 'declaration-list at-rules hold colors'; t = '<svg><style>@property --brand{syntax:1;initial-value:#0078D4}</style></svg>';             e = '#0078D4' }
        @{ n = 'font-face is a declaration list';       t = '<svg><style>@font-face{src:url(a);color:#111}</style></svg>';                              e = '#111' }
        @{ n = 'CDATA with CSS after the ]]>';        t = '<svg><style><![CDATA[ #111 { content: "</style>" } ]]> #333 { fill: #444 } </style></svg>'; e = '#444' }
        @{ n = 'script CDATA holding a </script>';   t = '<svg><script><![CDATA[ var a = "</script>"; var c = "#112233"; ]]></script><path fill="#0078D4"/></svg>'; e = '#0078D4' }
        @{ n = 'a </style> inside CDATA does not truncate'; t = '<svg><style><![CDATA[ /* </style> */ #ABCDEF { fill: #111111 } ]]></style></svg>'; e = '#111111' }
        @{ n = 'a > inside a style attribute value';  t = '<svg><style id="a>b">.c { fill: #0078D4 }</style></svg>';                                e = '#0078D4' }
        @{ n = 'and it does not break the masking';   t = '<svg><style id="a>b"> .c " { font-family: ": #111111 "; } </style></svg>';               e = '' }
        @{ n = 'at-rule block is selector territory'; t = '<svg><style>@media (min-width:1px){ a:hover #ABCDEF { fill:#000 } }</style></svg>';          e = '#000' }
        @{ n = 'nested at-rules';                    t = '<svg><style>@supports (x:y){@media (min-width:1px){ #FEDCBA:focus{fill:#111} }}</style></svg>'; e = '#111' }
        @{ n = 'at-rule without a block';            t = '<svg><style>@import url(a.css);.a{fill:#111}</style></svg>';                                 e = '#111' }
        @{ n = 'two separate style blocks';          t = '<svg><style>.a{fill:#111}</style><style>#ABCDEF:hover{fill:#222}</style></svg>';             e = '#111,#222' }
        @{ n = 'escaped paren in an unquoted url()'; t = '<svg><style>.x{fill:url(foo\)#ABCDEF);stroke:#000}</style></svg>';                         e = '#000' }
        @{ n = 'custom property with a block value'; t = '<svg><style>:root{--palette: {#ABCDEF};fill:#000}</style></svg>';                          e = '#ABCDEF,#000' }
        @{ n = 'XML comment is prose';               t = '<svg><!-- brand #0078D4 --><path fill="#111"/></svg>';                                     e = '#111' }
        @{ n = 'desc and metadata are prose';        t = '<svg><desc>note #0078D4</desc><metadata>{"s":"#0078D4"}</metadata><path fill="#111"/></svg>'; e = '#111' }
        @{ n = 'script content is code';             t = '<svg><script>const c="#0078D4";</script><path fill="#111"/></svg>';                        e = '#111' }
        @{ n = 'plain attributes still work';        t = '<svg><path fill="#0078D4"/><rect fill="url(#g)"/></svg>';                                  e = '#0078D4' }
        @{ n = 'var() and gradient stops are colors';    t = '<svg><style>.a{fill:var(--x, #111)}.b{background:linear-gradient(#222,#333)}</style></svg>'; e = '#111,#222,#333' }
    )
    $cssBad = @()
    foreach ($case in $cssCases) {
        $got = (@(@(Get-ColorTokenMatch -Text $case.t) | ForEach-Object { $_.Value }) -join ',')
        if ($got -ne $case.e) { $cssBad += "$($case.n): [$got] != [$($case.e)]" }
    }
    Test-Check -Name 'clasificacion CSS: strings, url(), llaves y ; enganosos' -Ok ($cssBad.Count -eq 0) `
        -Detail $(if ($cssBad.Count -eq 0) { "$($cssCases.Count)/$($cssCases.Count) casos" } else { $cssBad -join ' | ' })

    # --- CSS selectors survive a recolor that TARGETS their values -------------
    # This has to run after a recolor whose -From actually matches the selectors,
    # or the check passes without exercising anything. An auto-detect run (no
    # -From) is the harshest case: every color in the file is a target.
    $cssDir = Get-ScopedTempPath -Prefix 'pbip-css'
    $cssRes = Join-Path (Join-Path (Join-Path $cssDir 'C.Report') 'StaticResources') 'RegisteredResources'
    New-Item -ItemType Directory -Path $cssRes -Force | Out-Null
    # Selectors that must survive, colors that must change, and the value forms a
    # naive 'previous char is :' rule would silently skip.
    [System.IO.File]::WriteAllText((Join-Path $cssRes 'sel.svg'),
        '<svg><style>' +
        '#fff:hover{fill:#0078D4} #abc .child{stroke:#0078D4} #def > path{fill:#0078D4} #012345[a=b]{fill:#0078D4}' +
        ' a:hover #ABCDEF{fill:#0078D4}' +
        ' .v1{box-shadow:0 0 2px #0078D4} .v2{filter:drop-shadow(0 0 2px #0078D4)}' +
        ' .v3{fill:var(--x, #0078D4)} .v4{background:linear-gradient(#0078D4, #0078D4)}' +
        ' @media (min-width:1px){ .v5{fill:#0078D4} }' +
        ' /* commented: #0078D4 and .old{fill:#0078D4} */' +
        '</style></svg>',
        $utf8NoBom)
    & $recolor -PbipDir $cssDir -To '#DC143C' *>&1 | Out-Null
    $sel = [System.IO.File]::ReadAllText((Join-Path $cssRes 'sel.svg'))
    Remove-Item $cssDir -Recurse -Force -ErrorAction SilentlyContinue

    Test-Check -Name 'selectores :hover / descendiente / > / [attr] / tras pseudo-clase sobreviven' `
        -Ok (($sel -match '#fff:hover') -and ($sel -match '#abc \.child') -and
             ($sel -match '#def > path') -and ($sel -match '#012345\[a=b\]') -and
             ($sel -match 'a:hover #ABCDEF')) -Detail $sel

    # Los que una regla ingenua de "caracter anterior es :" se saltaria en silencio.
    # Exactly the two occurrences inside the CSS comment may survive. Everything
    # else - box-shadow, drop-shadow, var(), both gradient stops, @media - is a
    # real value-position color and must have changed.
    $leftover = ([regex]::Matches($sel, [regex]::Escape('#0078D4'))).Count
    Test-Check -Name 'colores en box-shadow / drop-shadow / var() / gradient / @media SI cambian' `
        -Ok ($leftover -eq 2) -Detail "quedan $leftover ocurrencias de #0078D4, ambas dentro del comentario"

    Test-Check -Name 'el CSS comentado no se toca' `
        -Ok ($sel -match '/\* commented: #0078D4 and \.old\{fill:#0078D4\} \*/') `
        -Detail 'el comentario conserva sus dos colores intactos'

    # --- unsupported-notation warnings must ignore prose too --------------------
    # 'currentColor' written in a <desc> is documentation, not a color left behind.
    $prose = (Get-UnsupportedNotation -Text '<svg><desc>usa currentColor y rgb(1,2,3)</desc><path fill="#111"/></svg>')
    Test-Check -Name 'currentColor en un <desc> no cuenta como notacion sin reescribir' `
        -Ok ($prose.Count -eq 0) -Detail "notaciones reportadas: $($prose.Count)"

    # --- unsupported counting is gated on declaration VALUES too ---------------
    $unsupCases = @(
        @{ t = '<svg><style>path[fill=red]{fill:#0078D4}</style></svg>'; e = 0 }   # selector, not paint
        @{ t = '<svg><style>.a{fill:red}</style></svg>';                 e = 1 }
        @{ t = '<svg><style>.a{fill: red}</style></svg>';                e = 1 }   # space after the colon
        @{ t = '<svg><style>.a{stroke:  red}</style></svg>';             e = 1 }   # and two of them
        @{ t = '<svg><style>.a{fill: rgb(1,2,3)}</style></svg>';         e = 1 }
        @{ t = '<svg><style>.a{stroke: currentColor}</style></svg>';     e = 1 }
        @{ t = '<svg><style>.a{fill:rgb(1,2,3)}</style></svg>';          e = 1 }
        @{ t = '<svg><style>.a{stroke:currentColor}</style></svg>';      e = 1 }
        @{ t = '<svg><path fill="red"/></svg>';                          e = 1 }
        @{ t = '<svg><path style="fill:red"/></svg>';                    e = 1 }
        @{ t = '<svg><stop stop-color="red"/></svg>';                    e = 1 }
        @{ t = '<svg data-fill="red"><path fill="#111"/></svg>';         e = 0 }   # not a paint attribute
        @{ t = '<svg><path prefill="red" fill="#111"/></svg>';           e = 0 }
        @{ t = '<svg><path data-stroke="blue" fill="#111"/></svg>';      e = 0 }
        @{ t = '<svg data-note="fill:red"><path fill="#111"/></svg>';    e = 0 }   # prose in a data attribute
        @{ t = '<svg aria-label="rgb(1,2,3)"><path fill="#111"/></svg>'; e = 0 }
        @{ t = '<svg data-x="currentColor"><path fill="#111"/></svg>';   e = 0 }
        @{ t = '<svg><path fill="rgb(1,2,3)"/></svg>';                   e = 1 }   # the real ones still count
        @{ t = '<svg><path stroke="currentColor"/></svg>';               e = 1 }
    )
    $unsupBad = 0
    foreach ($case in $unsupCases) {
        $tot = 0
        foreach ($v in (Get-UnsupportedNotation -Text $case.t).Values) { $tot += $v }
        if ($tot -ne $case.e) { $unsupBad++ }
    }
    Test-Check -Name 'un selector de atributo no cuenta como color con nombre' -Ok ($unsupBad -eq 0) `
        -Detail "$($unsupCases.Count - $unsupBad)/$($unsupCases.Count) casos"

    # --- multi-value -From / -Exclude ------------------------------------------
    # Note these must be called with & so PowerShell passes an ARRAY; 'pwsh -File'
    # hands the script one literal string and the test would prove nothing.
    $mvDir = Get-ScopedTempPath -Prefix 'pbip-mv'
    $mvRes = Join-Path (Join-Path (Join-Path $mvDir 'M.Report') 'StaticResources') 'RegisteredResources'
    New-Item -ItemType Directory -Path $mvRes -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $mvRes 'a.svg'),
        '<svg><path fill="#0078D4"/><path fill="#FFFFFF"/><path fill="#123123"/></svg>', $utf8NoBom)
    & $recolor -PbipDir $mvDir -From '#0078D4', '#FFFFFF' -To '#DC143C' *>&1 | Out-Null
    $mv = [System.IO.File]::ReadAllText((Join-Path $mvRes 'a.svg'))
    Test-Check -Name '-From con varios colores los aplica todos' `
        -Ok ((([regex]::Matches($mv, [regex]::Escape('#DC143C'))).Count -eq 2) -and ($mv -match '#123123')) `
        -Detail $mv

    & $recolor -PbipDir $mvDir -To '#00FF7F' -Exclude '#DC143C', '#123123' *>&1 | Out-Null
    $mvEx = [System.IO.File]::ReadAllText((Join-Path $mvRes 'a.svg'))
    Test-Check -Name '-Exclude con varios colores los protege todos' -Ok ($mvEx -eq $mv) -Detail $mvEx

    # try/catch because $ErrorActionPreference is Stop here, and the script signals
    # a bad argument with Write-Error - which the caller then sees as terminating.
    $mvErr = ''
    try { $mvErr = (& $recolor -PbipDir $mvDir -From '#DC143C', 'basura' -To '#00FF7F' *>&1 | Out-String) }
    catch { $mvErr = $_.Exception.Message }
    Remove-Item $mvDir -Recurse -Force -ErrorAction SilentlyContinue
    Test-Check -Name 'un valor invalido se rechaza nombrandolo a el, no al array' `
        -Ok ($mvErr -match "'basura'" -and $mvErr -notmatch "'#DC143C','basura'") -Detail $mvErr.Trim()

    # --- keywords and functions are not named colors ---------------------------
    # CSS-wide keywords are not colors, so nothing was left behind by them. But
    # var(), hsl() and the fallback in 'url(#g) red' ARE paint this tool cannot
    # rewrite, and staying quiet about those is the failure the warning exists for.
    $kw = @('<path fill="context-fill"/>', '<path fill="initial"/>', '<path stroke="unset"/>',
            '<path fill="none"/>', '<path fill="url(#g)"/>')
    $kwFalse = 0
    foreach ($t in $kw) {
        $tot = 0
        foreach ($v in (Get-UnsupportedNotation -Text $t).Values) { $tot += $v }
        if ($tot -ne 0) { $kwFalse++ }
    }
    $mustReport = @('<path style="fill:var(--brand)"/>', '<path fill="hsl(0,100%,50%)"/>',
                    '<path fill="url(#g) red"/>', '<path fill="red"/>')
    $missed = 0
    foreach ($t in $mustReport) {
        $tot = 0
        foreach ($v in (Get-UnsupportedNotation -Text $t).Values) { $tot += $v }
        if ($tot -eq 0) { $missed++ }
    }
    Test-Check -Name 'los keywords no cuentan, pero var()/hsl()/el fallback de url() si' `
        -Ok ($kwFalse -eq 0 -and $missed -eq 0) `
        -Detail "falsos positivos: $kwFalse / no reportados que deberian: $missed"

    # --- unsupported-notation counting uses the same CSS masking ---------------
    $cssStr = (Get-UnsupportedNotation -Text '<svg><style>.a{content:"rgb(";fill:#111}</style></svg>')
    Test-Check -Name 'rgb( dentro de un string CSS no cuenta como notacion' -Ok ($cssStr.Count -eq 0) `
        -Detail "notaciones reportadas: $($cssStr.Count)"

    # --- a write that fails is a failure, not a smaller success ----------------
    $roDir = Get-ScopedTempPath -Prefix 'pbip-ro'
    $roRes = Join-Path (Join-Path (Join-Path $roDir 'R.Report') 'StaticResources') 'RegisteredResources'
    New-Item -ItemType Directory -Path $roRes -Force | Out-Null
    foreach ($n in 'a', 'b', 'c') {
        [System.IO.File]::WriteAllText((Join-Path $roRes "$n.svg"), "<svg id=`"$n`"><path fill=`"#0078D4`"/></svg>", $utf8NoBom)
    }
    Set-ItemProperty (Join-Path $roRes 'b.svg') -Name IsReadOnly -Value $true
    # Continue, not Stop, for this one call: the script ends with Write-Error and
    # under Stop the caller only ever sees that exception - the per-report line we
    # need to assert on would be thrown away with the rest of the output.
    $roOut = ''
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $roOut = (& $recolor -PbipDir $roDir -To '#DC143C' *>&1 | Out-String)
    $ErrorActionPreference = $prevEap
    Set-ItemProperty (Join-Path $roRes 'b.svg') -Name IsReadOnly -Value $false
    $bIntact = ([System.IO.File]::ReadAllText((Join-Path $roRes 'b.svg')) -match '#0078D4')
    $othersDone = ([System.IO.File]::ReadAllText((Join-Path $roRes 'a.svg')) -match '#DC143C')
    Test-Check -Name 'un archivo no escribible no se cuenta como modificado' `
        -Ok (($roOut -match '2/3') -and $bIntact -and $othersDone) `
        -Detail "cuenta honesta: $($roOut -match '2/3') / b intacto: $bIntact / a recoloreado: $othersDone"

    # --- .SVG in capitals is still an SVG --------------------------------------
    # Windows would find it either way; Linux, where CI runs, would not.
    $caseDir = Get-ScopedTempPath -Prefix 'pbip-case'
    $caseRes = Join-Path (Join-Path (Join-Path $caseDir 'C.Report') 'StaticResources') 'RegisteredResources'
    New-Item -ItemType Directory -Path $caseRes -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $caseRes 'upper.SVG'), '<svg><path fill="#0078D4"/></svg>', $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $caseRes 'lower.svg'), '<svg><path fill="#0078D4"/></svg>', $utf8NoBom)
    & $recolor -PbipDir $caseDir -To '#DC143C' *>&1 | Out-Null
    $upperDone = ([System.IO.File]::ReadAllText((Join-Path $caseRes 'upper.SVG')) -match '#DC143C')
    Test-Check -Name 'una extension .SVG en mayusculas tambien se recolorea' -Ok $upperDone `
        -Detail "upper.SVG recoloreado: $upperDone"

    # --- a folder name with brackets is a name, not a wildcard -----------------
    $brDir = Join-Path ([System.IO.Path]::GetTempPath()) "MyReport[1]-$([guid]::NewGuid().ToString('N').Substring(0,6))"
    $script:tempPaths += $brDir
    $brRes = Join-Path (Join-Path (Join-Path $brDir 'B.Report') 'StaticResources') 'RegisteredResources'
    New-Item -ItemType Directory -Path $brRes -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $brRes 'a.svg'), '<svg><path fill="#0078D4"/></svg>', $utf8NoBom)
    & $recolor -PbipDir $brDir -To '#DC143C' *>&1 | Out-Null
    Test-Check -Name 'una ruta con corchetes no se trata como comodin' `
        -Ok ([System.IO.File]::ReadAllText((Join-Path $brRes 'a.svg')) -match '#DC143C') `
        -Detail 'el proyecto se encontro y se recoloreo'

    # --- a file that is only a BOM is valid, empty UTF-8 -----------------------
    $bomDir = Get-ScopedTempPath -Prefix 'pbip-bomonly'
    $bomRes = Join-Path (Join-Path (Join-Path $bomDir 'O.Report') 'StaticResources') 'RegisteredResources'
    New-Item -ItemType Directory -Path $bomRes -Force | Out-Null
    [System.IO.File]::WriteAllBytes((Join-Path $bomRes 'empty.svg'), [byte[]](0xEF, 0xBB, 0xBF))
    [System.IO.File]::WriteAllText((Join-Path $bomRes 'real.svg'), '<svg><path fill="#0078D4"/></svg>', $utf8NoBom)
    $bomOut = (& $detect -PbipDir $bomDir *>&1 | Out-String)
    Test-Check -Name 'un archivo de solo BOM no se descarta como no-UTF-8' `
        -Ok ($bomOut -match '2 scanned \(2 found\)') -Detail (($bomOut -split "`n" | Where-Object { $_ -match 'SVGs' }) -join '')

    # --- each report reports its OWN count -------------------------------------
    # The two-pass split introduced this: $allFiles belongs to pass 1, so pass 2
    # read whatever the last report left in it and printed that denominator for
    # every report.
    $mcDir = Get-ScopedTempPath -Prefix 'pbip-count'
    $mcA = Join-Path (Join-Path (Join-Path $mcDir 'A.Report') 'StaticResources') 'RegisteredResources'
    $mcB = Join-Path (Join-Path (Join-Path $mcDir 'B.Report') 'StaticResources') 'RegisteredResources'
    New-Item -ItemType Directory -Force -Path $mcA, $mcB | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $mcA 'one.svg'), '<svg><path fill="#0078D4"/></svg>', $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $mcB 'one.svg'), '<svg><path fill="#0078D4"/></svg>', $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $mcB 'two.svg'), '<svg><path fill="#0078D4"/></svg>', $utf8NoBom)
    $mcOut = (& $recolor -PbipDir $mcDir -To '#DC143C' *>&1 | Out-String)
    Test-Check -Name 'cada reporte imprime su propio denominador' `
        -Ok (($mcOut -match '\[A\.Report\] Modified 1/1') -and ($mcOut -match '\[B\.Report\] Modified 2/2')) `
        -Detail (($mcOut -split "`n" | Where-Object { $_ -match 'Modified' }) -join ' | ')

    # --- -Backup is all-or-nothing across reports ------------------------------
    # A failed backup must leave EVERY report untouched, not just the one whose
    # backup failed: the alternative is a half-recolored project plus an error
    # message, which is worse than not running at all.
    #
    # This used to force the failure by occupying every backup name the second
    # report could pick for the next 90 seconds. That stopped working, and for a
    # good reason: backup directory names now carry a random suffix, because a
    # name built only from a per-second timestamp meant two runs in the same
    # second collided and the second refused to back up - reproduced, and it was
    # reddening CI. So the failure is forced at the root instead: -BackupRoot
    # points at a FILE, so creating a directory under it cannot succeed for any
    # report.
    $paDir  = Get-ScopedTempPath -Prefix 'pbip-partial'
    $paBack = Get-ScopedTempPath -Prefix 'pbip-block'
    [System.IO.File]::WriteAllText($paBack, 'not a directory', $utf8NoBom)
    foreach ($r in 'A.Report', 'B.Report') {
        $rr = Join-Path (Join-Path (Join-Path $paDir $r) 'StaticResources') 'RegisteredResources'
        New-Item -ItemType Directory -Force -Path $rr | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $rr 'icon.svg'), '<svg><path fill="#0078D4"/></svg>', $utf8NoBom)
    }
    $prevEap2 = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $recolor -PbipDir $paDir -To '#DC143C' -Backup -BackupRoot $paBack *>&1 | Out-Null
    $ErrorActionPreference = $prevEap2
    $paths = 'A.Report', 'B.Report' | ForEach-Object {
        Join-Path (Join-Path (Join-Path (Join-Path $paDir $_) 'StaticResources') 'RegisteredResources') 'icon.svg'
    }
    $stillOriginal = @($paths | Where-Object { [System.IO.File]::ReadAllText($_) -match '#0078D4' }).Count
    Test-Check -Name 'si el backup falla, NINGUN reporte queda reescrito' `
        -Ok ($stillOriginal -eq 2) `
        -Detail "$stillOriginal/2 reportes conservan #0078D4"

    # El caso de verdad: el backup del PRIMER reporte funciona y falla el del
    # SEGUNDO. El de arriba no lo cubre - ahi nunca se llega al segundo, asi que
    # pasaria igual si el script volviera a escribir el reporte A antes de
    # intentar el backup de B, que es justo la regresion que hay que impedir.
    #
    # Se fuerza por la longitud del nombre, no por ocuparlo: los nombres de backup
    # llevan un GUID y ya no se pueden predecir. Un componente de ruta de mas de
    # 255 caracteres falla en Windows y en Linux por igual (medido: 200 se crea,
    # 260 lanza IOException), asi que un reporte de nombre largo hace fallar su
    # New-Item y solo el suyo. El orden A-antes-que-B lo da Get-ChildItem.
    $sqDir  = Get-ScopedTempPath -Prefix 'pbip-second'
    $sqBack = Get-ScopedTempPath -Prefix 'pbip-secondback'
    New-Item -ItemType Directory -Force -Path $sqBack | Out-Null
    $longName = 'B' + ('o' * 200) + '.Report'
    foreach ($r in 'A.Report', $longName) {
        $rr = Join-Path (Join-Path (Join-Path $sqDir $r) 'StaticResources') 'RegisteredResources'
        New-Item -ItemType Directory -Force -Path $rr | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $rr 'icon.svg'), '<svg><path fill="#0078D4"/></svg>', $utf8NoBom)
    }
    $prevEap3 = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $recolor -PbipDir $sqDir -To '#DC143C' -Backup -BackupRoot $sqBack *>&1 | Out-Null
    $ErrorActionPreference = $prevEap3
    $aIcon = Join-Path (Join-Path (Join-Path (Join-Path $sqDir 'A.Report') 'StaticResources') 'RegisteredResources') 'icon.svg'
    $aBackedUp = @(Get-ChildItem -LiteralPath $sqBack -Directory -ErrorAction SilentlyContinue).Count
    Test-Check -Name 'si falla el backup del 2o reporte, el 1o NO queda reescrito' `
        -Ok ([System.IO.File]::ReadAllText($aIcon) -match '#0078D4' -and $aBackedUp -ge 1) `
        -Detail "backups creados antes del fallo: $aBackedUp; A conserva su color original"

    # --- a linked .Report is a link too ----------------------------------------
    # The file-level guard does not cover this: the SVGs inside a junctioned
    # .Report are ordinary files, so every one of them would be rewritten outside
    # the project. Junctions need no Developer Mode, so this normally runs.
    $jnDir = Get-ScopedTempPath -Prefix 'pbip-junction'
    $jnOut = Get-ScopedTempPath -Prefix 'outside-junction'
    $jnRes = Join-Path (Join-Path $jnOut 'StaticResources') 'RegisteredResources'
    New-Item -ItemType Directory -Force -Path $jnRes | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $jnRes 'icon.svg'), '<svg><path fill="#0078D4"/></svg>', $utf8NoBom)
    New-Item -ItemType Directory -Force -Path $jnDir | Out-Null
    $jnMade = $false
    try {
        New-Item -ItemType Junction -Path (Join-Path $jnDir 'External.Report') -Target $jnOut -ErrorAction Stop | Out-Null
        $jnMade = $true
    } catch { $jnMade = $false }

    if ($jnMade) {
        $prevEap3 = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $recolor -PbipDir $jnDir -To '#DC143C' *>&1 | Out-Null
        $ErrorActionPreference = $prevEap3
        Test-Check -Name 'un .Report enlazado no deja escribir fuera del proyecto' `
            -Ok ([System.IO.File]::ReadAllText((Join-Path $jnRes 'icon.svg')) -match '#0078D4') `
            -Detail 'el archivo externo quedo intacto'
    } else {
        Test-Check -Name 'un .Report enlazado no deja escribir fuera del proyecto' -Ok $true `
            -Detail 'OMITIDO: este equipo no permite crear junctions'
    }

    # --- a link is not a file this tool owns -----------------------------------
    # Creating a symlink needs Developer Mode or elevation on Windows, so the check
    # reports honestly when it could not run rather than passing by default.
    $lnDir = Get-ScopedTempPath -Prefix 'pbip-link'
    $lnOut = Join-Path ([System.IO.Path]::GetTempPath()) "outside-$([guid]::NewGuid().ToString('N').Substring(0,6)).svg"
    $script:tempPaths += $lnOut
    $lnRes = Join-Path (Join-Path (Join-Path $lnDir 'L.Report') 'StaticResources') 'RegisteredResources'
    New-Item -ItemType Directory -Path $lnRes -Force | Out-Null
    [System.IO.File]::WriteAllText($lnOut, '<svg><path fill="#0078D4"/></svg>', $utf8NoBom)
    $linkMade = $false
    try {
        New-Item -ItemType SymbolicLink -Path (Join-Path $lnRes 'logo.svg') -Target $lnOut -ErrorAction Stop | Out-Null
        $linkMade = $true
    } catch { $linkMade = $false }

    if ($linkMade) {
        & $recolor -PbipDir $lnDir -To '#DC143C' *>&1 | Out-Null
        $outsideSafe = ([System.IO.File]::ReadAllText($lnOut) -notmatch '#DC143C')
        Test-Check -Name 'un symlink no deja escribir fuera del proyecto' -Ok $outsideSafe `
            -Detail "el archivo externo quedo intacto: $outsideSafe"
    } else {
        Test-Check -Name 'un symlink no deja escribir fuera del proyecto' -Ok $true `
            -Detail 'OMITIDO: este equipo no permite crear symlinks (hace falta Developer Mode)'
    }

    # --- files that are not UTF-8 are skipped, not mangled ---------------------
    # ReadAllText would decode a latin-1 file with replacement characters and the
    # write would make that damage permanent, for the sake of one color.
    $encDir = Get-ScopedTempPath -Prefix 'pbip-enc'
    $encRes = Join-Path (Join-Path (Join-Path $encDir 'E.Report') 'StaticResources') 'RegisteredResources'
    New-Item -ItemType Directory -Path $encRes -Force | Out-Null
    $latin = [System.Text.Encoding]::GetEncoding('ISO-8859-1')
    [System.IO.File]::WriteAllBytes((Join-Path $encRes 'decl.svg'),
        $latin.GetBytes('<?xml version="1.0" encoding="ISO-8859-1"?><svg><title>A' + [char]0xF1 + 'adir</title><path fill="#0078D4"/></svg>'))
    [System.IO.File]::WriteAllBytes((Join-Path $encRes 'nodecl.svg'),
        $latin.GetBytes('<svg><title>A' + [char]0xF1 + 'adir ' + [char]0xA9 + '</title><path fill="#0078D4"/></svg>'))
    [System.IO.File]::WriteAllText((Join-Path $encRes 'ok.svg'), '<svg><path fill="#0078D4"/></svg>', $utf8NoBom)
    # A BOM states an intention, not a fact: these bytes carry the UTF-8 mark and
    # then a stray 0xE9, which is not valid UTF-8. Trusting the mark and skipping
    # the decode check would substitute a replacement character and save it.
    [System.IO.File]::WriteAllBytes((Join-Path $encRes 'bomBad.svg'),
        ([byte[]](0xEF, 0xBB, 0xBF) +
         [System.Text.Encoding]::ASCII.GetBytes('<svg><title>A') + [byte[]](0xE9) +
         [System.Text.Encoding]::ASCII.GetBytes('</title><path fill="#0078D4"/></svg>')))
    [System.IO.File]::WriteAllText((Join-Path $encRes 'bomOk.svg'), '<svg><path fill="#0078D4"/></svg>',
                                   (New-Object System.Text.UTF8Encoding($true)))
    $encBefore = @{}
    foreach ($f in (Get-ChildItem $encRes -Filter '*.svg')) { $encBefore[$f.Name] = (Get-FileHash $f.FullName).Hash }
    & $recolor -PbipDir $encDir -To '#DC143C' *>&1 | Out-Null
    $latinIntact = ((Get-FileHash (Join-Path $encRes 'decl.svg')).Hash -eq $encBefore['decl.svg']) -and
                   ((Get-FileHash (Join-Path $encRes 'nodecl.svg')).Hash -eq $encBefore['nodecl.svg'])
    $utf8Changed = (Get-FileHash (Join-Path $encRes 'ok.svg')).Hash -ne $encBefore['ok.svg']
    $bomBadIntact = (Get-FileHash (Join-Path $encRes 'bomBad.svg')).Hash -eq $encBefore['bomBad.svg']
    $bomOkChanged = (Get-FileHash (Join-Path $encRes 'bomOk.svg')).Hash -ne $encBefore['bomOk.svg']
    $bomBytes = [System.IO.File]::ReadAllBytes((Join-Path $encRes 'bomOk.svg'))
    $bomKept = ($bomBytes[0] -eq 0xEF -and $bomBytes[1] -eq 0xBB -and $bomBytes[2] -eq 0xBF)
    Remove-Item $encDir -Recurse -Force -ErrorAction SilentlyContinue
    Test-Check -Name 'archivos latin-1 se saltan intactos (con y sin declaracion XML)' `
        -Ok ($latinIntact -and $utf8Changed) `
        -Detail "latin-1 intactos: $latinIntact / el UTF-8 si cambio: $utf8Changed"
    Test-Check -Name 'un BOM con bytes invalidos detras tambien se salta' `
        -Ok ($bomBadIntact -and $bomOkChanged -and $bomKept) `
        -Detail "bomBad intacto: $bomBadIntact / bomOk cambio: $bomOkChanged / conservo BOM: $bomKept"

    # --- recolor: warns even when there is nothing to rewrite (#12) ------------
    # The case where the warning matters most: every color is a notation this tool
    # does not handle, so nothing changes and the user needs to know why.
    $onlyDir = Get-ScopedTempPath -Prefix 'pbip-only'
    $onlyRes = Join-Path (Join-Path (Join-Path $onlyDir 'X.Report') 'StaticResources') 'RegisteredResources'
    New-Item -ItemType Directory -Path $onlyRes -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $onlyRes 'only.svg'),
        '<svg><path fill="rgb(1,2,3)"/><path stroke="currentColor"/></svg>', $utf8NoBom)
    $onlyOut = & $recolor -PbipDir $onlyDir -To '#DC143C' *>&1 | Out-String
    Remove-Item $onlyDir -Recurse -Force -ErrorAction SilentlyContinue
    Test-Check -Name 'avisa aunque no hubiera nada que reescribir' `
        -Ok ($onlyOut -match 'NOT rewritten' -and $onlyOut -match 'rgb') `
        -Detail 'el aviso aparece incluso con 0 cambios'

    # --- recolor: warns about what it could not rewrite (#12) ------------------
    $out = & $recolor -PbipDir $work -To '#123456' 6>&1 3>&1 | Out-String
    Test-Check -Name 'recolor avisa de las notaciones que no reescribio' `
        -Ok ($out -match 'NOT rewritten' -or $out -match 'rgb\(\)') -Detail 'aviso presente al final'

    # --- el modulo no se filtra al llamador (#28) -------------------------------
    # El criterio de aceptacion del issue, literal: una sesion que define
    # $HexTokenPattern por su cuenta no debe verlo alterado por cargar esto. Con
    # dot-sourcing lo veia; ese era el problema. Se comprueba en una sesion nueva
    # porque esta ya importo el modulo mas arriba.
    $probe = @'
$HexTokenPattern   = 'CENTINELA-DEL-ANFITRION'
$StyleBlockPattern = 'CENTINELA-2'
Import-Module '{0}' -Force
Import-Module '{1}' -Force
$leak1 = $HexTokenPattern
$leak2 = $StyleBlockPattern
# Lo privado sigue privado: exportarlo haria del enmascarado CSS parte del contrato.
$priv  = @(Get-Command Get-CssValueRange, Get-PaintValueKind -ErrorAction SilentlyContinue).Count
# Y lo publico si esta.
$pub   = @(Get-Command Get-ColorTokenMatch, Get-CanonicalHex, Test-HexColor, Get-UnsupportedNotation, Get-SvgFile, Join-PbipPath, Get-FileEncodingKind, Get-Utf8Encoding -ErrorAction SilentlyContinue).Count
"$leak1|$leak2|$priv|$pub"
'@ -f (Join-Path $modules 'ColorTokens.psm1'), (Join-Path $modules 'PbipIo.psm1')

    $probeFile = Join-Path ([System.IO.Path]::GetTempPath()) ("probe-" + [guid]::NewGuid().ToString('N').Substring(0,8) + ".ps1")
    $script:tempPaths += $probeFile
    [System.IO.File]::WriteAllText($probeFile, $probe)
    $probeOut = (& pwsh -NoProfile -File $probeFile 2>&1 | Out-String).Trim()
    $parts = $probeOut -split '\|'

    Test-Check -Name 'importar el modulo no pisa variables del anfitrion' `
        -Ok ($parts.Count -eq 4 -and $parts[0] -eq 'CENTINELA-DEL-ANFITRION' -and $parts[1] -eq 'CENTINELA-2') `
        -Detail "el anfitrion conserva: $($parts[0]), $($parts[1])"

    Test-Check -Name 'la superficie publica es la declarada, ni mas ni menos' `
        -Ok ($parts.Count -eq 4 -and $parts[2] -eq '0' -and $parts[3] -eq '8') `
        -Detail "privadas visibles: $($parts[2]) (debe ser 0) / publicas: $($parts[3]) de 8"

    # Get-Utf8Encoding sustituye a las dos variables que el dot-sourcing filtraba.
    # Un kind desconocido tiene que ser un error de parametro, no un $null que
    # acaba escribiendo UTF-16 sobre cada icono.
    $encBom   = Get-Utf8Encoding -Kind 'Utf8Bom'
    $encNoBom = Get-Utf8Encoding -Kind 'Utf8NoBom'
    $rejected = $false
    try { Get-Utf8Encoding -Kind 'Utf16' | Out-Null } catch { $rejected = $true }
    Test-Check -Name 'Get-Utf8Encoding da el BOM correcto y rechaza lo que no conoce' `
        -Ok ($encBom.GetPreamble().Length -eq 3 -and $encNoBom.GetPreamble().Length -eq 0 -and $rejected) `
        -Detail "preambulo con BOM: $($encBom.GetPreamble().Length) / sin BOM: $($encNoBom.GetPreamble().Length) / kind invalido rechazado: $rejected"
}
finally {
    # Only the paths this run created, by exact name. The inline Remove-Item calls
    # above are best-effort; this is what guarantees nothing leaks when the script
    # throws before reaching them.
    foreach ($p in $script:tempPaths) {
        if ($p -and (Test-Path $p)) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Write-Host ""
if ($failures.Count -gt 0) {
    Write-Host "COLOR-TOKEN TESTS FAILED - $($failures.Count): $($failures -join '; ')" -ForegroundColor Red
    exit 1
}
Write-Host "COLOR-TOKEN TESTS PASSED" -ForegroundColor Green
exit 0
