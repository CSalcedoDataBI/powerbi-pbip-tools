# Context Store Template

> Generado por: Power BI Semantic Architect Skill
> Modelo: {{MODEL_NAME}}
> Industria detectada: {{INDUSTRY}}
> Arquitectura: {{ARCHITECTURE}} (Estrella / Copo de Nieve / Tabla Plana)
> Fecha: {{DATE}}

---

## 1. Industry Overview

### Industria: {{INDUSTRY}}

{{INDUSTRY_DESCRIPTION}}

### Desafíos Analíticos Clave

- {{CHALLENGE_1}}
- {{CHALLENGE_2}}
- {{CHALLENGE_3}}

### Contexto de Negocio Detectado

{{BUSINESS_CONTEXT}}

---

## 2. Metadata Proposal

### Tablas

| Tabla          | Tipo                       | Descripción de Negocio | Acción                      |
| -------------- | -------------------------- | ---------------------- | --------------------------- |
| {{TABLE_NAME}} | {{Hecho/Dimensión/Lookup}} | {{DESCRIPTION}}        | {{✅ Visible / 🔒 Ocultar}} |

### Columnas

| Tabla     | Columna    | Tipo de Dato | Descripción de Negocio | Acción           |
| --------- | ---------- | ------------ | ---------------------- | ---------------- |
| {{TABLE}} | {{COLUMN}} | {{TYPE}}     | {{DESCRIPTION}}        | {{✅ / 🔒 / 🔍}} |

**Leyenda de acciones**:

- ✅ **Visible** — Debe ser accesible para el usuario final
- 🔒 **Ocultar** — Clave técnica, ocultar del panel de campos
- 🔍 **Revisar** — Patrón no reconocido, requiere validación manual del experto

### Relaciones Existentes

| Desde (Tabla.Columna) | Hacia (Tabla.Columna) | Cardinalidad    | Estado                 |
| --------------------- | --------------------- | --------------- | ---------------------- |
| {{FROM}}              | {{TO}}                | {{CARDINALITY}} | {{Correcta / Revisar}} |

---

## 3. KPI Catalog

### Medidas Propuestas

#### {{MEASURE_NAME}}

```dax
[{{MEASURE_NAME}}] =
    {{DAX_EXPRESSION}}
```

- **Justificación**: {{BUSINESS_JUSTIFICATION}}
- **Business Question**: "{{BUSINESS_QUESTION}}"
- **Categoría**: {{CATEGORY}} (Revenue / Cost / Efficiency / Growth / ...)
- **Formato sugerido**: {{FORMAT_STRING}}

---

## 4. Resumen de Auditoría

| Categoría                 | Total | Aprobadas | Pendientes |
| ------------------------- | ----- | --------- | ---------- |
| Descripciones de tablas   | {{N}} | —         | —          |
| Descripciones de columnas | {{N}} | —         | —          |
| Columnas a ocultar        | {{N}} | —         | —          |
| Columnas en revisión      | {{N}} | —         | —          |
| KPIs propuestos           | {{N}} | —         | —          |

> **Estado**: ⏳ Pendiente de auditoría del experto
