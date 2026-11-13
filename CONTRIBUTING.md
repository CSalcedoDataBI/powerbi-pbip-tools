# Contributing

Thanks for helping. Before you start:

1. **Open an issue first** (bug or feature template) so the change has a plan to compare against.
2. **Read [`FICHA.md`](FICHA.md):** it says what this tool is, what it is not, and which pieces are
   protected (the svg-recolor contract, the test fixtures, the Chart.js licence, published paths).
3. **Open a pull request to `main`.** Its title is a conventional commit in English
   (`fix: …`, `feat: …`, `docs: …`): the changelog and the version are generated from it.
4. **Keep the check `validate` green.** It runs PSScriptAnalyzer and the four scripts in `tests/`; run
   them locally with PowerShell 7 before pushing. A bug fix comes with a test that fails without it.
5. **Docs in two languages:** if you change a `SKILL.md`, change its `SKILL.en.md` too.

Do not commit client projects or real data: `examples/` holds only sample PBIP projects.
