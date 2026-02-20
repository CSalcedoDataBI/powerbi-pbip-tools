# 🛠️ Power BI PBIP Skills

Automation skills for Power BI projects in **PBIP format**. Streamline your workflow with batch operations, SVG manipulation, and more.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Power BI](https://img.shields.io/badge/Power%20BI-PBIP-F2C811?logo=powerbi)](https://powerbi.microsoft.com/)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)](https://docs.microsoft.com/en-us/powershell/)

## 🎯 What is PBIP?

PBIP (Power BI Project) is an **open format** that stores Power BI reports and semantic models as **plain text files**. This enables:

- ✅ Version control with Git
- ✅ Collaboration via pull requests
- ✅ Offline metadata editing
- ✅ Automated batch operations

## 📦 Available Skills

### 🎨 skill-svg-recolor-pbip

Automatically change the color of **all SVG icons** in your Power BI PBIP project.

**Use Case:** You have a report with 142 icons in blue, and you want to change them all to red **in 2 seconds** without opening Power BI Desktop.

#### Workflow

```mermaid
flowchart LR
    A["📂 PBIP Project"] --> B["🔍 detect-colors.ps1"]
    B --> C["📊 Color Report"]
    C --> D["🎨 recolor.ps1"]
    D --> E["✅ SVGs Updated"]
    E --> F["📊 Open in Power BI"]
```

**[📖 Read the full documentation →](skills/skill-svg-recolor-pbip/README.md)**

**Quick Start:**
```powershell
# Detect all colors in your project
.\skills\skill-svg-recolor-pbip\scripts\detect-colors.ps1 -PbipDir "C:\MyProject"

# Change all blue icons to red
.\skills\skill-svg-recolor-pbip\scripts\recolor.ps1 -PbipDir "C:\MyProject" -From "#0078D4" -To "#DC143C"
```

---

### 🧠 semantic-architect-powerbi

Transform technical Power BI data models into **fully documented semantic models** — auto-generates descriptions, KPIs, and a complete Context Store using **MCP** (Model Context Protocol) as a bidirectional bridge.

**Use Case:** You have a model with 12 tables and 87 undocumented columns. The skill scans the model, researches industry KPIs, generates business descriptions for every object, and writes them back — turning you from a manual builder into an **Intelligence Auditor**.

#### Workflow

```mermaid
flowchart LR
    A["🤖 Phase 1\nModel DNA Scan"] --> B["🔬 Phase 2\nDeep Research"]
    B --> C["📋 Phase 3\nContext Store"]
    C --> D["👤 Phase 4\nExpert Audit"]
```

| Phase | Action | Mode |
|-------|--------|------|
| 1. Scan | Extract tables, columns, relationships via MCP. Classify industry & architecture | 🤖 Auto |
| 2. Research | Web search for industry KPIs, business questions, DAX patterns | 🤖 Auto |
| 3. Context Store | Generate semantic map with descriptions, visibility rules & KPI catalog | 🤖 Auto |
| 4. Audit | Expert reviews & approves → AI writes to the model via MCP | 👤 + 🤖 |

**[📖 Read the full documentation →](skills/semantic-architect-powerbi/SKILL.md)**

**Includes:**
- 📄 Context Store template with 4 structured sections
- 🔍 Industry research prompts for 7+ industries (Retail, Healthcare, Finance, Manufacturing, HR, Education, Logistics)
- 📏 Naming conventions for DAX measures, descriptions & technical column detection
- 📊 Complete Retail example (Contoso model)

---

## 🚀 Getting Started

### Prerequisites

- **Power BI Desktop** (with PBIP format support)
- **PowerShell 5.1+** (included in Windows)
- **Git** (optional, for version control)
- **MCP Server** (required for semantic-architect-powerbi skill)

### Installation

1. **Clone this repository:**
   ```powershell
   git clone https://github.com/CSalcedoDataBI/powerbi-pbip-tools.git
   cd powerbi-pbip-tools
   ```

2. **Try the Demo project:**
   ```powershell
   # Open the Demo project in Power BI Desktop
   start examples/Demo/Demo.pbip
   
   # Detect colors
   .\skills\skill-svg-recolor-pbip\scripts\detect-colors.ps1 -PbipDir ".\examples\Demo"
   
   # Recolor all icons
   .\skills\skill-svg-recolor-pbip\scripts\recolor.ps1 -PbipDir ".\examples\Demo" -From "#0078D4" -To "#DC143C"
   ```

---

## 📚 Documentation

- **[SVG Recolor Guide](docs/skill-svg-recolor-pbip-guide.md)** - Complete tutorial with examples
- **[SVG Recolor README](skills/skill-svg-recolor-pbip/README.md)** - Skill-specific documentation
- **[Semantic Architect SKILL.md](skills/semantic-architect-powerbi/SKILL.md)** - Full skill specification with 4-phase workflow

---

## 🤝 Contributing

This repository is designed to be **extensible**. If you create a new skill for Power BI PBIP automation, feel free to contribute!

**Structure for new skills:**
```text
powerbi-pbip-tools/
├── skills/
│   ├── skill-svg-recolor-pbip/      # SVG batch recoloring
│   ├── semantic-architect-powerbi/  # Semantic model documentation
│   └── skill-your-name-pbip/        # Your new skill
│       ├── README.md
│       ├── SKILL.md                 # Optional: Standard skill format
│       └── scripts/
│           └── your-script.ps1
├── docs/
│   └── skill-your-name-pbip-guide.md
└── examples/
    └── YourExample/
```

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

---

## 🔗 Links

- **Author:** [Cristobal Salcedo](https://csalcedodatabi.com)
- **Repository:** [github.com/CSalcedoDataBI/powerbi-pbip-tools](https://github.com/CSalcedoDataBI/powerbi-pbip-tools)
- **Issues:** [Report a bug or request a feature](https://github.com/CSalcedoDataBI/powerbi-pbip-tools/issues)

---

## 🌟 More Skills Coming Soon

This repository will grow with more automation skills for Power BI PBIP projects. Stay tuned!
