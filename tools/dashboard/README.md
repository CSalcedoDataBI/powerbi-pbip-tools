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
- **Standalone HTML** — a single file, no backend and no server. It loads Chart.js from a
  CDN by default; run `Inline-ChartJs.ps1` (below) to embed the library and make it work
  with no network access at all

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
        ├── Inline-ChartJs.ps1
        └── vendor/
            ├── chart.umd.min.js
            └── chart.js.LICENSE.txt
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

## Making a dashboard work offline

`template.html` pulls Chart.js from a CDN. That is fine on a laptop with internet, and it
fails badly without one: the script dies on its first reference to `Chart`, so the page
renders **nothing** — no charts, no KPI cards, not even the title.

```
Failed to load resource: net::ERR_NAME_NOT_RESOLVED
Uncaught ReferenceError: Chart is not defined
```

That is what a corporate proxy, an air-gapped machine or a plane looks like. To remove the
dependency, run the script once against the generated file:

```powershell
pwsh tools/dashboard/Inline-ChartJs.ps1 -Path <OUTPUT_BASE>/dashboards/contoso_2025.html
```

It replaces the Chart.js `<script src="...">` with the vendored copy of the library, plus
its MIT notice, and the file grows from ~44 KB to ~245 KB. Chart.js is the only thing it
removes, so it finishes by reporting any other external reference the dashboard still
carries — a web font, an image — rather than letting you assume an offline guarantee it
cannot give. A dashboard from the stock template has none, and prints:

```
  No external references remain: it renders with no network access.
```

Running it twice is a no-op. It refuses to run on a file that carries its marker but still
has a CDN tag: that means either an interrupted conversion or marker text that came from
the dashboard's own content, and guessing which would risk shipping the library with the
license notice stripped.

It is a separate step, not part of the template, because the library is 200 KB of minified
JavaScript: carrying that blob through every read-and-rewrite of the template would be slow,
and one mistyped character would break every chart. Splicing it in afterwards is mechanical.

---

## Third-party software

| Component | Version | License | Source |
|---|---|---|---|
| Chart.js | 4.4.1 (pinned) | MIT — [`vendor/chart.js.LICENSE.txt`](vendor/chart.js.LICENSE.txt) | <https://github.com/chartjs/Chart.js> |

The version is pinned in two places that must stay in step: the CDN URL in `template.html`
and the vendored `vendor/chart.umd.min.js`. When a CVE or a bug forces an update, change
both, and refresh `chart.js.LICENSE.txt` from the tag you moved to — the copyright line
changes between releases.

Chart.js is MIT, which requires its copyright and permission notice to travel with every
copy. `Inline-ChartJs.ps1` therefore writes the full notice into each dashboard it converts,
and refuses to run if `chart.js.LICENSE.txt` is missing rather than shipping the code
without it.

---

## Customize without touching HTML

- **Skill** (`dashboard-builder.md`) — change the MCP source, the KPIs, the breakdown dimensions
- **Template** (`template.html`) — change the color palette (CSS variables), typography, KPI layout
- **Command** (`dashboard.md`) — change the output folder or the command name

The template is data-agnostic: it only cares about the JavaScript objects the skill fills in.

---

## License

MIT — see the repository [LICENSE](../../LICENSE).
