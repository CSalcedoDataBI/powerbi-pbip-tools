# SVG Recolor Guide

Complete tutorial for using the SVG recolor skill with Power BI PBIP projects.

## Table of Contents
- [Understanding PBIP Format](#understanding-pbip-format)
- [Where SVG Files Are Stored](#where-svg-files-are-stored)
- [Step-by-Step Tutorial](#step-by-step-tutorial)
- [Advanced Scenarios](#advanced-scenarios)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Understanding PBIP Format
PBIP (Power BI Project) is an **open format** introduced by Microsoft that stores Power BI reports and semantic models as plain text files. This enables:

- ✅ **Version control** with Git
- ✅ **Offline editing** without Power BI Desktop
- ✅ **Automation** via scripts
- ✅ **Team collaboration** with merge conflict resolution

### PBIP vs PBIX

| Feature | PBIX | PBIP |
|---------|------|------|
| Format | Binary (compressed) | Plain text (JSON, etc.) |
| Git-friendly | ❌ No | ✅ Yes |
| Offline editing | ❌ No | ✅ Yes |
| Automation | Limited | ✅ Full access |

## Where SVG Files Are Stored

When you add an SVG icon to a Power BI report, it's stored in the PBIP project structure:

```text
MyProject/
├── MyProject.pbip                    ← Project definition
├── MyProject.Report/                 ← Report files
│   ├── definition.pbir               ← Report definition
│   ├── report.json                   ← Report layout
│   └── StaticResources/
│       └── RegisteredResources/      ← 🎯 SVG ICONS HERE
│           ├── icon1.svg
│           ├── icon2.svg
│           └── ...
└── MyProject.SemanticModel/          ← Data model
    ├── definition.pbism
    └── model.bim
```

## Step-by-Step Tutorial

### Prerequisites
- Windows PowerShell 5.1+ or PowerShell Core 7+
- A Power BI project in PBIP format
- Git (recommended for version control)

### Step 1: Clone This Repository
```powershell
git clone https://github.com/CSalcedoDataBI/powerbi-pbip-tools.git
cd powerbi-pbip-tools
```

### Step 2: Locate Your PBIP Project
Find the folder containing your `.pbip` file:

```powershell
# Example path
C:\Projects\SalesReport\SalesReport.pbip
```

### Step 3: Detect Current Colors
Run the detection script to see what colors are in your SVG icons:

```powershell
.\skills\skill-svg-recolor-powerbi\scripts\detect-colors.ps1 -PbipDir "C:\Projects\SalesReport"
```

**Example output:**

```text
Carpeta: C:\Projects\SalesReport\SalesReport.Report\StaticResources\RegisteredResources
84 SVGs escaneados
Colores encontrados: 2
  #0078D4  (42 archivos)
  #D9D9D9  (42 archivos)
```

### Step 4: Change Colors
#### Option A: Replace All Colors

```powershell
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 `
  -PbipDir "C:\Projects\SalesReport" `
  -To "#FF5733"
```

#### Option B: Replace Specific Colors

```powershell
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 `
  -PbipDir "C:\Projects\SalesReport" `
  -From "#0078D4" `
  -To "#FF5733"
```

#### Option C: Preserve Certain Colors

```powershell
# Replace all colors EXCEPT gray (masks)
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 `
  -PbipDir "C:\Projects\SalesReport" `
  -To "#FF5733" `
  -Exclude "#D9D9D9"
```

### Step 5: Verify Changes
1. Open `SalesReport.pbip` in Power BI Desktop
2. Check that your icons have the new color
3. If satisfied, commit changes to Git:

```powershell
git add .
git commit -m "chore: update icon colors to #FF5733"
```

## Advanced Scenarios

### Scenario 1: Multi-Color Icons with Masks
Some icons use multiple colors where one color is a "mask" (usually gray) that should be preserved:

```powershell
# Replace blue but keep gray mask
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 `
  -PbipDir "C:\MyProject" `
  -From "#0078D4" `
  -To "#FF0000" `
  -Exclude "#D9D9D9"
```

### Scenario 2: Batch Processing Multiple Projects
Create a script to process multiple PBIP projects:

```powershell
$projects = @(
    "C:\Projects\Sales",
    "C:\Projects\Marketing",
    "C:\Projects\Finance"
)

$newColor = "#FF5733"

foreach ($proj in $projects) {
    Write-Host "Processing: $proj"
    .\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 -PbipDir $proj -To $newColor
}
```

### Scenario 3: Theme-Based Recoloring
Create different color themes:

```powershell
# Blue theme
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 -PbipDir "C:\MyProject" -To "#0078D4"

# Red theme
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 -PbipDir "C:\MyProject" -To "#E74856"

# Green theme
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 -PbipDir "C:\MyProject" -To "#107C10"
```

## Best Practices

### 1. Always Use Version Control
```powershell
# Before making changes
git add .
git commit -m "checkpoint: before color change"

# Make changes
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 -PbipDir "." -To "#FF0000"

# Review changes
git diff

# Commit or revert
git commit -m "feat: update icons to red"
# OR
git restore .
```

### 2. Test on a Copy First
```powershell
# Make a copy
Copy-Item "C:\MyProject" "C:\MyProject-Test" -Recurse

# Test on copy
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 -PbipDir "C:\MyProject-Test" -To "#FF0000"

# If satisfied, apply to original
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 -PbipDir "C:\MyProject" -To "#FF0000"
```

### 3. Document Color Choices
Keep a `colors.md` file in your project:

```markdown
# Icon Colors

- **Primary**: #0078D4 (Microsoft Blue)
- **Secondary**: #107C10 (Success Green)
- **Accent**: #E74856 (Error Red)
- **Mask**: #D9D9D9 (Gray, never change)
```

## Troubleshooting

### Error: "No .Report folder found"
**Cause**: The path doesn't point to a PBIP project root.

**Solution**: Make sure you're pointing to the folder containing the `.pbip` file:

```powershell
# ❌ Wrong
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 -PbipDir "C:\MyProject\MyProject.Report"

# ✅ Correct
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 -PbipDir "C:\MyProject"
```

### Error: "Path not found: ...RegisteredResources"
**Cause**: Your PBIP project doesn't have any SVG icons yet.

**Solution**: Add at least one SVG icon to your report in Power BI Desktop, then save.

### Colors Didn't Change
**Possible causes:**

1. **Wrong color format**: Use 6-digit hex (`#FF0000`), not 3-digit (`#F00`)
2. **Color is excluded**: Check if the color is in your `-Exclude` list
3. **SVG uses named colors**: The skill only replaces hex colors, not named colors like `red` or `blue`

### Changes Not Visible in Power BI Desktop
**Solution**: Close and reopen the `.pbip` file. Power BI Desktop caches resources.

## Need More Help?

- [Main README](../README.md)
- [Skill-Specific README](../skills/skill-svg-recolor-powerbi/README.md)
- [Report an Issue](https://github.com/CSalcedoDataBI/powerbi-pbip-tools/issues)
- [Contact the Author](https://csalcedodatabi.com/)
