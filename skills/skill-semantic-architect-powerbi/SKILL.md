---
name: Power BI Semantic Architect
description: Transforma modelos de datos técnicos de Power BI en modelos semánticos documentados — genera descripciones, KPIs y un Context Store completo usando MCP como puente de comunicación bidireccional. El analista pasa de constructor manual a Auditor de Inteligencia.
---

# Power BI Semantic Architect

> 🇱🇷 [English version → SKILL.en.md](SKILL.en.md)

Esta skill automatiza la documentación completa de un modelo de datos de Power BI. Usando el Model Context Protocol (MCP) como puente bidireccional, el agente lee los metadatos del modelo, investiga la industria, genera un Context Store semántico y —tras la validación del experto— escribe descripciones + KPIs directamente en el modelo.

## Clonar Solo Esta Skill

```bash
git clone --filter=blob:none --sparse https://github.com/CSalcedoDataBI/powerbi-pbip-tools.git
cd powerbi-pbip-tools
git sparse-checkout set skills/skill-semantic-architect-powerbi
```

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

Consultar el [SKILL.md completo original](../../DevWorkspace/skills/semantic-architect-powerbi/SKILL.md) para la descripción detallada de cada fase, o la [versión en inglés](SKILL.en.md) para la documentación completa.

---

## Reglas de Oro

- 🔒 **Privacidad** — Solo metadatos, nunca datos de filas
- 🎯 **Precisión** — Columnas ambiguas → "🔍 Revisión Manual"
- ✨ **Estética** — `[Total Sales]` nunca `[sum_of_sales_amt]`
- 🛡️ **Seguridad** — Fase 4 SIEMPRE requiere aprobación del usuario

## Archivos de Referencia

| Archivo                  | Ruta                                     |
| ------------------------ | ---------------------------------------- |
| Plantilla Context Store  | `resources/context-store-template.md`    |
| Prompts de Investigación | `resources/industry-research-prompts.md` |
| Convenciones de Nombres  | `resources/naming-conventions.md`        |
| Ejemplo Retail           | `examples/retail-example.md`             |
