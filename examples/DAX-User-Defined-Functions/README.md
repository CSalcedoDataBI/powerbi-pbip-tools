# DAX User-Defined Functions — PBIP Example

![PerformanceBand function in Power BI Desktop TMDL editor](./DAX%20User-Defined%20Functions.PNG)

> Reference implementation of DAX User-Defined Functions (GA June 2026) in PBIP format.
> Full article: [CSalcedo DataBI — DAX UDF Reference](https://www.csalcedodatabi.com/blog/dax-user-defined-functions-referencia/)

---

## What's Inside

### 6 Custom Functions (`functions.tmdl`)

| Function | Parameters | Purpose |
|---|---|---|
| `GrossMarginPct` | `sales: ANYREF`, `cogs: ANYREF` | Gross margin % with safe division |
| `SafeDivide` | `numerator: ANYREF`, `denominator: ANYREF` | Division returning BLANK on zero |
| `ClassifyValue` | `value: ANYREF`, `high: SCALAR`, `low: SCALAR` | Threshold-based classifier |
| `YoYGrowth` | `metric: ANYREF`, `dateCol: ANYREF` | Year-over-Year % growth |
| `ShareOfTotal` | `metric: ANYREF`, `groupCol: ANYREF` | Share within dimension via ALL() |
| **`PerformanceBand`** | `metric: ANYREF`, `groupCol: ANYREF` | **Statistical band classifier (★ Top / ↑ / ↓ / ⚠)** |

### 11 Measures (`_Medidas` table)

| Measure | Formula |
|---|---|
| `Total Sales` | `SUM(financials[Sales])` |
| `Total COGS` | `SUM(financials[COGS])` |
| `Total Profit` | `SUM(financials[Profit])` |
| `Total Units Sold` | `SUM(financials[Units Sold])` |
| `Gross Margin %` | `GrossMarginPct([Total Sales], [Total COGS])` |
| `Discount Rate %` | `SafeDivide(SUM(financials[Discounts]), SUM(financials[Gross Sales]))` |
| `Profit Classification` | `ClassifyValue([Total Profit], 3000000, 1500000)` |
| `YoY Sales Growth` | `YoYGrowth([Total Sales], financials[Date])` |
| `Sales Share %` | `ShareOfTotal([Total Sales], financials[Product])` |
| `Profit Band` | `PerformanceBand([Total Profit], financials[Product])` |
| `Sales Band` | `PerformanceBand([Total Sales], financials[Product])` |

### Data

- **Table:** `financials` — Microsoft Financial Sample (public domain, 700 rows)
- **Products:** Paseo, VTT, Amarilla, Velo, Montana, Carretera
- **Years:** 2013–2014
- **Countries:** Canada, Germany, France, Mexico, USA, India

---

## The Magistral Example: `PerformanceBand`

This function classifies any measure against its own statistical distribution — mean ± standard deviation — computed over all elements of a given dimension. The thresholds are **data-driven**, not arbitrary.

```dax
FUNCTION PerformanceBand = (
    metric   : ANYREF,   -- any measure in the model
    groupCol : ANYREF    -- any dimension column
) =>
    VAR _AllRows = CALCULATETABLE(
        ADDCOLUMNS( DISTINCT( groupCol ), "@val", CALCULATE( metric ) ),
        ALL( TABLEOF( groupCol ) )   -- clears external filters before iterating
    )
    VAR _Mean    = AVERAGEX( _AllRows, [@val] )
    VAR _StdDev  = STDEVX.P( _AllRows, [@val] )
    VAR _Current = metric
    RETURN
    SWITCH(
        TRUE(),
        ISBLANK( _Current ),             "—",
        _Current >= _Mean + _StdDev,     "★ Top",
        _Current >= _Mean,               "↑ Sobre promedio",
        _Current >= _Mean - _StdDev,     "↓ Bajo promedio",
                                         "⚠ Rezagado"
    )
```

**Key pattern:** `CALCULATETABLE(..., ALL(TABLEOF(groupCol)))` clears the external filter context *before* iterating — otherwise the outer slicer context contaminates the statistical computation.

**Usage — one line per metric:**

```dax
Profit Band = PerformanceBand( [Total Profit], financials[Product] )
Sales Band  = PerformanceBand( [Total Sales],  financials[Product] )
```

**Result on Financial Sample data:**

| Product | Total Profit | Profit Band | Total Sales | Sales Band |
|---|---|---|---|---|
| Paseo | 4.8M | ★ Top | 33M | ★ Top |
| VTT | 3.0M | ↑ Sobre promedio | 20.5M | ↑ Sobre promedio |
| Amarilla | 2.8M | ↓ Bajo promedio | 17.7M | ↓ Bajo promedio |
| Velo | 2.3M | ↓ Bajo promedio | 18.2M | ↓ Bajo promedio |
| Montana | 2.1M | ↓ Bajo promedio | 15.4M | ↓ Bajo promedio |
| Carretera | 1.8M | ⚠ Rezagado | 13.8M | ↓ Bajo promedio |

---

## How to Use

### 1. Clone the repository

```bash
git clone https://github.com/CSalcedoDataBI/powerbi-pbip-tools.git
cd powerbi-pbip-tools
```

### 2. Open the project

Double-click `examples/DAX-User-Defined-Functions/DAX User-Defined Functions.pbip`

Power BI Desktop will open the project with the semantic model and report already configured.

### 3. Refresh data

Click **Home → Refresh**. The data loads automatically from the public GitHub CSV — no local path configuration needed.

> **Note:** Power BI may ask you to set the data source privacy level to *Public* for the GitHub URL the first time you refresh.

### 4. Explore the functions

Go to **Model view → Functions** (left panel) to see all 6 UDFs with their TMDL source. You can edit them directly in the TMDL editor.

To inspect via DAX:

```dax
-- List all UDFs in the model
EVALUATE INFO.USERDEFINEDFUNCTIONS()
```

---

## TMDL Structure

```
DAX User-Defined Functions.SemanticModel/
└── definition/
    ├── database.tmdl          # Compatibility level 1702+ (required for UDFs)
    ├── functions.tmdl         # All 6 UDFs defined here
    ├── model.tmdl
    └── tables/
        ├── _Medidas.tmdl      # 11 measures (dedicated measures table)
        └── financials.tmdl    # Data table (loads from GitHub CSV)

DAX User-Defined Functions.Report/
└── definition/
    └── pages/
        └── PerformanceBand/
            ├── page.json
            └── visuals/
                ├── matrix/    # Product × (Profit, Profit Band, Sales, Sales Band)
                └── slicer/    # Year slicer
```

---

## Compatibility Requirements

- **Power BI Desktop:** June 2026 or later
- **Compatibility Level:** 1702+ (set in `database.tmdl`)
- **Internet access:** Required for data refresh (loads CSV from GitHub)

---

## References

- [Full article (Spanish)](https://www.csalcedodatabi.com/blog/dax-user-defined-functions-referencia/)
- [DAX UDF Overview — Microsoft Learn](https://learn.microsoft.com/en-us/power-bi/transform-model/desktop-user-defined-functions-overview)
- [Understanding parameter types — SQLBI](https://www.sqlbi.com/articles/understanding-parameter-types-in-dax-user-defined-functions-udf/)
- [DAX Lib — community UDF library](https://daxlib.org)
- [INFO.USERDEFINEDFUNCTIONS() — DAX reference](https://learn.microsoft.com/en-us/dax/info-userdefinedfunctions-function-dax)
