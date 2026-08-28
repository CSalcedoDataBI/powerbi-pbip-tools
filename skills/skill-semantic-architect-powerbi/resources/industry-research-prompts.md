# Industry Research Prompts

Patrones de búsqueda web estructurados para la Fase 2 (Deep Research).
Reemplazar `[INDUSTRY]` con la industria detectada en Fase 1.

---

## Prompts Genéricos (Aplicar Siempre)

```
"Standard data dictionary for [INDUSTRY]"
"Key Performance Indicators for [INDUSTRY] analytics"
"Common DAX measures for [INDUSTRY] Power BI"
"Business questions for [INDUSTRY] reporting"
"[INDUSTRY] data warehouse star schema best practices"
```

---

## Prompts por Industria

### Retail / E-Commerce

```
"Retail KPI dashboard Power BI measures"
"Sales analytics standard metrics retail"
"Customer segmentation KPIs retail industry"
"Inventory turnover ratio DAX calculation"
"Same-store sales analysis Power BI"
```

**KPIs esperados**: Total Revenue, Gross Margin %, Units Sold, Average Transaction Value, Customer Lifetime Value, Inventory Turnover, Sales per Square Foot.

### Salud / Healthcare

```
"Healthcare analytics KPIs hospital reporting"
"Patient outcomes metrics data dictionary"
"Clinical data standard terminology HL7"
"Healthcare revenue cycle management KPIs"
"Hospital bed occupancy rate DAX"
```

**KPIs esperados**: Patient Volume, Average Length of Stay, Bed Occupancy Rate, Readmission Rate, Revenue per Patient, Cost per Case.

### Finanzas / Banking

```
"Financial services KPI dashboard metrics"
"Banking data dictionary standard"
"Loan portfolio analytics Power BI"
"Financial risk metrics reporting"
"Net interest margin DAX calculation"
```

**KPIs esperados**: Net Interest Margin, Return on Assets, Loan-to-Deposit Ratio, Non-Performing Loan Ratio, Cost-to-Income Ratio.

### Manufactura / Manufacturing

```
"Manufacturing KPIs OEE Power BI"
"Production analytics standard metrics"
"Supply chain data dictionary"
"Overall equipment effectiveness DAX"
"Manufacturing defect rate analysis"
```

**KPIs esperados**: OEE (Overall Equipment Effectiveness), Yield Rate, Defect Rate, Cycle Time, Throughput, Inventory Days of Supply.

### Recursos Humanos / HR / Staffing

```
"HR analytics KPIs workforce reporting"
"Staffing industry metrics standard"
"Employee turnover rate DAX calculation"
"Workforce analytics Power BI dashboard"
"Recruitment funnel metrics"
```

**KPIs esperados**: Headcount, Turnover Rate, Time to Fill, Cost per Hire, Revenue per Employee, Absenteeism Rate, Bill Rate, Pay Rate, Spread/Margin.

### Educación / Education

```
"Education analytics KPIs student performance"
"Higher education data dictionary"
"Student retention rate analysis Power BI"
"Academic performance metrics reporting"
```

**KPIs esperados**: Enrollment Count, Retention Rate, Graduation Rate, GPA Distribution, Student-to-Faculty Ratio, Course Completion Rate.

### Logística / Supply Chain

```
"Supply chain KPIs logistics analytics"
"Freight and transportation data dictionary"
"On-time delivery rate DAX Power BI"
"Warehouse efficiency metrics"
```

**KPIs esperados**: On-Time Delivery Rate, Order Fulfillment Rate, Inventory Accuracy, Freight Cost per Unit, Warehouse Capacity Utilization.

---

## Enriquecimiento con Documentos Internos

Si el usuario proporciona documentos, buscar:

### Energía / Utilities

```
"Energy utilities KPIs analytics reporting"
"Power generation data dictionary standard"
"Energy consumption analytics Power BI"
"Renewable energy performance metrics"
"Utility billing analytics DAX"
```

**KPIs esperados**: Energy Production (MWh), Capacity Factor %, SAIDI (System Average Interruption Duration), Customer Satisfaction Score, Revenue per kWh, Distribution Loss Rate.

### Seguros / Insurance

```
"Insurance analytics KPIs reporting"
"Claims management data dictionary"
"Loss ratio analysis Power BI DAX"
"Insurance underwriting metrics"
"Actuarial KPIs dashboard"
```

**KPIs esperados**: Loss Ratio, Combined Ratio, Claims Frequency, Average Claim Severity, Premiums Written, Customer Retention Rate, Expense Ratio.

### Telecomunicaciones

```
"Telecom KPIs analytics churn reporting"
"Telecommunications data dictionary standard"
"ARPU ARPA analysis Power BI DAX"
"Network performance metrics dashboard"
"Mobile subscriber analytics"
```

**KPIs esperados**: ARPU (Average Revenue per User), Churn Rate, Costo de Adquisición por Cliente, Network Uptime %, Consumo de Datos por Suscriptor, NPS (Net Promoter Score), Subscriber Growth Rate.

### Gobierno / Sector Público

```
"Government public sector KPIs analytics"
"Public administration data dictionary"
"Budget execution analysis Power BI"
"Government performance metrics reporting"
"Public services efficiency dashboard"
```

**KPIs esperados**: Budget Execution Rate, Costo por Unidad de Servicio, Índice de Satisfacción Ciudadana, Service Request Resolution Rate, Beneficiary Count, Audit Compliance Rate.

---

## Enriquecimiento con Documentos Internos

Si el usuario proporciona documentos, buscar:

### Código M (Power Query)

- Analizar transformaciones para deducir lógica de negocio
- Buscar columnas calculadas y su propósito
- Identificar fuentes de datos y conexiones

### PDFs Corporativos

- Extraer reglas de negocio mencionadas
- Identificar definiciones de métricas oficiales
- Mapear terminología interna a nombres de columnas

### Diccionarios de Datos

- Mapear cada columna a su definición oficial
- Identificar claves primarias y foráneas documentadas
- Extraer reglas de validación de datos
