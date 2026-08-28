# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Added

#### `skill-svg-recolor-powerbi`
- `-Backup` flag: saves original SVGs to a timestamped `_backup_` subfolder before modifying
- `-WhatIf` flag: previews which files would change without touching any file
- Hex color format validation for `-To` and `-From` parameters (rejects non-`#RRGGBB` values)
- Multi-report support: both `detect-colors.ps1` and `recolor.ps1` now process **all** `.Report` folders found in the project root (previously only the first one)
- English-only output messages (previously mixed Spanish/English)

#### `skill-semantic-architect-powerbi`
- Complete **Contoso Sales** example in `projects/Contoso_Sales/context-store.md` — 5 tables, 29 columns, 8 KPI measures
- Added **4 new industries** to `resources/industry-research-prompts.en.md` and `.md`:
  - Energy / Utilities
  - Insurance
  - Telecommunications
  - Government / Public Sector

#### `dashboard` (Claude Code plugin)
- Dark mode support in `tools/dashboard/template.html` via `@media (prefers-color-scheme: dark)`
- `AVG_UNITS_PER_TX` constant moved from hardcoded `36.8` to `CONFIG.avgUnitsPerTx` — now documented in the template and in `skills/dashboard-builder.md` Configuration block
- All static labels in the template converted to English (previously mixed Spanish/English)

#### Repository
- `.github/ISSUE_TEMPLATE/bug_report.md` — structured bug report template
- `.github/ISSUE_TEMPLATE/feature_request.md` — structured feature request template

---

## [1.0.0] — 2025-01-01

### Added

- `skill-svg-recolor-powerbi`: batch SVG color detection and replacement for PBIP projects
- `skill-semantic-architect-powerbi`: AI-driven semantic model documentation via MCP (4-phase workflow)
- `dashboard` Claude Code plugin: interactive standalone HTML dashboard generator from Power BI via MCP
- `examples/Demo`: sample PBIP project for testing `skill-svg-recolor-powerbi`
- `examples/DAX-User-Defined-Functions`: sample PBIP project showcasing DAX UDF patterns
