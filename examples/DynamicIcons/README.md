# DynamicIcons — SVGs that do not live in a folder

A deliberately small PBIP project whose icons are in the three places a Power BI
report can keep them. It exists so `-Scope Dax` and `-Scope Visuals` can be tested
against something shaped like a real project rather than a synthetic string.

```
DynamicIcons/
├── DynamicIcons.SemanticModel/definition/tables/Icons.tmdl
│     three measures, on purpose:
│       'Status Icon'  — the dynamic-icon pattern: the colour is in its OWN
│                        literal, IF(..., "%230078D4", "%23D13438"), and the SVG
│                        concatenates it. NOT rewritten — reported instead.
│       'Fixed Badge'  — an SVG data URI with the colours inside it, plus a
│                        url(%23grad) fragment reference that must survive.
│       'Palette Note' — prose that mentions #0078D4. Never rewritten.
│
├── DynamicIcons.Report/definition/pages/pg1/visuals/v1/visual.json
│     a base64 data URI, and a title reading "Ventas #1 del trimestre" — the #1
│     must not be mistaken for a colour
├── …/visuals/v2/visual.json
│     a second one, same file name: it is what proves the backup does not
│     overwrite one visual.json with another
│
└── DynamicIcons.Report/StaticResources/RegisteredResources/badge.svg
      an ordinary loose icon, so -Scope All has something in all three places
```

Every icon starts at `#0078D4`, the same starting colour the rest of the
documentation uses.

## Try it

Look first — nothing is written:

```powershell
.\skills\skill-svg-recolor-powerbi\scripts\detect-colors.ps1 -PbipDir ".\examples\DynamicIcons" -Scope All
```

Then preview, then do it on a copy of your own project:

```powershell
.\skills\skill-svg-recolor-powerbi\scripts\recolor.ps1 -PbipDir ".\examples\DynamicIcons" -To "#DC143C" -Scope All -WhatIf
```

`-Scope Dax` writes to the semantic model, so it refuses to run without `-Backup`
or `-WhatIf`. A bad substitution in an `.svg` spoils a picture; the same mistake
in a `.tmdl` stops the report from opening.

## What this example is for

`tests/embedded-svg-test.ps1` runs against a throwaway copy of this folder. The
assertions that matter are the negative ones — that the DAX logic, the fragment
reference, the prose and the visual's title all come out byte for byte identical.
