---
name: Power BI Semantic Architect
description: Transforms technical Power BI data models into documented semantic models — generates descriptions, KPIs, and a complete Context Store using MCP as a bidirectional communication bridge. The analyst shifts from manual builder to Intelligence Auditor.
---

# Power BI Semantic Architect

This skill automates the complete documentation of a Power BI data model. Using the Model Context Protocol (MCP) as a bidirectional bridge, the agent reads the model’s metadata, researches the industry, generates a semantic Context Store and — after expert validation — writes descriptions + KPIs directly into the model.

## Clone Only This Skill

```bash
git clone --filter=blob:none --sparse https://github.com/CSalcedoDataBI/powerbi-pbip-tools.git
cd powerbi-pbip-tools
git sparse-checkout set skills/skill-semantic-architect-powerbi
```

## When to Use This Skill

Use it when:

- You need to **document an existing Power BI model** (table, column, and measure descriptions)
- The user says "document the model", "generate descriptions", "create KPIs", "semantic architect" or similar
- A **Context Store** (semantic map) of a model is needed for future queries
- You need to **automatically hide** foreign/primary keys from the fields panel
- You want to **create standard DAX measures** based on the model’s industry

## Prerequisites

| Component              | Tool                  | Why it’s needed                                   |
| ---------------------- | --------------------- | ------------------------------------------------- |
| **Model connection**   | MCP Server (Power BI) | Reading and writing model metadata                |
| **Research**           | Web Search            | Finding KPIs and industry standards               |
| **Processing**         | File Reader           | Analyzing PDFs, M code, and technical documents   |

> [!IMPORTANT]
> The Power BI MCP Server must be enabled and connected to the active model before starting. Without it, phases 1 and 4 cannot run.

---

## Workflow: 4 Phases

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   PHASE 1   │───▶│   PHASE 2   │───▶│   PHASE 3   │───▶│   PHASE 4   │
│  Model DNA  │    │   Deep      │    │  Context    │    │  Audit      │
│  Scan       │    │  Research   │    │  Store      │    │ + Execution │
│             │    │             │    │             │    │             │
│ 🤖 Auto    │    │ 🤖 Auto    │    │ 🤖 Auto    │    │ 👤 + 🤖    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### Phase 1 — Model DNA Scan

**Goal**: Extract the complete model structure and classify the industry.

**Actions**:

1. **Extract metadata via MCP**: List all tables, columns, data types, and relationships from the active model.
2. **Classify the industry** by analyzing naming patterns:
   - `DimPatient`, `FactClaim` → **Healthcare**
   - `DimProduct`, `FactSalesOrder` → **Retail**
   - `Medical_Records` → **Healthcare**
   - `Tickets_Sold` → **Entertainment**
   - `Invoice_Lines` → **Billing**
   - If unclear, **ask the user** before continuing.
3. **Identify the model architecture**:
   - **Star**: Dim and Fact tables clearly separated
   - **Snowflake**: Dimensions normalized across multiple levels
   - **Flat Table**: No clear dimensional structure
4. **Inventory existing measures**: List any existing DAX measures to avoid duplication.

**Output**: Structured list of tables, columns, relationships, detected industry, and identified architecture.

---

### Phase 2 — Deep Research

**Goal**: Enrich context with industry knowledge.

**Actions**:

1. **Advanced web search** using these patterns:
   - `"Standard data dictionary for [INDUSTRY]"`
   - `"Key Performance Indicators for [INDUSTRY] analytics"`
   - `"Common DAX measures for [INDUSTRY] Power BI"`
   - `"Business questions for [INDUSTRY] reporting"`

   See `resources/industry-research-prompts.md` for additional industry-specific patterns.

2. **Collect**:
   - **Industry-standard KPIs** — the "gold standard" indicators any analyst would expect
   - **Frequent Business Questions** — the questions stakeholders ask
   - **Validated technical logic** — proven DAX formulas and calculation patterns

3. **Enrich with internal documents** (if provided by the user):
   - Power Query M code → deduce business logic from calculated columns
   - Corporate PDFs → extract specific business rules
   - Data dictionaries → map technical names to business meanings

> [!NOTE]
> The key differentiator is the cross-reference: **what the world knows about the industry + the user’s specific business rules**.

4. **Save research findings** in `projects/{model-name}/research-notes.md`.

**Output**: `research-notes.md` file with proposed KPIs, Business Questions, and business descriptions for each model object.

---

### Phase 3 — Context Store Construction

**Goal**: Consolidate all intelligence into a structured Markdown file.

**Actions**:

1. **Generate the Context Store** using the template in `resources/context-store-template.md`.
2. **Complete the three sections**:

#### Section 1: Industry Overview

Executive summary of the industry, its key analytical challenges, and the detected business context.

#### Section 2: Metadata Proposal

Table with a proposal for each model object:

| Original Object | Suggested Business Description                              | Action     |
| --------------- | ------------------------------------------------------------ | ---------- |
| `FactSales`     | Fact table recording each sales transaction...               | ✅ Visible |
| `DimDate`       | Calendar dimension with year → quarter → month hierarchies... | ✅ Visible |
| `SK_CustomerID` | Customer dimension surrogate key. Internal use               | 🔒 Hide   |
| `FK_ProductKey` | Foreign key connecting sales to products                     | 🔒 Hide   |
| `Col_14`        | ⚠️ _Requires manual review — unrecognized pattern_           | 🔍 Review |

**Action classification rules**:

- Columns with prefixes `SK_`, `FK_`, `ID_`, `Key` or suffixes `_Key`, `_ID` → **🔒 Hide**
- Columns with unrecognizable patterns → **🔍 Review** (flag for manual review)
- Everything else → **✅ Visible**

See `resources/naming-conventions.md` for complete patterns.

#### Section 3: KPI Catalog

Catalog of suggested DAX measures with business justification:

```dax
// Example:
[Total Revenue] =
    SUMX(
        FactSales,
        FactSales[Quantity] * FactSales[UnitPrice]
    )

// Justification: Total gross revenue before discounts.
// Retail industry standard for executive reports.
// Business Question: "What was the total revenue for the period?"
```

3. **Save the file** in `projects/{model-name}/context-store.md`.

> [!IMPORTANT]
> The Context Store is not a disposable file. It’s a **reusable asset** that functions as contextual memory (RAG) for future interactions with the model.

**Output**: Complete `projects/{model-name}/context-store.md` with all three sections, ready for review.

---

### Phase 4 — Expert Audit and Direct Execution

**Goal**: Human validation and direct writing to the model.

> [!CAUTION]
> **ABSOLUTE RULE**: The AI NEVER modifies the model without explicit user approval. The expert has the final word. Always use `notify_user` to present the Context Store and request confirmation before writing.

**Actions**:

1. **Present the Context Store** to the user using `notify_user` with the file in `PathsToReview`.
2. **Request explicit confirmation** with a summary:
   - ☑ X column descriptions ready
   - ☑ X KPIs proposed
   - ☐ X columns flagged for manual review
   - Ask: "Shall I proceed with writing to the model?"
3. **Only after user confirmation ("Execute", "Apply", "Go")**, execute via MCP:
   - **Update the `Description` property** of each approved table and column
   - **Hide primary and foreign keys** (change visibility) for columns marked as 🔒
   - **Create DAX measures** in their respective tables with standard naming

4. **Save audit log** in `projects/{model-name}/audit-log.md`.

5. **Report results** to the user.

**Output**: Updated Power BI model + `projects/{model-name}/audit-log.md` with complete record.

---

## Golden Rules (Constraints)

### 🔒 Privacy
- **Metadata only**: Never request or process row data (records). Only work with the model structure.

### 🎯 Precision
- If a column has no recognizable pattern, mark it as **"🔍 Manual Review"** in the Context Store.
- Never invent meanings for ambiguous columns.
- Verify that proposed DAX measures use column names that actually exist in the model.

### ✨ Aesthetics
- Clean naming for measures: `[Total Sales]`, `[Avg Revenue per Customer]` — never `[sum_of_sales_amt]`.
- Business-language descriptions, not technical: "Total revenue per transaction" — not "SUM of amount column".
- See `resources/naming-conventions.md` for the complete guide.

### 🛡️ Execution Safety
- Phase 4 (writing) ALWAYS requires explicit user approval.
- Before creating measures, verify no measures with the same name exist.
- Before hiding columns, confirm they are not being used in visualizations.

---

## Reference Files

| File                     | Path                                     | Purpose                                            |
| ------------------------ | ---------------------------------------- | -------------------------------------------------- |
| Context Store Template   | `resources/context-store-template.md`    | Base structure for the context file                 |
| Research Prompts         | `resources/industry-research-prompts.md` | Web search patterns by industry                    |
| Naming Conventions       | `resources/naming-conventions.md`        | Naming rules for measures and descriptions         |
| Retail Example           | `examples/retail-example.md`             | Complete example Context Store for Retail industry  |

---

## Output Files

```
projects/
└── {model-name}/
    ├── context-store.md           ← Phase 3: Complete semantic map
    ├── research-notes.md          ← Phase 2: Research findings
    └── audit-log.md               ← Phase 4: Record of applied changes
```

---

## Usage Example

**User**: "Document this Power BI model and generate the KPIs"

**Agent**:

1. Connects via MCP → extracts 12 tables, 87 columns, 15 relationships
2. Detects industry: **Retail** (based on `DimProduct`, `FactSales`, `DimCustomer`)
3. Researches standard Retail KPIs → proposes 8 DAX measures
4. Generates `projects/Contoso_Sales/context-store.md` with Industry Overview + 87 descriptions + 8 KPIs
5. Presents to user for audit → user approves 85 descriptions, adjusts 2 KPIs
6. Executes writing via MCP → model updated in ~2 minutes
