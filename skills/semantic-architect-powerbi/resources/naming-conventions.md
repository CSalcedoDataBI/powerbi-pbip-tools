# Naming Conventions

Guía de convenciones de nomenclatura para medidas DAX, descripciones y detección de columnas técnicas.

---

## Medidas DAX

### Formato de Nombres

Las medidas deben seguir estas convenciones:

| Patrón        | Ejemplo                                           | Cuándo usar                           |
| ------------- | ------------------------------------------------- | ------------------------------------- |
| `[Total X]`   | `[Total Sales]`, `[Total Revenue]`                | Sumas y agregaciones totales          |
| `[Avg X]`     | `[Avg Order Value]`, `[Avg Revenue per Customer]` | Promedios                             |
| `[X %]`       | `[Gross Margin %]`, `[Conversion Rate %]`         | Porcentajes y ratios                  |
| `[X Count]`   | `[Order Count]`, `[Customer Count]`               | Conteos con COUNTROWS o DISTINCTCOUNT |
| `[X YTD]`     | `[Revenue YTD]`, `[Sales YTD]`                    | Acumulados Year-to-Date               |
| `[X vs PY]`   | `[Revenue vs PY]`, `[Sales vs PY %]`              | Comparaciones con período anterior    |
| `[Min/Max X]` | `[Max Transaction Amount]`                        | Extremos                              |

### Anti-patrones (NO usar)

| ❌ Incorrecto         | ✅ Correcto         | Razón                             |
| --------------------- | ------------------- | --------------------------------- |
| `[sum_of_sales_amt]`  | `[Total Sales]`     | Sin underscores, lenguaje natural |
| `[M_Revenue_Total]`   | `[Total Revenue]`   | Sin prefijos técnicos             |
| `[KPI1]`              | `[Gross Margin %]`  | Nombre descriptivo, no códigos    |
| `[CALCULATEDMEASURE]` | `[Avg Order Value]` | Evitar nombres de funciones       |
| `[rev]`               | `[Total Revenue]`   | No abreviar                       |

---

## Descripciones de Tablas

### Estructura Estándar

```
[Tipo de tabla] que [función principal] con detalle de [dimensiones/granularidad clave].
```

**Ejemplos**:

- "Tabla de hechos que registra cada transacción de venta con detalle de producto, cliente y fecha."
- "Dimensión de calendario con jerarquías año → trimestre → mes → semana → día."
- "Tabla de lookup que contiene el catálogo de productos con categorías y subcategorías."

### Tipos de Tabla

| Prefijo detectado   | Tipo            | Descripción estándar                                             |
| ------------------- | --------------- | ---------------------------------------------------------------- |
| `Fact`, `fct`, `f_` | Tabla de hechos | "Tabla de hechos que registra..."                                |
| `Dim`, `dim`, `d_`  | Dimensión       | "Dimensión de [dominio] con..."                                  |
| `Bridge`, `brg`     | Puente          | "Tabla puente que resuelve la relación muchos-a-muchos entre..." |
| `Lookup`, `lkp`     | Lookup          | "Tabla de lookup que contiene el catálogo de..."                 |
| `Calendar`, `Date`  | Calendario      | "Dimensión de calendario con jerarquías..."                      |
| `_Measures`, `_KPI` | Medidas         | "Tabla auxiliar para organización de medidas DAX."               |

---

## Descripciones de Columnas

### Estructura Estándar

```
[Qué representa] [contexto adicional si aplica]. [Formato/unidad si aplica].
```

**Ejemplos**:

- "Identificador único del cliente asignado por el sistema. Clave primaria."
- "Fecha en que se realizó la transacción. Formato: YYYY-MM-DD."
- "Monto total de la línea de venta antes de impuestos. Moneda: USD."
- "Categoría principal del producto según el catálogo corporativo."

---

## Detección Automática de Columnas Técnicas (para Ocultar)

### Patrones de Claves Primarias (PK)

Ocultar automáticamente si el nombre coincide con:

```
SK_*          → Surrogate Key
PK_*          → Primary Key
*_SK          → Surrogate Key (sufijo)
*_PK          → Primary Key (sufijo)
*_Key         → Key column
*_ID          → ID column (con precaución — puede ser visible)
ID_*          → ID column
```

### Patrones de Claves Foráneas (FK)

Ocultar automáticamente:

```
FK_*          → Foreign Key
*_FK          → Foreign Key (sufijo)
*_ForeignKey  → Foreign Key
*_Ref         → Reference column
```

### Excepciones (NO ocultar)

Algunos campos con "ID" deben permanecer **visibles** porque tienen valor de negocio:

- `OrderID`, `InvoiceID`, `TicketID` → identificadores de negocio que el usuario consulta
- `EmployeeID`, `CustomerID` → pueden ser visibles si se usan en reportes
- `SKU`, `ISBN`, `ISIN` → códigos de negocio, no claves técnicas

> **Regla**: Si una columna con "ID" aparece sola (no como parte de una relación FK) y tiene valores legibles para el usuario de negocio, marcarla como **🔍 Revisar** en lugar de ocultar automáticamente.

---

## Formato de Medidas (Format Strings)

| Tipo de métrica | Formato DAX    | Ejemplo de output |
| --------------- | -------------- | ----------------- |
| Moneda          | `"$#,##0.00"`  | $1,234.56         |
| Porcentaje      | `"0.0%"`       | 45.3%             |
| Entero          | `"#,##0"`      | 1,234             |
| Decimal         | `"#,##0.00"`   | 1,234.56          |
| Días            | `"#,##0 days"` | 45 days           |
