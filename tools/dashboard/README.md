# Dashboard Builder — `/dashboard`

Generate an interactive, standalone HTML dashboard from a **Power BI** model connected
through **MCP** (Model Context Protocol). One command queries your model and produces a
single `.html` file with KPI cards, sparklines and trend/breakdown charts — no backend,
no server.

> This is the plugin described in the article
> [Cómo construí mi propio plugin para Claude Code que genera tableros desde Power BI](https://csalcedodatabi.com/blog/plugin-claude-code-dashboard-powerbi-mcp).
> Explore the [live demo](https://csalcedodatabi.com/demo/contoso-dashboard) (built from the Contoso model).

---

## What it produces

- **Summary cards** — totals for sales, units, margin and product count
- **Interactive KPI cards** with monthly trend sparklines
- **Trend chart** that updates when you click a KPI
- **Dimension breakdown** — by product category and by region, with switchable tabs
- **Year filter** — pick any year and every chart updates live
- Fully offline standalone HTML (Chart.js is bundled)

---

## The three parts

| File | Role |
|------|------|
| `commands/dashboard.md` | The command — entry point for `/dashboard` |
| `skills/dashboard-builder.md` | The skill — query plan, design rules and KPI system |
| `tools/dashboard/template.html` | The template — visual scaffold Claude fills with real data |

---

## Requirements

- [Claude Code](https://claude.ai/code)
- A **Power BI MCP** server connected (e.g. `powerbi-modeling-mcp`) pointing at an open
  Power BI Desktop model. Any MCP that answers tabular/DAX-style queries also works.

---

## Install

Copy the three folders into your Claude Code project:

```
your-project/
├── .claude/
│   ├── commands/
│   │   └── dashboard.md
│   └── skills/
│       └── dashboard-builder.md
└── tools/
    └── dashboard/
        ├── template.html
        └── vendor/
            └── chart.umd.min.js
```

Then open `skills/dashboard-builder.md` and edit the **Configuration** block at the top:

```
MCP_CONNECTION  : Data Source=localhost:PORT;Application Name=MCP-PBIModeling
OUTPUT_BASE     : <your output folder, e.g. ~/dashboards>
TEMPLATE_PATH   : tools/dashboard/template.html
DEFAULT_YEAR    : 2025
```

- **OUTPUT_BASE** — where generated dashboards are saved (must exist, and **not** inside the git repo)
- To find your Power BI port: run the MCP `connection_operations` with `ListLocalInstances`

---

## Usage

```
/dashboard
/dashboard sales 2025
/dashboard contoso por región Q1
/dashboard <describe what you want>
```

Claude reads the skill, connects to the model via MCP, runs all DAX queries in parallel,
fills the template with the real values and saves a standalone HTML to `OUTPUT_BASE`.

---

## Customize without touching HTML

- **Skill** (`dashboard-builder.md`) — change the MCP source, the KPIs, the breakdown dimensions
- **Template** (`template.html`) — change the color palette (CSS variables), typography, KPI layout
- **Command** (`dashboard.md`) — change the output folder or the command name

The template is data-agnostic: it only cares about the JavaScript objects the skill fills in.

---

## License

MIT — see the repository [LICENSE](../../LICENSE).
