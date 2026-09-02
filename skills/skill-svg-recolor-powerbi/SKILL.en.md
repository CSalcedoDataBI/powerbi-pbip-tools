---
name: SVG Recolor for Power BI
description: Change the colour of the SVG icons in a PBIP project without touching anything else — report what colours are there, replace only what is genuinely a colour (not `url(#id)` references or CSS id selectors), preserve each file's encoding, and say what it could not rewrite.
---

# SVG Recolor for Power BI

> 🇪🇸 [Versión en español → SKILL.md](SKILL.md)

The icons in a Power BI report live as loose `.svg` files inside the PBIP project. Changing the palette by hand means opening dozens or hundreds of them. This skill does two things: **say which colours are there** and **change them**, with the promise that it touches nothing else in the file.

## Clone only this skill

```bash
git clone --filter=blob:none --sparse https://github.com/CSalcedoDataBI/powerbi-pbip-tools.git
cd powerbi-pbip-tools
git sparse-checkout set skills/skill-svg-recolor-powerbi
```

## The flow

Always in this order. `detect` first, because `-From` without knowing what is inside is guessing.

```
detect-colors.ps1  →  recolor.ps1 -WhatIf  →  recolor.ps1 -Backup
   what is there?      what would change?       do it
```

### 1. See what colours are there

```powershell
.\scripts\detect-colors.ps1 -PbipDir "C:\MyProject"
```

```
SVGs   : 184 scanned (184 found)
Colors : 1 unique hex colors found

  #0078D4  (184 files)
```

`-PassThru` returns objects (`Report`, `Color`, `FileCount`) instead of text, to pipe into something else.

### 2. See what would change, without changing it

```powershell
.\scripts\recolor.ps1 -PbipDir "C:\MyProject" -From "#0078D4" -To "#DC143C" -WhatIf
```

### 3. Do it

```powershell
.\scripts\recolor.ps1 -PbipDir "C:\MyProject" -From "#0078D4" -To "#DC143C" -Backup
```

## Parameters

### `detect-colors.ps1`

| Parameter | Type | What it does |
|---|---|---|
| `-PbipDir` | required | PBIP project folder. **Every** `.Report` folder inside is scanned |
| `-PassThru` | switch | Emit objects instead of printing a report |

### `recolor.ps1`

| Parameter | Type | What it does |
|---|---|---|
| `-PbipDir` | required | PBIP project folder |
| `-To` | required | Target colour. `#RGB`, `#RGBA`, `#RRGGBB` or `#RRGGBBAA` |
| `-From` | list | Only these colours. Without `-From`, **every** detected colour is replaced |
| `-Exclude` | list | Colours to leave alone. Wins over `-From` |
| `-Backup` | switch | Copy the SVGs before writing |
| `-BackupRoot` | path | Where the copy goes. Defaults **outside** the project, so it does not become an input to the next scan |
| `-WhatIf` | switch | Writes nothing; reports what it would do |

An invalid hex is rejected before a single file is touched. `#0078D4` and `#0078D480` are **not** the same colour: the second carries alpha, and swapping one for the other would change the icon's opacity.

## Scope and limits

This is the part worth reading before using it on something that matters.

### What it guarantees

- **Presentation attributes** on icon SVGs: `fill`, `stroke`, `stop-color`, `flood-color`, `lighting-color` — both as attributes (`fill="#0078D4"`) and inside `style="..."`.
- **All four hex forms**: `#RGB`, `#RGBA`, `#RRGGBB`, `#RRGGBBAA`. An 8-digit colour is never rewritten as a 6-digit one with the alpha left dangling.
- **Encoding survives**: a file with a BOM leaves with a BOM; one without leaves without. UTF-16, and anything that does not decode as valid UTF-8, is **skipped** rather than guessed at.
- **It does not mistake a colour for something that looks like one**: `url(#fff)`, `href="#a"`, `href=&quot;#a&quot;`, `url(other.svg#id)` and CSS id selectors (`<style>#fff{...}</style>`) are not colours and are left alone.

### What it does not do, and says so

On finishing, both scripts list the notations they found and **cannot** rewrite:

- `rgb()`, `hsl()`, `var(--x)`, `currentColor` and the CSS named colours (`red`, `steelblue`)
- a paint fallback: the reserve `red` in `fill="url(#g) red"`

They appear in the closing warning so you know they exist, instead of the count saying "184/184" while the icon stays blue.

### The ceiling of the approach, stated plainly

The tool decides what is a colour by **matching text**, not by parsing the document's grammar. In SVG a `#` introduces at least four different things: a colour, a fragment reference (same document or another), a CSS id selector, and text that happens to contain one. Telling them apart properly needs XML structure, then CSS structure inside `<style>`, then CSS value syntax inside a declaration.

`ColorTokens.psm1` implements a hand-rolled approximation of all three. It works for everything measured — 16 distinct constructs, each covered by a test that fails when its fix is reverted — and **the list did not converge**: every review round that changed its angle found another construct.

Hence the contract above: **presentation attributes on Power BI icon SVGs**. Not one of the 184 SVGs in `examples/` has a `<style>` block, a CDATA section, an `hsl()` or an external fragment reference. The tool handles them anyway, but that is robustness beyond the ground it was designed for.

**Before adding a new special case to the patterns, read [issue #29](https://github.com/CSalcedoDataBI/powerbi-pbip-tools/issues/29).** It carries the table of all 16 constructs and the two ways forward (parse the XML for real, or narrow the contract). Adding the seventeenth without that reading is repeating the last round.

## Layout

```
skill-svg-recolor-powerbi/
├── SKILL.md
├── SKILL.en.md       ← this file
├── README.md         ← the long guide, with examples
├── modules/
│   ├── ColorTokens.psm1   what is a colour
│   └── PbipIo.psm1        where the SVGs are, and how they are encoded
└── scripts/
    ├── detect-colors.ps1
    └── recolor.ps1
```

The modules are loaded with `Import-Module`, not dot-sourcing: their state does not leak into the caller's scope, and their public surface is declared with `Export-ModuleMember`.

## Requirements

PowerShell 5.1 or later. No external dependencies.

## Verification

```powershell
pwsh tests/smoke-test.ps1          # against a copy of the real Demo (184 SVGs)
pwsh tests/color-tokens-test.ps1   # the awkward constructs, one at a time
```
