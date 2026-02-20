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
