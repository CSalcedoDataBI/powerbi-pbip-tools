# 📦 skill-svg-recolor-pbip

Automatically change the color of **all SVG icons** in your Power BI PBIP project.

## 🎯 Use Case

You have a Power BI report with 142 icons in blue, and you want to change them all to red **in 2 seconds** without opening Power BI Desktop.

## 🚀 Quick Start

### Step 1: Detect Colors

First, see what colors are currently in your project:

```powershell
.\skills\skill-svg-recolor-pbip\scripts\detect-colors.ps1 -PbipDir "C:\MyProject"
```

**Output example:**
```text
Carpeta: C:\MyProject\MyReport.Report\StaticResources\RegisteredResources
142 SVGs escaneados
Colores encontrados: 3
  #003893  (62 archivos)
  #CE1126  (61 archivos)
  #FCD116  (61 archivos)
```

### Step 2: Change Colors

Now replace all colors with red:

```powershell
.\skills\skill-svg-recolor-pbip\scripts\recolor.ps1 -PbipDir "C:\MyProject" -To "#FF0000"
```

**Output:**
```text
Auto-detectados: #003893, #CE1126, #FCD116
142/142 SVGs actualizados (-> #FF0000)
```

Done! Open your `.pbip` file in Power BI Desktop to see the changes.

## 📚 Advanced Usage

### Replace Specific Colors Only

```powershell
# Only replace blue and red, leave yellow unchanged
.\skills\skill-svg-recolor-pbip\scripts\recolor.ps1 `
  -PbipDir "C:\MyProject" `
  -From "#003893","#CE1126" `
  -To "#000000"
```

### Exclude Colors (Preserve Masks)

```powershell
# Replace all colors EXCEPT gray (often used for masks)
.\skills\skill-svg-recolor-pbip\scripts\recolor.ps1 `
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
| `-To`      |    ✅    | Target hex color (e.g., `#FF0000`)                                              |
| `-From`    |    ❌    | Array of hex colors to replace. If omitted, replaces **all** colors            |
| `-Exclude` |    ❌    | Array of hex colors to preserve (not modify)                                    |

## ⚠️ Important Notes

> [!WARNING]
> This skill modifies SVG files **in-place**. No automatic backup is created.

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

- [Full Documentation](../../docs/skill-svg-recolor-pbip-guide.md)
- [Example Project](../../examples/Demo/)
- [Report an Issue](https://github.com/CSalcedoDataBI/powerbi-pbip-tools/issues)
