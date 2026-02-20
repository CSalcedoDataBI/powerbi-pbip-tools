---
name: Power BI Semantic Architect
description: Transforma modelos de datos técnicos de Power BI en modelos semánticos documentados — genera descripciones, KPIs y un Context Store completo usando MCP como puente de comunicación bidireccional. El analista pasa de constructor manual a Auditor de Inteligencia.
---

# Power BI Semantic Architect

Esta skill automatiza la documentación completa de un modelo de datos de Power BI. Usando el Model Context Protocol (MCP) como puente bidireccional, el agente lee los metadatos del modelo, investiga la industria, genera un Context Store semántico y —tras la validación del experto— escribe descripciones + KPIs directamente en el modelo.

## Cuándo Usar esta Skill

Úsala cuando:

- Se necesite **documentar un modelo Power BI** existente (descripciones de tablas, columnas, medidas)
- El usuario diga "documenta el modelo", "genera descripciones", "crea KPIs", "semantic architect" o similar
- Se requiera un **Context Store** (mapa semántico) de un modelo para futuras consultas
- Se necesite **ocultar automáticamente** claves foráneas/primarias del panel de campos
- Se quiera **crear medidas DAX** estándar basadas en la industria del modelo

## Prerequisitos

| Componente             | Herramienta           | Por qué es necesario                             |
| ---------------------- | --------------------- | ------------------------------------------------ |
| **Conexión al modelo** | MCP Server (Power BI) | Lectura y escritura de metadatos del modelo      |
| **Investigación**      | Web Search            | Búsqueda de KPIs y estándares de industria       |
| **Procesamiento**      | File Reader           | Análisis de PDFs, código M y documentos técnicos |

> [!IMPORTANT]
> El MCP Server de Power BI debe estar habilitado y conectado al modelo activo antes de iniciar. Sin él, las fases 1 y 4 no pueden ejecutarse.

---

## Flujo de Trabajo: 4 Fases

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   FASE 1    │───▶│   FASE 2    │───▶│   FASE 3    │───▶│   FASE 4    │
│  Escaneo    │    │ Deep        │    │ Context     │    │ Auditoría   │
│  ADN Modelo │    │ Research    │    │ Store       │    │ + Ejecución │
│             │    │             │    │             │    │             │
│ 🤖 Auto    │    │ 🤖 Auto    │    │ 🤖 Auto    │    │ 👤 + 🤖    │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### Fase 1 — Escaneo del ADN del Modelo

**Objetivo**: Extraer la estructura completa del modelo y clasificar la industria.

**Acciones**:

1. **Extraer metadatos vía MCP**: Listar todas las tablas, columnas, tipos de datos y relaciones del modelo activo.
2. **Clasificar la industria** analizando los patrones de nombres:
   - `DimPatient`, `FactClaim` → **Salud**
   - `DimProduct`, `FactSalesOrder` → **Retail**
   - `Medical_Records` → **Salud**
   - `Tickets_Sold` → **Entretenimiento**
   - `Invoice_Lines` → **Facturación**
   - Si no es claro, **preguntar al usuario** antes de continuar.
3. **Identificar la arquitectura del modelo**:
   - **Estrella**: Tablas Dim y Fact claramente separadas
   - **Copo de Nieve**: Dimensiones normalizadas en múltiples niveles
   - **Tabla Plana**: Sin estructura dimensional clara
4. **Inventariar las medidas existentes**: Listar cualquier medida DAX ya presente para no duplicar.

**Output**: Lista estructurada de tablas, columnas, relaciones, industria detectada y arquitectura identificada.

---

### Fase 2 — Investigación Profunda (Deep Research)

**Objetivo**: Enriquecer el contexto con conocimiento de la industria.

**Acciones**:

1. **Búsqueda web avanzada** usando estos patrones:
   - `"Standard data dictionary for [INDUSTRIA]"`
   - `"Key Performance Indicators for [INDUSTRIA] analytics"`
   - `"Common DAX measures for [INDUSTRIA] Power BI"`
   - `"Business questions for [INDUSTRIA] reporting"`

   Consultar `resources/industry-research-prompts.md` para patrones adicionales por industria.

2. **Recopilar**:
   - **KPIs estándar de la industria** — los indicadores "de oro" que cualquier analista esperaría
   - **Business Questions frecuentes** — las preguntas que los stakeholders hacen
   - **Lógica técnica validada** — fórmulas DAX y patrones de cálculo probados

3. **Enriquecer con documentos internos** (si el usuario los proporciona):
   - Código M de Power Query → deducir lógica de negocio de columnas calculadas
   - PDFs corporativos → extraer reglas de negocio específicas
   - Diccionarios de datos → mapear nombres técnicos a significados de negocio

> [!NOTE]
> El diferenciador clave es el cruce: **lo que el mundo sabe de la industria + las reglas específicas del negocio del usuario**.

4. **Guardar hallazgos de investigación** en `projects/{model-name}/research-notes.md`. Este archivo preserva las fuentes, KPIs encontrados y Business Questions para referencia futura.

**Output**: Archivo `research-notes.md` con KPIs propuestos, Business Questions, y descripción de negocio para cada objeto del modelo.

---

### Fase 3 — Construcción del Context Store

**Objetivo**: Consolidar toda la inteligencia en un archivo Markdown estructurado.

**Acciones**:

1. **Generar el Context Store** usando la plantilla en `resources/context-store-template.md`.
2. **Completar las tres secciones**:

#### Section 1: Industry Overview

Resumen ejecutivo de la industria, sus desafíos analíticos clave y el contexto de negocio detectado.

#### Section 2: Metadata Proposal

Tabla con propuesta para cada objeto del modelo:

| Objeto Original | Descripción de Negocio Sugerida                                 | Acción     |
| --------------- | --------------------------------------------------------------- | ---------- |
| `FactSales`     | Tabla de hechos que registra cada transacción de venta...       | ✅ Visible |
| `DimDate`       | Dimensión de calendario con jerarquías año → trimestre → mes... | ✅ Visible |
| `SK_CustomerID` | Clave subrogada de la dimensión de clientes. Uso interno        | 🔒 Ocultar |
| `FK_ProductKey` | Clave foránea que conecta ventas con productos                  | 🔒 Ocultar |
| `Col_14`        | ⚠️ _Requiere revisión manual — patrón no reconocido_            | 🔍 Revisar |

**Reglas de clasificación de acciones**:

- Columnas con prefijos `SK_`, `FK_`, `ID_`, `Key` o sufijos `_Key`, `_ID` → **🔒 Ocultar**
- Columnas sin patrón reconocible → **🔍 Revisar** (marcar para revisión manual)
- Todo lo demás → **✅ Visible**

Consultar `resources/naming-conventions.md` para los patrones completos.

#### Section 3: KPI Catalog

Catálogo de medidas DAX sugeridas con justificación de negocio:

```dax
// Ejemplo:
[Total Revenue] =
    SUMX(
        FactSales,
        FactSales[Quantity] * FactSales[UnitPrice]
    )

// Justificación: Ingreso total bruto antes de descuentos.
// Estándar de la industria Retail para reportes ejecutivos.
// Business Question: "¿Cuál fue el ingreso total del período?"
```

3. **Guardar el archivo** en `projects/{model-name}/context-store.md` dentro del directorio de la skill.
   - `{model-name}` = nombre del modelo/base de datos obtenido del MCP (e.g., `Demo_Catalogo_Cristobal`)
   - Sanitizar: espacios → guiones bajos, mantener capitalización original
   - Si el directorio no existe, crearlo automáticamente
   - Si ya existe un `context-store.md` previo, **sobreescribirlo** (la versión nueva siempre reemplaza la anterior)

> [!IMPORTANT]
> El Context Store no es un archivo desechable. Es un **activo reutilizable** que funciona como memoria contextual (RAG) para futuras interacciones con el modelo. Vive dentro de la skill para ser accesible entre conversaciones.

**Output**: Archivo `projects/{model-name}/context-store.md` completo con las tres secciones, listo para revisión.

---

### Fase 4 — Auditoría del Experto y Ejecución Directa

**Objetivo**: Validación humana y escritura directa en el modelo.

> [!CAUTION]
> **REGLA ABSOLUTA**: La IA NUNCA modifica el modelo sin aprobación explícita del usuario. El experto tiene la última palabra. Siempre usar `notify_user` para presentar el Context Store y solicitar confirmación antes de escribir.

**Acciones**:

1. **Presentar el Context Store al usuario** usando `notify_user` con el archivo en `PathsToReview`.
2. **Solicitar confirmación explícita** con un resumen:
   - ☑ X descripciones de columnas listas
   - ☑ X KPIs propuestos
   - ☐ X columnas marcadas para revisión manual
   - Preguntar: "¿Procedo con la escritura en el modelo?"
3. **Solo tras confirmación del usuario ("Ejecuta", "Aplica", "Go")**, ejecutar vía MCP:
   - **Actualizar la propiedad `Description`** de cada tabla y columna aprobada
   - **Ocultar las claves primarias y foráneas** (cambiar visibilidad) de las columnas marcadas como 🔒
   - **Crear las medidas DAX** en sus respectivas tablas con nomenclatura estándar

4. **Guardar registro de auditoría** en `projects/{model-name}/audit-log.md` con:
   - Fecha de ejecución
   - Resumen de cambios aplicados (descripciones, columnas ocultadas, medidas creadas)
   - Errores o advertencias encontradas
   - Decisiones del experto (qué aprobó, qué rechazó, qué ajustó)

5. **Reportar resultados** al usuario:
   - X descripciones escritas
   - X columnas ocultadas
   - X medidas creadas
   - Cualquier error o advertencia

**Output**: Modelo de Power BI actualizado + `projects/{model-name}/audit-log.md` con registro completo.

---

## Reglas de Oro (Constraints)

### 🔒 Privacidad

- **Solo metadatos**: Nunca pedir ni procesar datos de filas (registros). Solo trabajar con la estructura del modelo.
- Los datos sensibles del negocio nunca salen del perímetro.

### 🎯 Precisión

- Si una columna no tiene un patrón reconocible, marcarla como **"🔍 Revisión Manual"** en el Context Store.
- Nunca inventar significados para columnas ambiguas.
- Verificar que las medidas DAX propuestas usen nombres de columnas que realmente existen en el modelo.

### ✨ Estética

- Nomenclatura limpia para medidas: `[Total Sales]`, `[Avg Revenue per Customer]` — nunca `[sum_of_sales_amt]`.
- Descripciones en lenguaje de negocio, no técnico: "Ingreso total por transacción" — no "SUM of amount column".
- Consultar `resources/naming-conventions.md` para la guía completa.

### 🛡️ Seguridad de Ejecución

- Fase 4 (escritura) SIEMPRE requiere aprobación explícita del usuario.
- Antes de crear medidas, verificar que no existan medidas con el mismo nombre.
- Antes de ocultar columnas, confirmar que no están siendo usadas en visualizaciones.

---

## Archivos de Referencia

| Archivo                  | Ruta                                     | Propósito                                               |
| ------------------------ | ---------------------------------------- | ------------------------------------------------------- |
| Plantilla Context Store  | `resources/context-store-template.md`    | Estructura base del archivo de contexto                 |
| Prompts de Investigación | `resources/industry-research-prompts.md` | Patrones de búsqueda web por industria                  |
| Convenciones de Nombres  | `resources/naming-conventions.md`        | Reglas de nomenclatura para medidas y descripciones     |
| Ejemplo Retail           | `examples/retail-example.md`             | Context Store completo de ejemplo para industria Retail |

---

## Archivos de Salida (Output Files)

Todos los archivos generados por la skill se almacenan dentro de `projects/` en el directorio raíz de la skill, organizados por modelo:

```
projects/
└── {model-name}/                  ← Nombre del modelo desde MCP
    ├── context-store.md           ← Fase 3: Mapa semántico completo
    ├── research-notes.md          ← Fase 2: Hallazgos de investigación
    └── audit-log.md               ← Fase 4: Registro de cambios aplicados
```

| Archivo             | Fase | Propósito                                                                                            |
| ------------------- | ---- | ---------------------------------------------------------------------------------------------------- |
| `context-store.md`  | 3    | Activo reutilizable principal. Mapa semántico con Industry Overview, Metadata Proposal y KPI Catalog |
| `research-notes.md` | 2    | Fuentes consultadas, KPIs encontrados, Business Questions recopiladas                                |
| `audit-log.md`      | 4    | Registro de qué se aplicó al modelo, decisiones del experto, errores                                 |

### Convención de nombres para `{model-name}`

- Usar el nombre de la base de datos/modelo obtenido del MCP (e.g., `Demo_Catalogo_Cristobal`)
- Sanitizar: espacios → guiones bajos (`_`), mantener capitalización original
- Si se re-ejecuta la skill sobre el mismo modelo, **actualizar** los archivos existentes (no duplicar)
- Si el directorio del proyecto no existe, crearlo automáticamente

---

## Ejemplo de Uso

**Usuario**: "Documenta este modelo de Power BI y genera los KPIs"

**Agente**:

1. Se conecta vía MCP → extrae 12 tablas, 87 columnas, 15 relaciones
2. Detecta industria: **Retail** (basado en `DimProduct`, `FactSales`, `DimCustomer`)
3. Investiga KPIs estándar de Retail → propone 8 medidas DAX
4. Genera `projects/Contoso_Sales/context-store.md` con Industry Overview + 87 descripciones + 8 KPIs
5. Presenta al usuario para auditoría → usuario aprueba 85 descripciones, ajusta 2 KPIs
6. Ejecuta escritura vía MCP → modelo actualizado en ~2 minutos
