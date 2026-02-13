# Demo Project

This is a working example Power BI project in PBIP format that you can use to test the SVG recolor tool.

## What's Inside

- **142 SVG icons** with multiple colors
- Sample Power BI report demonstrating icon usage
- Ready to use with the recolor scripts

## How to Use

### 1. Clone the Repository

```powershell
git clone https://github.com/CSalcedoDataBI/powerbi-pbip-tools.git
cd powerbi-pbip-tools
```

### 2. Detect Colors

```powershell
.\svg-recolor\scripts\detect-colors.ps1 -PbipDir ".\examples\Demo"
```

### 3. Change Colors

```powershell
# Change all icons to red
.\svg-recolor\scripts\recolor.ps1 -PbipDir ".\examples\Demo" -To "#FF0000"
```

### 4. Open in Power BI Desktop

Double-click `Demo.pbip` to open it in Power BI Desktop and see the changes.

## Reverting Changes

Since this is a Git repository, you can easily revert:

```powershell
git restore examples/Demo
```

## Learn More

- [SVG Recolor Tool Documentation](../../svg-recolor/README.md)
- [Complete Tutorial](../../docs/svg-recolor-guide.md)
