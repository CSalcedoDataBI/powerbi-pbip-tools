# Ficha — powerbi-pbip-tools

> Ficha of this tool. Its experto (`.claude/agents/experto.md`) reads it on every PR.
> Maintained with the maintainer's internal rules.
> Changing the ficha requires a new approval.

## Qué es

- **What it builds and for whom:** a public, MIT-licensed set of automation pieces for Power BI projects in
  **PBIP** format, each one cloneable on its own with `git sparse-checkout`:
  - `skills/skill-svg-recolor-powerbi/` — two PowerShell scripts (`detect-colors.ps1`, `recolor.ps1`) and
    their modules that report and change the colours of the SVG icons of a PBIP: loose `.svg` files and,
    with `-Scope Dax|Visuals|All`, SVGs inside DAX measures (`*.tmdl`) and base64 SVGs in `visual.json`.
  - `skills/skill-semantic-architect-powerbi/` — an instructions-only skill (ES + EN) that documents a
    semantic model through MCP in four phases (scan, research, Context Store, expert audit).
  - `commands/dashboard.md` + `skills/dashboard-builder.md` + `tools/dashboard/` — the `/dashboard`
    Claude Code command that fills `template.html` with a model's values, and `Inline-ChartJs.ps1`, which
    makes the result work offline with the Chart.js MIT notice.
  - `examples/` — reference PBIP projects (`Demo`, `DynamicIcons`, `DAX-User-Defined-Functions`).
- **Users:** Power BI developers who keep their reports as PBIP in git and want batch changes without
  opening Power BI Desktop; readers of the blog posts that link the examples; the agents (Claude Code,
  Antigravity) that run these skills on a user's project.
- **Role** (`repo-roles`): tool.
- **Public/private twin:** none.

## Norte

- **Current plan:** no board epic yet. Open work: #32 (CHANGELOG states a backup location that is not
  real), #33 (`template.html` renders a blank page), #35 (svg-recolor `SKILL.md` as the single copy),
  #34 (these common rules).
- **North:** each piece changes exactly what it promises in a PBIP and nothing else, says what it could
  not do instead of skipping it silently, and is proven by a test that reads the files on disk, not the
  script's own output.
- **What this tool is NOT:**
  - not a Power BI Desktop plugin or an external tool: it works on the PBIP files on disk;
  - not a theme or report designer: svg-recolor changes colours that are already there, it does not choose
    a palette;
  - not a store of client projects: `examples/` holds only public, synthetic or sample data;
  - not a Claude Code marketplace plugin (no `plugin.json`): the pieces are copied or cloned by hand;
  - not a DAX or TMDL library: the DAX UDF example illustrates the feature, it is not maintained as a
    function catalogue.

## Zonas protegidas

What is not touched without a plan step that names it:

- **The svg-recolor contract** (`skills/skill-svg-recolor-powerbi/SKILL.md` and `SKILL.en.md`):
  parameters `-PbipDir`, `-From`, `-To`, `-Scope`, `-WhatIf`, `-Backup`, `-PassThru` and the output
  objects; only genuine colour tokens are rewritten (never `url(#id)` or CSS id selectors); each file keeps
  its encoding and gets no BOM; backups go outside the project; notations it cannot rewrite (`rgb()`,
  `hsl()`, `var()`, `currentColor`, named colours) are reported. Broken before and fixed in #27 and #31.
- **The test fixtures** `examples/Demo` and `examples/DynamicIcons`: the suite runs against copies of
  them. Changing their files changes what the tests prove.
- **Chart.js and its licence:** `tools/dashboard/vendor/chart.umd.min.js` travels with
  `chart.js.LICENSE.txt`, and every dashboard `Inline-ChartJs.ps1` produces carries the MIT notice (#30).
- **Published paths:** `skills/skill-*-powerbi/` folder names, `examples/DAX-User-Defined-Functions/`
  and the README sparse-checkout commands. Blog posts and users' clones point at them; the old renames
  (`skill-svg-recolor-pbip`) broke links.
- **Bilingual pairs:** every `*.md` with an `*.en.md` twin changes in both in the same PR.
- **The lint bar:** PSScriptAnalyzer pinned in `validate.yml` and failing on Warning; a new rule is
  excluded only in `PSScriptAnalyzerSettings.psd1` with its reason.
- **Public repo:** no versioned file links private repos, local disk paths or workspace data.

## Capa y feedback

- **Node layer** (ADR 0023): none.
- **Feedback skill:** none. Problems with this tool are GitHub issues on this repo
  (`.github/ISSUE_TEMPLATE/`).

## Check y experto

- **Required CI check:** `validate` (job `validate` of `.github/workflows/validate.yml`, ruleset
  `main protegida` on `main`, 0 approvals).
- **Test suite:** PSScriptAnalyzer 1.25.0 over `skills`, `tests` and `tools` with
  `PSScriptAnalyzerSettings.psd1`, then `./tests/smoke-test.ps1`, `./tests/color-tokens-test.ps1`,
  `./tests/inline-chartjs-test.ps1` and `./tests/embedded-svg-test.ps1` (each exits non-zero on failure).
- **Runner:** GitHub (public repo).
- **Formato de tag:** `vX.Y.Z`. No tag yet: the `[1.0.0]` of `CHANGELOG.md` covers everything up to commit
  `d9a267b`, the last one before the `[Unreleased]` work, and release-please counts from there (`bootstrap-sha`, manifest `1.0.0`); its first release PR brings the first
  tag, and from then on release-please decides the number.
- **Experto:** `.claude/agents/experto.md`
- **Directory plugin?:** no.
- **Visible parts Cristóbal approves:** the README and the examples as a reader sees them on GitHub, and
  the live dashboard demo linked from the README.

Definition of done for a PR: it answers an issue and does no more; `validate` is green on the head commit;
a behaviour change carries a test that fails without it and reads the files on disk; the PR title is a
conventional commit in English (release-please writes `CHANGELOG.md` from it); a change to a script's
parameters or output updates its `SKILL.md` and `SKILL.en.md`; nothing in a protected zone moved unless
the PR names it.

## Aprobación

Aprobada: 2026-11-12 (parent, por delegación, re-approved with the tag line after the experto's review; Cristóbal en el chat del 2026-11-12: «crea todos los expertos faltantes, revisar que se hagan bien»)
