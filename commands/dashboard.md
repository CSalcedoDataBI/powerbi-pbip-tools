# /dashboard — Interactive KPI Dashboard Generator

Creates a fully interactive HTML dashboard from any Power BI model connected via MCP.
Output: a standalone `.html` file with 12 KPI cards, sparklines, and sentiment charts.

## Usage

```
/dashboard
/dashboard sales 2025
/dashboard <describe what you want>
```

## What this command does

1. **Reads** `.claude/skills/dashboard-builder.md` for full instructions and configuration
2. **Connects** to the Power BI Desktop model via MCP
3. **Queries** all required monthly metrics in parallel (DAX)
4. **Generates** a standalone HTML file with:
   - 12 KPI metric cards (3-column grid) with embedded sparklines
   - 4 sparkline interaction modes (vs. Average · vs. PY Bar · vs. PY Line · vs. PY Only Bar)
   - Dashboard page: CY vs PY sentiment line chart (green/red fill)
   - Category donut, country bars, annual evolution — all dynamic by metric
   - Drill-through: click any KPI card → Dashboard page filtered to that metric
   - Year filter: select any year, all charts and KPIs update live
5. **Saves** to `OUTPUT_BASE\dashboards\{topic}_{year}.html`

## Execution

Read the skill file first, then follow its phases exactly:

```
Phase 1: Connect to MCP and identify the model
Phase 2: Run all DAX queries in parallel
Phase 3: Fill the HTML template with real data
Phase 4: Run the quality checklist before saving
```

## Critical rules

- **Never fabricate numbers** — every value must come from a DAX query response
- **Always query in parallel** — fire all DAX queries in a single message
- **Never save inside the git repo** — output goes to OUTPUT_BASE only
- **Use the template** — read `tools/dashboard/template.html` before generating any HTML

## Output examples

- `DASHBOARDS\dashboards\sales_2025.html`
- `DASHBOARDS\dashboards\contoso_overview_2024.html`
- `DASHBOARDS\dashboards\kpi_analysis_q1_2025.html`
