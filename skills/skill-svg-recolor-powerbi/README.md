# 📦 skill-svg-recolor-powerbi

Automatically change the color of **all SVG icons** in your Power BI PBIP project.

## 🏷️ Clone Only This Skill

```bash
git clone --filter=blob:none --sparse https://github.com/CSalcedoDataBI/powerbi-pbip-tools.git
cd powerbi-pbip-tools
git sparse-checkout set skills/skill-svg-recolor-powerbi
```

## 🎯 Use Case

You have a Power BI report with 142 icons in blue, and you want to change them all to red **in 2 seconds** without opening Power BI Desktop.

## 🚀 Quick Start

### Step 1: Detect Colors

First, see what colors are currently in your project:

```powershell
.\skills\skill-svg-recolor-powerbi\scripts\detect-colors.ps1 -PbipDir "C:\MyProject"
```

**Output example:**
```text
Report : MyReport.Report
Folder : C:\MyProject\MyReport.Report\StaticResources\RegisteredResources
SVGs   : 142 scanned (142 found)
Colors : 3 unique hex colors found

  #003893  (62 files)
  #CE1126  (61 files)
  #FCD116  (61 files)
```

### Step 2: Preview Changes (Dry Run)

Before modifying anything, preview which files would be updated:

```powershell
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 -PbipDir "C:\MyProject" -To "#FF0000" -WhatIf
```

**Output:**
```text
[MyReport.Report] Auto-detected: #003893, #CE1126, #FCD116
  [WhatIf] Would modify: icon_arrow.svg
  [WhatIf] Would modify: icon_chart.svg
  ...
[WhatIf] Total: 142/142 SVGs would be modified. No files were changed.
```

### Step 3: Change Colors

Run without `-WhatIf` to apply. Add `-Backup` to save originals first:

```powershell
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 `
  -PbipDir "C:\MyProject" `
  -To "#FF0000" `
  -Backup
```

**Output:**
```text
[MyReport.Report] Auto-detected: #003893, #CE1126, #FCD116
[MyReport.Report] Backup saved to: C:\Users\you\AppData\Local\Temp\pbip-recolor-backup_MyReport.Report_20250115_143022
[MyReport.Report] Modified 142/142 SVGs (-> #FF0000)

Done. Total: 142/142 SVGs modified (-> #FF0000)
```

Done! Open your `.pbip` file in Power BI Desktop to see the changes.

## 📚 Advanced Usage

### Replace Specific Colors Only

```powershell
# Only replace blue and red, leave yellow unchanged
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 `
  -PbipDir "C:\MyProject" `
  -From "#003893","#CE1126" `
  -To "#000000"
```

### Exclude Colors (Preserve Masks)

```powershell
# Replace all colors EXCEPT gray (often used for masks)
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 `
  -PbipDir "C:\MyProject" `
  -To "#FF0000" `
  -Exclude "#D9D9D9"
```

## 📖 Parameter Reference

### detect-colors.ps1

| Parameter  | Required | Description                                       |
| :--------- | :------: | :------------------------------------------------ |
| `-PbipDir`  |    ✅    | Root folder of the PBIP project (where `.pbip` file is) |
| `-PassThru` |    ❌    | Also emit `Color` / `FileCount` / `Report` objects, for scripting |

### recolor.ps1

| Parameter  | Required | Description                                                                     |
| :--------- | :------: | :------------------------------------------------------------------------------ |
| `-PbipDir` |    ✅    | Root folder of the PBIP project (where `.pbip` file is)                         |
| `-To`      |    ✅    | Target hex color: `#RGB`, `#RGBA`, `#RRGGBB` or `#RRGGBBAA`                     |
| `-From`    |    ❌    | Array of hex colors to replace. If omitted, replaces **all** colors            |
| `-Exclude` |    ❌    | Array of hex colors to preserve (not modify)                                    |
| `-Backup`  |    ❌    | Copy originals before writing. **Fails the run** if the backup cannot be made   |
| `-BackupRoot` | ❌ | Where `-Backup` writes. Defaults to the system temp folder, deliberately outside the PBIP project |
| `-WhatIf`  |    ❌    | Preview which files would change without modifying anything                     |

## 🎨 Which colors are rewritten

Hex notation only, in all four written forms. `#FFF` and `#FFFFFF` are treated as
the same color; `#0078D4` and `#0078D480` are **not** — the second carries an alpha
channel, so rewriting one must never touch the other.

| Notation | Detected | Rewritten |
|---|:---:|:---:|
| `#RRGGBB`, `#RGB` | ✅ | ✅ |
| `#RRGGBBAA`, `#RGBA` | ✅ | ✅ (as its own color) |
| `rgb()` / `rgba()` | ✅ | ❌ |
| `currentColor` | ✅ | ❌ |
| Any non-hex paint value (`red`, `inherit-ish` words) | ⚠️ | ❌ |

⚠️ Reported as **non-hex paint value**, not as "named color": the check sees a word
in a paint position that is not hex and not a CSS-wide keyword, so `red` and
`redacted` both land there. It covers the attribute form (`fill="red"`), the inline
style form (`style="fill:red"`) and declarations inside a `<style>` block, and it
ignores the same word in a `data-` attribute or a `<desc>`.

Fragment references are never touched: `url(#fff)`, `href="#mask"` and
`xlink:href` keep their ids even when an id happens to look like a hex color,
which is ordinary SVGO output. Rewriting one leaves a live reference pointing at
nothing while its `id` attribute stays put.

Text that is not paint is left alone: XML comments, and the contents of
`<desc>`, `<title>`, `<metadata>` and `<script>`. Inside a `<style>` block the
scripts tell a selector from a declaration value, so `#fff:hover { fill: #0078D4 }`
has exactly one color in it. Commented-out CSS, CSS strings and `url()` bodies
are not colors either.

**Documented limit — XML character references.** A color written as
`fill="&#35;0078D4"` (or `&#x23;`) is a valid hex color once the XML is parsed, and
these scripts work on raw text, so they will not see it: the file reports zero
colors and the recolor leaves it alone. There are zero such colors in the 184 SVGs
shipped in `examples/`, and no tool in the Power BI, Figma, Illustrator or SVGO
chain emits them. Left unsupported on purpose rather than adding a code path that
nothing exercises.

**Documented limit:** anywhere else, any hex token is treated as a color. These
are icon files made of attribute soup, and guessing which attributes may carry
paint would miss real ones. If you keep hex strings somewhere unusual in your
SVGs, run with `-WhatIf` first.

**Links.** A *symlink* inside `RegisteredResources` is skipped on write, with the
reason printed: it is a pointer, and following it would land the change on a file
outside the project. A *hard link* is not skipped, because it is not a pointer —
the file in the folder is the file, with equal standing to its other name, and
Power BI reads it as a project asset. Recoloring it changes what the other name
sees, which is what a hard link means.

File encoding is preserved rather than imposed: a file that arrived without a BOM
is written back without one, a file that had one keeps it, and a UTF-16 file is
skipped with a warning instead of being silently re-encoded as UTF-8.

Anything in the "not rewritten" rows is **reported** by both scripts rather than
passed over in silence — `detect-colors.ps1` lists it, and `recolor.ps1` warns at
the end of the run. Reporting `142/142 updated` while some icons keep their old
color is the failure that reporting exists to prevent.

## ⚠️ Important Notes

> [!TIP]
> Use `-WhatIf` first to confirm the expected changes, then re-run with `-Backup` to save originals before committing.

> [!TIP]
> Always commit your PBIP project to Git before running the skill, so you can easily revert if needed.

## 🔍 How It Works

1. **Locates SVGs**: finds `StaticResources/RegisteredResources` inside every `*.Report/` folder
   of the project, so a multi-report project is handled in one run.
2. **Reads the encoding first**: a file is skipped, not rewritten, when it is UTF-16 or when its
   bytes are not valid UTF-8. A UTF-8 BOM is written back if it was there and not added if it
   was not.
3. **Finds colors, not every `#`**: matches `#RGB`, `#RGBA`, `#RRGGBB` and `#RRGGBBAA`, then
   discards the ones that are not paint - fragment references like `url(#grad)`, CSS selectors
   inside a `<style>` block, and text inside comments, `<desc>`, `<title>`, `<metadata>` and
   `<script>`.
4. **Replaces whole tokens**: each match is swapped as a unit after normalising it, so `#FFF` and
   `#FFFFFF` count as one color while `#0078D4` and `#0078D4**80**` stay two.
5. **Reports what it did not do**: `rgb()`, `currentColor` and any non-hex paint value are counted and named,
   because a silent skip is how a recolor ends up looking finished when it is not.

## 🧪 Running the checks

The same two suites CI runs, from the repository root:

```powershell
# once, pinned to the version CI uses
Install-Module PSScriptAnalyzer -RequiredVersion 1.25.0 -Scope CurrentUser

Invoke-ScriptAnalyzer -Path skills -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
Invoke-ScriptAnalyzer -Path tests  -Recurse -Settings ./PSScriptAnalyzerSettings.psd1

pwsh ./tests/smoke-test.ps1          # end to end against a copy of examples/Demo
pwsh ./tests/color-tokens-test.ps1   # the awkward colour cases, on a synthetic project
```

Both test scripts work on throwaway copies and exit non-zero on failure. The lint fails the build
on `Warning` as well as `Error`, deliberately: the bug that started this suite
(`PSAvoidAssignmentToAutomaticVariable`) is only a Warning.

## 📁 PBIP Structure

```text
MyProject/
├── MyProject.pbip
├── MyProject.Report/
│   └── StaticResources/
│       └── RegisteredResources/   ← SVGs are here
└── MyProject.SemanticModel/
```

## 🤝 Need Help?

- [Full Documentation](../../docs/skill-svg-recolor-powerbi-guide.md)
- [Example Project](../../examples/Demo/)
- [Report an Issue](https://github.com/CSalcedoDataBI/powerbi-pbip-tools/issues)
