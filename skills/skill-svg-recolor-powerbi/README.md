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
SVGs   : 142 scanned
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
  [WhatIf] Would update: icon_arrow.svg
  [WhatIf] Would update: icon_chart.svg
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
[MyReport.Report] Backup saved to: ...RegisteredResources\_backup_20250115_143022
[MyReport.Report] Updated 142/142 SVGs (-> #FF0000)

Done. Total: 142/142 SVGs updated (-> #FF0000)
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
| `-PbipDir` |    ✅    | Root folder of the PBIP project (where `.pbip` file is) |

### recolor.ps1

| Parameter  | Required | Description                                                                     |
| :--------- | :------: | :------------------------------------------------------------------------------ |
| `-PbipDir` |    ✅    | Root folder of the PBIP project (where `.pbip` file is)                         |
| `-To`      |    ✅    | Target hex color in `#RRGGBB` format (e.g., `#FF0000`)                          |
| `-From`    |    ❌    | Array of hex colors to replace. If omitted, replaces **all** colors            |
| `-Exclude` |    ❌    | Array of hex colors to preserve (not modify)                                    |
| `-Backup`  |    ❌    | Save original SVGs to a timestamped `_backup_` subfolder before modifying       |
| `-WhatIf`  |    ❌    | Preview which files would change without modifying anything                     |

## ⚠️ Important Notes

> [!TIP]
> Use `-WhatIf` first to confirm the expected changes, then re-run with `-Backup` to save originals before committing.

> [!TIP]
> Always commit your PBIP project to Git before running the skill, so you can easily revert if needed.

## 🔍 How It Works

1. **Locates SVGs**: Finds the `StaticResources/RegisteredResources` folder inside `YourProject.Report/`
2. **Scans for colors**: Uses regex to find all 6-digit hex colors (`#RRGGBB`)
3. **Replaces colors**: Updates SVG files with the new color
4. **Preserves structure**: Only changes color values, leaves SVG structure intact

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
