# Naming Conventions

Guía de nombrado para medidas DAX, descripciones y detección automática de columnas técnicas.

---

## Medidas DAX

### Formato Estándar

```
[Verbo/Adj + Sustantivo]   →  [Total Sales], [Avg Revenue per Customer]
```

### Reglas

1. **Title Case**: Cada palabra en mayúscula
2. **Sin prefijos técnicos**: Nunca `SUM_`, `CALC_`, `M_`
3. **Lenguaje de negocio**: `[Total Revenue]` no `[sum_of_sales_amount]`
4. **Unidades implícitas**: No incluir unidades, usar Format String
5. **Categoría como sufijo** (si ambigüedad): `[Avg Days to Close (Sales)]`

### Patrones Comunes

| Patrón        | Ejemplo                          |
|---------------|----------------------------------|
| Total + Noun  | `[Total Sales]`                  |
| Avg + Noun    | `[Avg Order Value]`              |
| Count + Noun  | `[Customer Count]`               |
| % + Noun      | `[Margin %]`                     |
| Noun + Rate   | `[Conversion Rate]`              |
| Noun + Ratio  | `[Debt-to-Equity Ratio]`         |
| YTD/MTD       | `[Sales YTD]`                    |
| vs + Period   | `[Sales vs Last Year]`           |

### Anti-patrones (❌ Evitar)

| ❌ Incorrecto                | ✅ Correcto                    |
|-----------------------------|-------------------------------|
| `[sum_of_sales_amt]`        | `[Total Sales]`               |
| `[M_Revenue_Calc]`          | `[Total Revenue]`             |
| `[Measure 1]`               | `[Gross Margin %]`            |
| `[CALCULATE_Sales_DATESYTD]`| `[Sales YTD]`                 |
| `[Total Sales USD]`         | `[Total Sales]` + $#,0        |

---

## Descripciones

### Formato para Tablas

```
[Tipo]: [Propósito principal]. [Detalle clave].
```

**Ejemplos**:
- `Fact table recording each sales transaction. Grain: one row per order line item.`
- `Date dimension with standard calendar hierarchies (Year → Quarter → Month → Day).`
- `Customer master with demographic and segmentation attributes.`

### Formato para Columnas

```
[Qué representa]. [Contexto si es necesario].
```

**Ejemplos**:
- `Unit selling price before discounts.`
- `Customer acquisition channel (Online, Retail, Partner, Direct).`
- `Unique product identifier. Links to DimProduct[ProductKey].`

---

## Detección Automática: Columnas Técnicas a Ocultar

### Patrones de Clave Primaria/Foránea

Detectar y marcar como **🔒 Hide** las columnas que coincidan con:

| Patrón              | Ejemplos                                        |
|---------------------|--------------------------------------------------|
| `*_Key`             | `ProductKey`, `Customer_Key`                     |
| `*_ID`              | `Sales_ID`, `CustomerID`                         |
| `SK_*`              | `SK_Customer`, `SK_Date`                         |
| `FK_*`              | `FK_ProductKey`, `FK_Store`                      |
| `PK_*`              | `PK_OrderID`                                     |
| `*_SK`              | `Customer_SK`, `Product_SK`                      |
| `*_PK`              | `Order_PK`                                       |
| `ID` (solo)         | `ID`                                             |
| `Key` (solo)        | `Key`                                            |

### Excepciones (NO ocultar)

- Columnas que son la **única columna de texto** de una dimensión (probablemente es la label)
- Columnas llamadas `ID` que son **identificadores de negocio** visibles (e.g., `OrderID`, `InvoiceID`)
- En caso de duda → marcar como **🔍 Review**

### Columnas Ambiguas (🔍 Review)

Marcar para revisión manual cuando:

1. El nombre no sigue ningún patrón reconocible: `Col_14`, `Field_A`
2. El nombre es genérico pero no técnico: `Value`, `Amount`, `Status`
3. El nombre parece código interno: `XREF_001`, `TMP_calc`
4. Columnas con nombres truncados o abreviados: `Cust_Nm`, `Prod_Desc_S`

> [!TIP]
> Cuando una columna se marca como 🔍 Review, incluir una nota con la razón:
> `"⚠️ Unrecognized pattern — requires manual validation"`
