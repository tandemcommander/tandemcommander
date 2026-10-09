# Open Salamander Architecture Documentation

This directory contains a comprehensive analysis of the Open Salamander
project — its build system, project structure, dependencies, compiler
options, and code standards.

## Documents

| # | Document | Description |
|---|----------|-------------|
| 01 | [Project Overview](01-project-overview.md) | History, purpose, technology stack, repository layout |
| 02 | [Solution Structure](02-solution-structure.md) | All 90 projects in salamand.sln with categories and dependencies |
| 03 | [Build Pipeline](03-build-pipeline.md) | Prerequisites, build scripts, configurations, output structure |
| 04 | [Dependencies](04-dependencies.md) | Third-party libraries, licenses, missing dependencies |
| 05 | [Compiler Comparison](05-compiler-comparison.md) | MSVC, Clang-cl, MinGW-w64, Intel ICX evaluation |
| 06 | [Plugin Architecture](06-plugin-architecture.md) | Plugin API, .spl/.slg format, build configuration |
| 07 | [Preprocessor Definitions](07-preprocessor-defs.md) | All #defines grouped by configuration scope |
| 08 | [Code Standards](08-code-standards.md) | Encoding, formatting, C++ standard, conventions |
| 09 | [Plugin Catalog](09-plugin-catalog.md) | All plugins categorized by purpose |
| 10 | [Plugin Maintenance Outlook](10-plugin-maintenance-outlook.md) | Per-plugin 2026+ maintenance assessment (Czech) |
| 11 | [WebView2 Integration](11-webview2-integration.md) | **Binding contract** for any plugin embedding WebView2 |
| 12 | [Project Reference](12-project-reference.md) | Long form of the facts `CLAUDE.md` keeps short: identity, copyright rule, build policies, key facts, technologies |

## Quick Navigation

| Question | Document |
|----------|----------|
| How do I build the project? | [03 — Build Pipeline](03-build-pipeline.md) |
| What projects are in the solution? | [02 — Solution Structure](02-solution-structure.md) |
| What plugins exist? | [02 — Solution Structure](02-solution-structure.md) + [06 — Plugin Architecture](06-plugin-architecture.md) |
| What third-party libraries are used? | [04 — Dependencies](04-dependencies.md) |
| What dependencies are missing? | [04 — Dependencies](04-dependencies.md#missing--external-dependencies) |
| Can I use a different compiler? | [05 — Compiler Comparison](05-compiler-comparison.md) |
| What are the coding conventions? | [08 — Code Standards](08-code-standards.md) |
| What do the preprocessor defines mean? | [07 — Preprocessor Definitions](07-preprocessor-defs.md) |
| How does the plugin system work? | [06 — Plugin Architecture](06-plugin-architecture.md) |

## See Also

- [CLAUDE.md](../CLAUDE.md) — AI assistant context file (concise project summary with links to all documents)
- [specs/FEATURE-HISTORY.md](../specs/FEATURE-HISTORY.md) — per-feature notes (what each feature changed, traps, evidence), with an index by area
- [README.md](../README.md) — Original project README with prerequisites and building instructions
