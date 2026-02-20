# Context Store — Contoso Retail (Ejemplo)

> Generado por: Power BI Semantic Architect Skill
> Modelo: Contoso Sales
> Industria detectada: Retail
> Arquitectura: Estrella (Star Schema)
> Fecha: 2026-02-20

---

## 1. Industry Overview

### Industria: Retail

El sector Retail abarca la venta de productos al consumidor final a través de canales físicos y digitales. Los modelos analíticos en esta industria típicamente se centran en el comportamiento de compra del cliente, la eficiencia del inventario y la rentabilidad por producto, tienda y período.

### Desafíos Analíticos Clave

- **Estacionalidad**: Las ventas varían significativamente por temporada, requiriendo análisis YoY y comparaciones período-a-período.
- **Margen variable**: Los márgenes difieren por categoría de producto; es crítico medir la rentabilidad a nivel granular.
- **Rotación de inventario**: El balance entre stock disponible y ventas perdidas por falta de inventario es un KPI central.

### Contexto de Negocio Detectado

Modelo Contoso Sales con esquema estrella clásico: tabla de hechos `FactSales` conectada a dimensiones de producto, cliente, tienda, fecha y geografía. El modelo incluye precios unitarios, cantidades, costos y descuentos, lo que permite calcular métricas de margen completas.

---

## 2. Metadata Proposal

### Tablas

| Tabla          | Tipo      | Descripción de Negocio                                                                                                                              | Acción     |
| -------------- | --------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| `FactSales`    | Hechos    | Tabla de hechos que registra cada transacción de venta con detalle de producto, cliente, tienda y fecha. Granularidad: una fila por línea de venta. | ✅ Visible |
| `DimProduct`   | Dimensión | Dimensión de productos con jerarquía categoría → subcategoría → producto. Incluye atributos como marca, color y precio de lista.                    | ✅ Visible |
| `DimCustomer`  | Dimensión | Dimensión de clientes con datos demográficos, segmento y ubicación geográfica.                                                                      | ✅ Visible |
| `DimStore`     | Dimensión | Dimensión de tiendas con ubicación, tipo (física/online) y zona geográfica.                                                                         | ✅ Visible |
| `DimDate`      | Dimensión | Dimensión de calendario con jerarquías año → trimestre → mes → semana → día. Incluye atributos fiscales.                                            | ✅ Visible |
| `DimGeography` | Dimensión | Dimensión geográfica con jerarquía país → estado → ciudad.                                                                                          | ✅ Visible |

### Columnas

| Tabla         | Columna          | Tipo de Dato | Descripción de Negocio                                                                                  | Acción     |
| ------------- | ---------------- | ------------ | ------------------------------------------------------------------------------------------------------- | ---------- |
| `FactSales`   | `SK_SalesKey`    | Integer      | Clave subrogada de la tabla de hechos de ventas. Uso interno del modelo.                                | 🔒 Ocultar |
| `FactSales`   | `FK_ProductKey`  | Integer      | Clave foránea que conecta la venta con el producto vendido.                                             | 🔒 Ocultar |
| `FactSales`   | `FK_CustomerKey` | Integer      | Clave foránea que conecta la venta con el cliente comprador.                                            | 🔒 Ocultar |
| `FactSales`   | `FK_StoreKey`    | Integer      | Clave foránea que conecta la venta con la tienda donde se realizó.                                      | 🔒 Ocultar |
| `FactSales`   | `FK_DateKey`     | Integer      | Clave foránea que conecta la venta con la fecha de transacción.                                         | 🔒 Ocultar |
| `FactSales`   | `OrderID`        | Text         | Número de orden de venta asignado por el sistema POS. Identificador de negocio consultado por usuarios. | ✅ Visible |
| `FactSales`   | `Quantity`       | Integer      | Cantidad de unidades vendidas en la línea de venta.                                                     | ✅ Visible |
| `FactSales`   | `UnitPrice`      | Decimal      | Precio unitario de venta aplicado al producto. Moneda: USD.                                             | ✅ Visible |
| `FactSales`   | `UnitCost`       | Decimal      | Costo unitario del producto según el proveedor. Moneda: USD.                                            | ✅ Visible |
| `FactSales`   | `DiscountAmount` | Decimal      | Monto de descuento aplicado a la línea de venta. Moneda: USD.                                           | ✅ Visible |
| `DimProduct`  | `SK_ProductKey`  | Integer      | Clave subrogada del producto. Uso interno del modelo.                                                   | 🔒 Ocultar |
| `DimProduct`  | `ProductName`    | Text         | Nombre comercial del producto tal como aparece en el catálogo.                                          | ✅ Visible |
| `DimProduct`  | `Category`       | Text         | Categoría principal del producto (ej: Electrónica, Ropa, Hogar).                                        | ✅ Visible |
| `DimProduct`  | `Subcategory`    | Text         | Subcategoría del producto dentro de su categoría principal.                                             | ✅ Visible |
| `DimProduct`  | `Brand`          | Text         | Marca del fabricante del producto.                                                                      | ✅ Visible |
| `DimProduct`  | `Color`          | Text         | Color del producto disponible para el consumidor.                                                       | ✅ Visible |
| `DimProduct`  | `ListPrice`      | Decimal      | Precio de lista sugerido por el fabricante. Moneda: USD.                                                | ✅ Visible |
| `DimCustomer` | `SK_CustomerKey` | Integer      | Clave subrogada del cliente. Uso interno del modelo.                                                    | 🔒 Ocultar |
| `DimCustomer` | `CustomerName`   | Text         | Nombre completo del cliente registrado.                                                                 | ✅ Visible |
| `DimCustomer` | `Segment`        | Text         | Segmento de mercado del cliente (Consumer, Corporate, Small Business).                                  | ✅ Visible |
| `DimCustomer` | `Col_14`         | Text         | ⚠️ _Requiere revisión manual — patrón no reconocido. Posible campo legacy._                             | 🔍 Revisar |

### Relaciones Existentes

| Desde                      | Hacia                        | Cardinalidad | Estado      |
| -------------------------- | ---------------------------- | ------------ | ----------- |
| `FactSales.FK_ProductKey`  | `DimProduct.SK_ProductKey`   | Muchos a Uno | ✅ Correcta |
| `FactSales.FK_CustomerKey` | `DimCustomer.SK_CustomerKey` | Muchos a Uno | ✅ Correcta |
| `FactSales.FK_StoreKey`    | `DimStore.SK_StoreKey`       | Muchos a Uno | ✅ Correcta |
| `FactSales.FK_DateKey`     | `DimDate.DateKey`            | Muchos a Uno | ✅ Correcta |

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

- **Justificación**: Ingreso total bruto antes de descuentos. Métrica principal de cualquier dashboard de ventas retail.
- **Business Question**: "¿Cuál fue el ingreso total del período?"
- **Categoría**: Revenue
- **Formato sugerido**: `"$#,##0.00"`

#### Total Cost

```dax
[Total Cost] =
    SUMX(
        FactSales,
        FactSales[Quantity] * FactSales[UnitCost]
    )
```

- **Justificación**: Costo total de los productos vendidos (COGS). Base para cálculo de margen bruto.
- **Business Question**: "¿Cuánto costaron los productos vendidos?"
- **Categoría**: Cost
- **Formato sugerido**: `"$#,##0.00"`

#### Gross Margin %

```dax
[Gross Margin %] =
    DIVIDE(
        [Total Revenue] - [Total Cost],
        [Total Revenue],
        0
    )
```

- **Justificación**: Porcentaje de margen bruto. KPI crítico para evaluar la rentabilidad antes de gastos operativos.
- **Business Question**: "¿Qué tan rentables son nuestras ventas?"
- **Categoría**: Efficiency
- **Formato sugerido**: `"0.0%"`

#### Total Discount

```dax
[Total Discount] =
    SUM( FactSales[DiscountAmount] )
```

- **Justificación**: Monto total de descuentos otorgados. Permite evaluar el impacto de las promociones en el margen.
- **Business Question**: "¿Cuánto estamos dando en descuentos?"
- **Categoría**: Cost
- **Formato sugerido**: `"$#,##0.00"`

#### Order Count

```dax
[Order Count] =
    DISTINCTCOUNT( FactSales[OrderID] )
```

- **Justificación**: Número total de órdenes únicas. Indicador de volumen de transacciones.
- **Business Question**: "¿Cuántas órdenes se procesaron en el período?"
- **Categoría**: Volume
- **Formato sugerido**: `"#,##0"`

#### Avg Order Value

```dax
[Avg Order Value] =
    DIVIDE(
        [Total Revenue],
        [Order Count],
        0
    )
```

- **Justificación**: Valor promedio por orden. Indicador clave para medir la calidad del ticket de venta.
- **Business Question**: "¿Cuánto gasta en promedio cada cliente por orden?"
- **Categoría**: Revenue
- **Formato sugerido**: `"$#,##0.00"`

#### Units Sold

```dax
[Units Sold] =
    SUM( FactSales[Quantity] )
```

- **Justificación**: Total de unidades vendidas. Complementa el análisis de revenue con volumen.
- **Business Question**: "¿Cuántas unidades vendimos?"
- **Categoría**: Volume
- **Formato sugerido**: `"#,##0"`

#### Revenue YTD

```dax
[Revenue YTD] =
    TOTALYTD(
        [Total Revenue],
        DimDate[Date]
    )
```

- **Justificación**: Ingreso acumulado año fiscal a la fecha. Estándar para reportes ejecutivos con visión temporal.
- **Business Question**: "¿Cómo vamos en ingresos acumulados este año?"
- **Categoría**: Revenue
- **Formato sugerido**: `"$#,##0.00"`

---

## 4. Resumen de Auditoría

| Categoría                 | Total | Aprobadas | Pendientes |
| ------------------------- | ----- | --------- | ---------- |
| Descripciones de tablas   | 6     | —         | —          |
| Descripciones de columnas | 21    | —         | —          |
| Columnas a ocultar        | 8     | —         | —          |
| Columnas en revisión      | 1     | —         | —          |
| KPIs propuestos           | 8     | —         | —          |

> **Estado**: ⏳ Pendiente de auditoría del experto
