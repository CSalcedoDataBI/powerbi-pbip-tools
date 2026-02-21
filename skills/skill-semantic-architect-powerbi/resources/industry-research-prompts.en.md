# Industry Research Prompts

Structured web search patterns for Phase 2 (Deep Research).
Replace `[INDUSTRY]` with the industry detected in Phase 1.

---

## Generic Prompts (Always Apply)

```
"Standard data dictionary for [INDUSTRY]"
"Key Performance Indicators for [INDUSTRY] analytics"
"Common DAX measures for [INDUSTRY] Power BI"
"Business questions for [INDUSTRY] reporting"
"[INDUSTRY] data warehouse star schema best practices"
```

---

## Industry-Specific Prompts

### Retail / E-Commerce

```
"Retail KPI dashboard Power BI measures"
"Sales analytics standard metrics retail"
"Customer segmentation KPIs retail industry"
"Inventory turnover ratio DAX calculation"
"Same-store sales analysis Power BI"
```

**Expected KPIs**: Total Revenue, Gross Margin %, Units Sold, Average Transaction Value, Customer Lifetime Value, Inventory Turnover, Sales per Square Foot.

### Healthcare

```
"Healthcare analytics KPIs hospital reporting"
"Patient outcomes metrics data dictionary"
"Clinical data standard terminology HL7"
"Healthcare revenue cycle management KPIs"
"Hospital bed occupancy rate DAX"
```

**Expected KPIs**: Patient Volume, Average Length of Stay, Bed Occupancy Rate, Readmission Rate, Revenue per Patient, Cost per Case.

### Finance / Banking

```
"Financial services KPI dashboard metrics"
"Banking data dictionary standard"
"Loan portfolio analytics Power BI"
"Financial risk metrics reporting"
"Net interest margin DAX calculation"
```

**Expected KPIs**: Net Interest Margin, Return on Assets, Loan-to-Deposit Ratio, Non-Performing Loan Ratio, Cost-to-Income Ratio.

### Manufacturing

```
"Manufacturing KPIs OEE Power BI"
"Production analytics standard metrics"
"Supply chain data dictionary"
"Overall equipment effectiveness DAX"
"Manufacturing defect rate analysis"
```

**Expected KPIs**: OEE (Overall Equipment Effectiveness), Yield Rate, Defect Rate, Cycle Time, Throughput, Inventory Days of Supply.

### Human Resources / HR / Staffing

```
"HR analytics KPIs workforce reporting"
"Staffing industry metrics standard"
"Employee turnover rate DAX calculation"
"Workforce analytics Power BI dashboard"
"Recruitment funnel metrics"
```

**Expected KPIs**: Headcount, Turnover Rate, Time to Fill, Cost per Hire, Revenue per Employee, Absenteeism Rate, Bill Rate, Pay Rate, Spread/Margin.

### Education

```
"Education analytics KPIs student performance"
"Higher education data dictionary"
"Student retention rate analysis Power BI"
"Academic performance metrics reporting"
```

**Expected KPIs**: Enrollment Count, Retention Rate, Graduation Rate, GPA Distribution, Student-to-Faculty Ratio, Course Completion Rate.

### Logistics / Supply Chain

```
"Supply chain KPIs logistics analytics"
"Freight and transportation data dictionary"
"On-time delivery rate DAX Power BI"
"Warehouse efficiency metrics"
```

**Expected KPIs**: On-Time Delivery Rate, Order Fulfillment Rate, Inventory Accuracy, Freight Cost per Unit, Warehouse Capacity Utilization.

---

## Enrichment with Internal Documents

If the user provides documents, look for:

### M Code (Power Query)

- Analyze transformations to deduce business logic
- Search for calculated columns and their purpose
- Identify data sources and connections

### Corporate PDFs

- Extract mentioned business rules
- Identify official metric definitions
- Map internal terminology to column names

### Data Dictionaries

- Map each column to its official definition
- Identify documented primary and foreign keys
- Extract data validation rules
