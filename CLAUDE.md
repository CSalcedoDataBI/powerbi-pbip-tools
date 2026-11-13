# powerbi-pbip-tools — instructions for agents

Automation for Power BI projects in PBIP format (svg-recolor, semantic-architect, `/dashboard`). What it
is, its users, what is not its job and its protected zones: [`FICHA.md`](FICHA.md), the repo's north.

## Working here

- **Tests** (PowerShell 7): PSScriptAnalyzer 1.25.0 over `skills`, `tests` and `tools` with
  `PSScriptAnalyzerSettings.psd1`, then `./tests/smoke-test.ps1`, `./tests/color-tokens-test.ps1`,
  `./tests/inline-chartjs-test.ps1` and `./tests/embedded-svg-test.ps1`. CI runs the same in the required
  check `validate` (`.github/workflows/validate.yml`).
- **Tests read the files on disk**, never a script's printed counts; they run against temp copies of
  `examples/Demo` and `examples/DynamicIcons`, which are never modified in place.
- **All code enters by PR** to `main`, grouped by issue; the experto (`.claude/agents/experto.md`)
  reviews it once and merges it. Nobody merges with `--admin`.
- **Versions:** release-please keeps the release PR (tag `vX.Y.Z`, `CHANGELOG.md`); never bump or tag by
  hand. Commits and PR titles are conventional commits in English.
- **Bilingual docs:** a `SKILL.md` and its `SKILL.en.md` change together.
- **Public repo:** no links to private repos, no local disk paths, no client data in versioned files.
