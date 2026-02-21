# Naming Conventions

Naming guide for DAX measures, descriptions, and automatic detection of technical columns.

---

## DAX Measures

### Standard Format

```
[Verb/Adj + Noun]   →  [Total Sales], [Avg Revenue per Customer]
```

### Rules

1. **Title Case**: Capitalize each word
2. **No technical prefixes**: Never `SUM_`, `CALC_`, `M_`
3. **Business language**: `[Total Revenue]` not `[sum_of_sales_amount]`
4. **Implicit units**: Don't include units, use Format String instead
5. **Category as suffix** (if ambiguous): `[Avg Days to Close (Sales)]`

### Common Patterns

| Pattern       | Example                          |
|---------------|----------------------------------|
| Total + Noun  | `[Total Sales]`                  |
| Avg + Noun    | `[Avg Order Value]`              |
| Count + Noun  | `[Customer Count]`               |
| % + Noun      | `[Margin %]`                     |
| Noun + Rate   | `[Conversion Rate]`              |
| Noun + Ratio  | `[Debt-to-Equity Ratio]`         |
| YTD/MTD       | `[Sales YTD]`                    |
| vs + Period   | `[Sales vs Last Year]`           |

### Anti-patterns (❌ Avoid)

| ❌ Wrong                     | ✅ Correct                     |
|-----------------------------|-------------------------------|
| `[sum_of_sales_amt]`        | `[Total Sales]`               |
| `[M_Revenue_Calc]`          | `[Total Revenue]`             |
| `[Measure 1]`               | `[Gross Margin %]`            |
| `[CALCULATE_Sales_DATESYTD]`| `[Sales YTD]`                 |
| `[Total Sales USD]`         | `[Total Sales]` + $#,0        |

---

## Descriptions

### Table Description Format

```
[Type]: [Main purpose]. [Key detail].
```

**Examples**:
- `Fact table recording each sales transaction. Grain: one row per order line item.`
- `Date dimension with standard calendar hierarchies (Year → Quarter → Month → Day).`
- `Customer master with demographic and segmentation attributes.`

### Column Description Format

```
[What it represents]. [Context if needed].
```

**Examples**:
- `Unit selling price before discounts.`
- `Customer acquisition channel (Online, Retail, Partner, Direct).`
- `Unique product identifier. Links to DimProduct[ProductKey].`

---

## Automatic Detection: Technical Columns to Hide

### Primary/Foreign Key Patterns

Detect and mark as **🔒 Hide** columns matching:

| Pattern             | Examples                                         |
|---------------------|--------------------------------------------------|
| `*_Key`             | `ProductKey`, `Customer_Key`                     |
| `*_ID`              | `Sales_ID`, `CustomerID`                         |
| `SK_*`              | `SK_Customer`, `SK_Date`                         |
| `FK_*`              | `FK_ProductKey`, `FK_Store`                      |
| `PK_*`              | `PK_OrderID`                                     |
| `*_SK`              | `Customer_SK`, `Product_SK`                      |
| `*_PK`              | `Order_PK`                                       |
| `ID` (standalone)   | `ID`                                             |
| `Key` (standalone)  | `Key`                                            |

### Exceptions (Do NOT hide)

- Columns that are the **only text column** in a dimension (likely the label)
- Columns named `ID` that are **visible business identifiers** (e.g., `OrderID`, `InvoiceID`)
- When in doubt → mark as **🔍 Review**

### Ambiguous Columns (🔍 Review)

Flag for manual review when:

1. Name doesn't follow any recognizable pattern: `Col_14`, `Field_A`
2. Name is generic but not technical: `Value`, `Amount`, `Status`
3. Name looks like internal code: `XREF_001`, `TMP_calc`
4. Columns with truncated or abbreviated names: `Cust_Nm`, `Prod_Desc_S`

> [!TIP]
> When a column is marked as 🔍 Review, include a note with the reason:
> `"⚠️ Unrecognized pattern — requires manual validation"`
