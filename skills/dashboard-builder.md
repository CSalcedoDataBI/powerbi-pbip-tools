---
name: dashboard-builder
description: >
  Use this skill to create an interactive HTML dashboard from a Power BI model (or any MCP data source).
  Trigger when the user says: "dashboard", "tablero", "KPI visual", "HTML analytics", "create a dashboard",
  "genera un dashboard", "quiero ver mis KPIs", or anything that implies building an analytics summary view.
  Always use this skill — even if the user doesn't say "dashboard" explicitly — when they want to visualize
  KPIs, monthly trends, or CY vs PY comparisons from a connected data source.
---

# Skill: Interactive HTML Dashboard Builder

---

## Configuration (edit before first use)

```
MCP_CONNECTION  : Data Source=localhost:PORT;Application Name=MCP-PBIModeling
OUTPUT_BASE     : <your output folder, e.g. ~/dashboards>
TEMPLATE_PATH   : tools/dashboard/template.html
DEFAULT_YEAR    : 2025
```

To find your Power BI port:
- Use `mcp__powerbi-modeling-mcp__connection_operations` with `ListLocalInstances`
- Or connect with the connection string returned by `ListLocalInstances`

---

## Phase 1 — Connect and identify the model

```
1. Call connection_operations { operation: "ListLocalInstances" }
2. Connect to the model: connection_operations { operation: "Connect", connectionString: "..." }
3. List tables: table_operations { operation: "List" }
4. List key measures: measure_operations { operation: "List", filter: { displayFolders: ["KPISales"] } }
```

Identify:
- **Date table** and its Year, Month Number, Month columns
- **Fact table** with Sales, Cost, Quantity fields
- **Dimension tables**: Product (Category), Store/Geography (Country)
- **Key measures**: Sales Amount, Total Cost, Margin, Margin %, Total Quantity

---

## Phase 2 — Query all data in parallel

Fire ALL queries in a single message. Use `dax_query_operations` with `operation: "Execute"`.

### Query set (adapt field names to the actual model):

```dax
-- Q1: Monthly Sales, Margin, Cost, Qty for current year and prior year
EVALUATE
ADDCOLUMNS(
  SUMMARIZE(DimDate, DimDate[Year], DimDate[Month Number], DimDate[Month]),
  "Sales", [Sales Amount],
  "Margin", [Margin],
  "Qty", [Total Quantity]
)
ORDER BY DimDate[Year], DimDate[Month Number]

-- Q2: Yearly totals
EVALUATE
ADDCOLUMNS(
  SUMMARIZE(DimDate, DimDate[Year]),
  "Sales", [Sales Amount],
  "Cost", [Total Cost],
  "Margin", [Margin],
  "Qty", [Total Quantity]
)
ORDER BY DimDate[Year]

-- Q3: Sales by Category per year
EVALUATE
ADDCOLUMNS(
  CROSSJOIN(
    SUMMARIZE(DimDate, DimDate[Year]),
    SUMMARIZE(DimProduct, DimProduct[Category])
  ),
  "Sales", [Sales Amount]
)
ORDER BY DimDate[Year], [Sales] DESC

-- Q4: Sales by Country (total historical)
EVALUATE
TOPN(10,
  ADDCOLUMNS(SUMMARIZE(DimStore, DimStore[Country]), "Sales", [Sales Amount]),
  [Sales], DESC
)
```

---

## Phase 3 — Fill the HTML template

### Step 3a — Read the template

Read `tools/dashboard/template.html` completely before writing any HTML.
Find all `/* PLACEHOLDER: */` comments — these are the only sections you modify.

### Step 3b — Fill the CONFIG section

```javascript
const CONFIG = {
  title:       "Your Model Name — Sales Analysis",  // shown in header
  source:      "YourModelName",                      // shown in footer
  author:      "Your Name",
  website:     "https://your-site.com",
  defaultYear: 2025,                                 // pre-selected year on load
  years:       [2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025]
};
```

### Step 3c — Fill the DATA section

Build JavaScript objects from the query results:

```javascript
// Monthly sales by year — object of arrays (12 values each)
const MS = {
  2024: [jan, feb, mar, apr, may, jun, jul, aug, sep, oct, nov, dec],
  2025: [jan, feb, mar, apr, may, jun, jul, aug, sep, oct, nov, dec],
  // ... all years
};

// Monthly margin by year
const MM = { /* same structure as MS */ };

// Monthly quantity by year
const MQ = { /* same structure as MS */ };

// Yearly totals
const YEARLY = {
  2024: { s: totalSales, c: totalCost, m: totalMargin, q: totalQty },
  2025: { s: totalSales, c: totalCost, m: totalMargin, q: totalQty },
  // ...
};

// Category sales by year (in millions)
const CAT_SALES = {
  2025: { "Category A": 55.0, "Category B": 38.3, ... },
  // ...
};

// Country proportions (fraction of total sales, must sum to ~1.0)
const COUNTRY_PROP = {
  "Country A": 0.526,
  "Country B": 0.089,
  // ...
};
```

### Step 3d — Fill METRICS and DASH_CARDS

This is **critical** — labels must match the actual model, not the Sales template defaults.

Map your three base arrays to the 12 card keys:

| Template key | Always shows | Sales model | Spend/VMS model | Mining/Ops model |
|---|---|---|---|---|
| `sales` | MS | Sales Amount | Gross Spend | Avance (m) |
| `margin` | MM | Margin | Net Spend | Target (m) |
| `cost` | MS − MM | Total Cost | Platform Fees | Gap vs Plan |
| `cost_pct` | cost/sales % | Cost % | Fee Rate % | Gap % |
| `margin_pct` | margin/sales % | Margin % | Net Rate % | Achievement % |
| `qty` | MQ | Units Sold | Headcount | Turnos |
| `avg_sales` | MS/MQ | Avg Ticket | Spend/Assignment | m/Turno |
| `avg_cost` | cost/MQ | Avg Cost | Fee/Assignment | Gap/Turno |
| `margin_unit` | MM/MQ | Margin/Unit | Net/Head | Target/Turno |
| `rev_unit` | MS/MQ | Revenue/Unit | Gross/Head | Avance/Pozo |
| `mom_pct` | MoM MS % | MoM Growth % | MoM Growth % | MoM Growth % |
| `avg_qty` | K constant | Avg Qty | Avg Assignments | Avg Turnos |

Replace every `label:` and `icon:` in METRICS and DASH_CARDS to reflect the actual model.
Use `better:'lower'` for metrics where lower is better (cost, fee rate, defects).
Use `better:'higher'` for metrics where higher is better (revenue, margin, production).

### Step 3e — Save the output

**Output path:** `{OUTPUT_BASE}\dashboards\{model}_{year}.html`
Example: `<OUTPUT_BASE>/dashboards/contoso_2025.html`

**NEVER write inside the git repo.** Always use OUTPUT_BASE.

---

## Phase 4 — Quality checklist

Before reporting done:

- [ ] CONFIG.title shows the actual model name
- [ ] All 8+ years have monthly arrays with exactly 12 values each
- [ ] MS, MM, MQ arrays use real values from DAX queries (not zeros)
- [ ] YEARLY totals match the sum of monthly arrays
- [ ] CAT_SALES has entries for all available years
- [ ] COUNTRY_PROP values sum to approximately 1.0
- [ ] Output file saved to OUTPUT_BASE (not inside the repo)
- [ ] File opens in browser without console errors

---

## Derived metrics (computed automatically by the template)

The template computes these from MS, MM, MQ — no separate queries needed:

| Metric | Formula |
|--------|---------|
| Total Cost | `Sales - Margin` per month |
| Cost % | `Cost / Sales × 100` per month |
| Margin % | `Margin / Sales × 100` per month |
| Average Sales | `Sales × 36.8 / Qty` per month |
| Average Cost | `Cost × 36.8 / Qty` per month |
| Revenue / Unit | `Sales / Qty` per month |
| Margin / Unit | `Margin / Qty` per month |
| MoM Growth % | `(Sales[m] - Sales[m-1]) / Sales[m-1] × 100` |

The constant `36.8` is the average units per transaction — update in the template if your model differs.
Query with: `EVALUATE ROW("AvgQty", [Average Quantity])`

---

## Adapting to your data source

### Different field names

If your model uses different column names, update the DAX queries in Phase 2.
The template logic is data-agnostic — it only cares about the JavaScript objects you fill in.

### Different number of years

Update `CONFIG.years` array. The template handles any number of years dynamically.

### Different categories / countries

Fill `CAT_SALES` with your actual category names and values.
Fill `COUNTRY_PROP` with your geography names and proportions.
The template adapts to any number of categories/countries.

### Non-Power BI source

If your MCP provides a different query interface (SQL, REST, etc.):
- Replace the DAX queries in Phase 2 with the appropriate syntax
- The data structure you fill into the template stays the same

---

## Design system (reference)

The template uses CSS custom properties — override in `:root` to re-theme:

```css
:root {
  --bg: #EEECEA;          /* page background */
  --sur: #FFFFFF;         /* card surface */
  --good: #27AE60;        /* positive / above goal */
  --bad: #E53935;         /* negative / below goal */
  --accent: #1E40AF;      /* active tab / selected */
}
```

Pastel card colors: blue · green · rose · violet · amber · teal · indigo · pink
Each assigns `--k-bg` (fill) and `--k-acc` (accent border) automatically.
