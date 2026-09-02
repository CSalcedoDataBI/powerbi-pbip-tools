---
name: SVG Recolor for Power BI
description: Cambia el color de los iconos SVG de un proyecto PBIP sin tocar nada más — detecta qué colores hay, sustituye solo los que son colores de verdad (no referencias `url(#id)` ni selectores CSS), conserva la codificación de cada archivo y avisa de lo que no puede reescribir.
---

# SVG Recolor for Power BI

> 🇬🇧 [English version → SKILL.en.md](SKILL.en.md)

Los iconos de un informe de Power BI viven como `.svg` sueltos dentro del proyecto PBIP. Cambiar la paleta a mano significa abrir decenas o cientos de archivos. Esta skill hace dos cosas: **decir qué colores hay** y **cambiarlos**, con la promesa de que no toca nada más del archivo.

## Clonar solo esta skill

```bash
git clone --filter=blob:none --sparse https://github.com/CSalcedoDataBI/powerbi-pbip-tools.git
cd powerbi-pbip-tools
git sparse-checkout set skills/skill-svg-recolor-powerbi
```

## Flujo

Siempre en este orden. `detect` primero, porque `-From` sin saber qué hay dentro es adivinar.

```
detect-colors.ps1  →  recolor.ps1 -WhatIf  →  recolor.ps1 -Backup
   ¿qué hay?            ¿qué cambiaría?         hacerlo
```

### 1. Ver qué colores hay

```powershell
.\scripts\detect-colors.ps1 -PbipDir "C:\MiProyecto"
```

```
SVGs   : 184 scanned (184 found)
Colors : 1 unique hex colors found

  #0078D4  (184 files)
```

Con `-PassThru` devuelve objetos (`Report`, `Color`, `FileCount`) en vez de texto, para encadenarlo con otro script.

### 2. Ver qué cambiaría, sin cambiarlo

```powershell
.\scripts\recolor.ps1 -PbipDir "C:\MiProyecto" -From "#0078D4" -To "#DC143C" -WhatIf
```

### 3. Hacerlo

```powershell
.\scripts\recolor.ps1 -PbipDir "C:\MiProyecto" -From "#0078D4" -To "#DC143C" -Backup
```

## Parámetros

### `detect-colors.ps1`

| Parámetro | Tipo | Qué hace |
|---|---|---|
| `-PbipDir` | obligatorio | Carpeta del proyecto PBIP. Se recorren **todas** las carpetas `.Report` que contenga |
| `-PassThru` | switch | Emite objetos en vez de imprimir un informe |

### `recolor.ps1`

| Parámetro | Tipo | Qué hace |
|---|---|---|
| `-PbipDir` | obligatorio | Carpeta del proyecto PBIP |
| `-To` | obligatorio | Color destino. `#RGB`, `#RGBA`, `#RRGGBB` o `#RRGGBBAA` |
| `-From` | lista | Solo estos colores. Sin `-From`, se sustituye **todo** color detectado |
| `-Exclude` | lista | Colores que no se tocan. Gana sobre `-From` |
| `-Backup` | switch | Copia los SVG antes de escribir |
| `-BackupRoot` | ruta | Dónde va la copia. Por defecto **fuera** del proyecto, para que no acabe siendo entrada del siguiente escaneo |
| `-WhatIf` | switch | No escribe nada; informa de lo que haría |

Un hex inválido se rechaza antes de tocar un archivo. `#0078D4` y `#0078D480` **no** son el mismo color: el segundo lleva alfa, y sustituir uno por otro cambiaría la opacidad del icono.

## Alcance y límites

Esta es la parte que conviene leer antes de usarla en algo que importe.

### Qué garantiza

- **Atributos de presentación** en SVG de iconos: `fill`, `stroke`, `stop-color`, `flood-color`, `lighting-color`, tanto como atributo (`fill="#0078D4"`) como dentro de `style="..."`.
- **Las cuatro formas hex**: `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`. Un color de 8 dígitos no se reescribe como uno de 6 dejando el alfa colgando.
- **La codificación se conserva**: un archivo con BOM sale con BOM; uno sin BOM sale sin BOM. UTF-16 y cualquier cosa que no decodifique como UTF-8 válido se **omite**, no se adivina.
- **No confunde un color con algo que lo parece**: `url(#fff)`, `href="#a"`, `href=&quot;#a&quot;`, `url(otro.svg#id)` y los selectores CSS de id (`<style>#fff{...}</style>`) no son colores y no se tocan.

### Qué no hace, y avisa

Al terminar, ambos scripts listan las notaciones que encontraron y **no** pueden reescribir:

- `rgb()`, `hsl()`, `var(--x)`, `currentColor` y los nombres CSS (`red`, `steelblue`)
- el *fallback* de una pintura: en `fill="url(#g) red"`, el `red` de reserva

Aparecen en el aviso final para que sepas que existen, en vez de que el conteo diga "184/184" y el icono siga azul.

### El techo del enfoque, en claro

La herramienta decide qué es un color **haciendo coincidir texto**, no analizando la gramática del documento. En SVG, un `#` introduce al menos cuatro cosas distintas: un color, una referencia a un fragmento (del mismo documento o de otro), un selector CSS de id, y texto que casualmente contiene uno. Distinguirlas de verdad exige entender XML, luego CSS dentro de `<style>`, luego sintaxis de valores CSS dentro de una declaración.

`ColorTokens.psm1` implementa una aproximación hecha a mano de las tres. Funciona para todo lo medido — 16 construcciones distintas, cada una con un test que falla si se revierte su arreglo — y **la lista no convergió**: cada ronda de revisión que cambiaba de ángulo encontraba una construcción nueva.

De ahí el contrato de arriba: **atributos de presentación en SVG de iconos de Power BI**. Ninguno de los 184 SVG de `examples/` tiene un bloque `<style>`, una sección CDATA, un `hsl()` ni una referencia a un fragmento externo. La herramienta los maneja igualmente, pero eso es robustez de más, no el terreno para el que se diseñó.

**Antes de añadir un caso especial nuevo a los patrones, lee [el issue #29](https://github.com/CSalcedoDataBI/powerbi-pbip-tools/issues/29).** Tiene la tabla de las 16 construcciones y las dos salidas posibles (parsear XML de verdad, o estrechar el contrato). Añadir el número diecisiete sin esa lectura es repetir la ronda anterior.

## Estructura

```
skill-svg-recolor-powerbi/
├── SKILL.md          ← este archivo
├── SKILL.en.md
├── README.md         ← guía larga con ejemplos
├── modules/
│   ├── ColorTokens.psm1   qué es un color
│   └── PbipIo.psm1        dónde están los SVG y cómo están codificados
└── scripts/
    ├── detect-colors.ps1
    └── recolor.ps1
```

Los módulos se cargan con `Import-Module`, no con dot-sourcing: su estado no se filtra al scope de quien los llama, y su superficie pública está declarada con `Export-ModuleMember`.

## Requisitos

PowerShell 5.1 o superior. Sin dependencias externas.

## Verificación

```powershell
pwsh tests/smoke-test.ps1          # contra una copia del Demo real (184 SVG)
pwsh tests/color-tokens-test.ps1   # las construcciones raras, una a una
```
