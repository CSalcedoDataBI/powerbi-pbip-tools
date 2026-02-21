# Ejemplo: Context Store — Contoso Retail

> Generado por: Power BI Semantic Architect Skill
> Modelo: Contoso_Sales
> Industria: Retail
> Arquitectura: Estrella (Star Schema)
> Fecha: 2026-01-15

---

## 1. Industry Overview

### Industria: Retail

La industria del retail abarca la venta de productos directamente al consumidor final a través de canales físicos y digitales. El análisis de datos en retail se centra en optimizar ventas, gestionar inventarios, entender el comportamiento del cliente y maximizar márgenes de beneficio.

### Desafíos Analíticos Clave

- **Estacionalidad**: Identificar y predecir picos de demanda (Black Friday, fiestas, vuelta al colegio)
- **Omnicanalidad**: Unificar métricas de tiendas físicas, e-commerce y marketplaces
- **Margen por producto**: Distinguir entre productos de alto volumen/bajo margen vs. bajo volumen/alto margen

### Contexto de Negocio Detectado

Modelo Contoso Sales con estructura estrella clásica: 1 tabla de hechos (ventas) rodeada de dimensiones de producto, cliente, tienda, fecha y geografía. Modelo preparado para análisis multidimensional con jerarquías naturales.

---

## 2. Metadata Proposal

### Tablas

| Tabla           | Tipo      | Descripción de Negocio                                                                                 | Acción     |
| --------------- | --------- | ------------------------------------------------------------------------------------------------------- | ---------- |
| `FactSales`     | Hecho     | Tabla de hechos que registra cada transacción de venta. Grano: una fila por línea de pedido.            | ✅ Visible |
| `DimProduct`    | Dimensión | Catálogo maestro de productos con categoría, subcategoría, marca y atributos físicos.                   | ✅ Visible |
| `DimCustomer`   | Dimensión | Maestro de clientes con datos demográficos, segmentación y canal de adquisición.                        | ✅ Visible |
| `DimStore`      | Dimensión | Catálogo de tiendas físicas con ubicación, tamaño, tipo y fecha de apertura.                             | ✅ Visible |
| `DimDate`       | Dimensión | Dimensión calendario estándar con jerarquías Año → Trimestre → Mes → Día.                               | ✅ Visible |
| `DimGeography`  | Dimensión | Jerarquía geográfica: País → Estado → Ciudad. Vinculada a tiendas y clientes.                           | ✅ Visible |

### Columnas (Muestra)

| Tabla         | Columna          | Tipo     | Descripción de Negocio                                                  | Acción     |
| ------------- | ---------------- | -------- | ----------------------------------------------------------------------- | ---------- |
| `FactSales`   | `SalesKey`       | Int64    | Clave sustituta de la transacción. Uso interno.                         | 🔒 Hide   |
| `FactSales`   | `OrderDate`      | DateTime | Fecha en que se realizó el pedido.                                      | ✅ Visible |
| `FactSales`   | `Quantity`       | Int64    | Unidades vendidas en esta línea de pedido.                              | ✅ Visible |
| `FactSales`   | `UnitPrice`      | Decimal  | Precio unitario de venta antes de descuentos.                           | ✅ Visible |
| `FactSales`   | `DiscountAmount` | Decimal  | Monto del descuento aplicado a esta línea.                              | ✅ Visible |
| `FactSales`   | `FK_ProductKey`  | Int64    | Clave foránea que conecta la venta con el producto.                     | 🔒 Hide   |
| `FactSales`   | `FK_CustomerKey` | Int64    | Clave foránea que conecta la venta con el cliente.                      | 🔒 Hide   |
| `FactSales`   | `FK_StoreKey`    | Int64    | Clave foránea que conecta la venta con la tienda.                       | 🔒 Hide   |
| `DimProduct`  | `ProductKey`     | Int64    | Clave primaria del producto. Uso interno.                               | 🔒 Hide   |
| `DimProduct`  | `ProductName`    | String   | Nombre comercial del producto para visualización.                       | ✅ Visible |
| `DimProduct`  | `Category`       | String   | Categoría principal del producto (Electrónica, Ropa, Hogar...).         | ✅ Visible |
| `DimProduct`  | `SubCategory`    | String   | Subcategoría dentro de la categoría principal.                           | ✅ Visible |
| `DimProduct`  | `Brand`          | String   | Marca del fabricante.                                                   | ✅ Visible |
| `DimProduct`  | `UnitCost`       | Decimal  | Costo unitario de adquisición del producto.                             | ✅ Visible |
| `DimProduct`  | `Col_14`         | String   | ⚠️ _Patrón no reconocido — requiere validación manual_.                 | 🔍 Review |
| `DimCustomer` | `CustomerKey`    | Int64    | Clave primaria del cliente. Uso interno.                                | 🔒 Hide   |
| `DimCustomer` | `CustomerName`   | String   | Nombre completo del cliente.                                            | ✅ Visible |
| `DimCustomer` | `Gender`         | String   | Género del cliente (M/F/Otro).                                          | ✅ Visible |
| `DimCustomer` | `AgeGroup`       | String   | Rango de edad del cliente (18-25, 26-35, 36-45...).                     | ✅ Visible |

### Relaciones

| Desde                       | Hacia                       | Cardinalidad | Estado     |
| --------------------------- | --------------------------- | ------------ | ---------- |
| `FactSales.FK_ProductKey`   | `DimProduct.ProductKey`     | Many-to-One  | ✅ Correcta |
| `FactSales.FK_CustomerKey`  | `DimCustomer.CustomerKey`   | Many-to-One  | ✅ Correcta |
| `FactSales.FK_StoreKey`     | `DimStore.StoreKey`         | Many-to-One  | ✅ Correcta |
| `FactSales.OrderDate`       | `DimDate.Date`              | Many-to-One  | ✅ Correcta |
| `DimStore.FK_GeographyKey`  | `DimGeography.GeographyKey` | Many-to-One  | ✅ Correcta |

---

## 3. KPI Catalog

### Medidas Propuestas

#### Total Revenue

```dax
[Total Revenue] =
    SUMX(
        FactSales,
        FactSales[Quantity] * FactSales[UnitPrice]
    )
```

- **Justificación**: Ingreso bruto total antes de descuentos. Métrica fundamental en retail.
- **Business Question**: "¿Cuál fue el ingreso total del período?"
- **Categoría**: Revenue
- **Formato**: $#,0

#### Gross Margin %

```dax
[Gross Margin %] =
    DIVIDE(
        [Total Revenue] - [Total Cost],
        [Total Revenue],
        0
    )
```

- **Justificación**: Porcentaje de beneficio bruto. Indicador clave de rentabilidad.
- **Business Question**: "¿Qué margen de beneficio estamos obteniendo?"
- **Categoría**: Profitability
- **Formato**: 0.0%

#### Total Cost

```dax
[Total Cost] =
    SUMX(
        FactSales,
        FactSales[Quantity] * RELATED(DimProduct[UnitCost])
    )
```

- **Justificación**: Costo total de los productos vendidos.
- **Business Question**: "¿Cuánto nos costó el inventario vendido?"
- **Categoría**: Cost
- **Formato**: $#,0

#### Units Sold

```dax
[Units Sold] =
    SUM(FactSales[Quantity])
```

- **Justificación**: Volumen total de unidades vendidas.
- **Business Question**: "¿Cuántas unidades vendimos?"
- **Categoría**: Volume
- **Formato**: #,0

#### Avg Transaction Value

```dax
[Avg Transaction Value] =
    DIVIDE(
        [Total Revenue],
        DISTINCTCOUNT(FactSales[SalesKey]),
        0
    )
```

- **Justificación**: Valor promedio por transacción. Indicador de upselling.
- **Business Question**: "¿Cuánto gasta un cliente en promedio por compra?"
- **Categoría**: Efficiency
- **Formato**: $#,0.00

#### Customer Count

```dax
[Customer Count] =
    DISTINCTCOUNT(FactSales[FK_CustomerKey])
```

- **Justificación**: Número de clientes únicos con al menos una compra.
- **Business Question**: "¿Cuántos clientes activos tenemos?"
- **Categoría**: Customer
- **Formato**: #,0

---

## 4. Resumen de Auditoría

| Categoría                 | Total | Aprobadas | Pendientes |
| ------------------------- | ----- | --------- | ---------- |
| Descripciones de tablas   | 6     | —         | —          |
| Descripciones de columnas | 19    | —         | —          |
| Columnas a ocultar        | 7     | —         | —          |
| Columnas en revisión      | 1     | —         | —          |
| KPIs propuestos           | 6     | —         | —          |

### Pendientes de Revisión Manual

| Tabla        | Columna  | Razón                                 |
| ------------ | -------- | ------------------------------------- |
| `DimProduct` | `Col_14` | Patrón no reconocido, origen desconocido |

> **Estado**: ⏳ Pendiente de auditoría del experto
