# Implementation Plan: Backlog app triage - choose the position when moving an item out of the Inbox

**Branch**: `414-triage-position` | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/414-triage-position/spec.md`

## Summary

The triage page of the backlog app (`tools/backlog-app/`, feature 344) gets a *Place at* chooser
for the current Inbox item: a section choice among the three ordered sections (preselected with the
suggestion's section) and a position field filled with that section's default by the severity rule.
Confirming sends the existing move request **with** the position - one `backlog.sh move ... --position`
- exactly like the existing Accept button does for the suggested place. The severity rule is
factored out of `suggestPlacement` into a pure, unit-tested `positionBySeverity`; the reading of a
typed position (whole number >= 1, past the end = last) is a pure, unit-tested
`readTriagePosition`. No server, schema or tool change.

## Technical Context

**Language/Version**: TypeScript 5 on Node 24 (type stripping), React 19
**Primary Dependencies**: the app's own packages (`@backlog-app/shared`, web UI primitives), TanStack Query / Router, react-hotkeys-like `useShortcuts` of the app
**Storage**: none new - the backlog files through `bin/backlog.sh` (unchanged)
**Testing**: Vitest (`shared` unit tests), Playwright on Edge (`e2e/us3-order.spec.ts`), `npm run check` (typecheck, ESLint with doc comments, Prettier, unit tests)
**Target Platform**: localhost web app on Windows 11 (the maintainer's browser)
**Project Type**: web application (server + web + shared packages)
**Performance Goals**: no measurable change; the default position is computed from the board already loaded
**Constraints**: changes only through the existing move endpoint (one tool call per placement); the write gate and the board revision guard stay in force
**Scale/Scope**: one page component, one shared rule module, their tests

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Effect of this feature | Result |
|---|---|---|
| I. Build reproducibility | No product build change; the app's dependencies are unchanged (no new package) | PASS |
| II. Backward compatibility | The existing triage actions keep their behaviour (FR-007); no file format, API or tool change | PASS |
| III. Incremental modernization | A small addition to a maintainer tool | PASS |
| IV. Windows commitment | Unaffected | PASS |
| V. Plugin architecture | Unaffected (no product code) | PASS |
| VI. UI consistency | The chooser reuses the app's own `NativeSelect`, `Input`, `Button`, `Kbd` and the hint wording of the existing position field (feature 371) | PASS |

No maintainer-owned area (stop-rules §1) is touched: no network, stored data, plug-in interface,
installer, shipping, release, public claim or translation. No product UI strings - no `.slt`
refresh.

Re-check after Phase 1: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/414-triage-position/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/triage-place-chooser.md
├── fix-log.md
└── tasks.md
```

### Source Code (repository root)

```text
tools/backlog-app/
├── packages/shared/src/query/triage.ts          # + positionBySeverity, readTriagePosition, TRIAGE_TARGETS
├── packages/shared/test/triage.test.ts          # + their unit checks
├── packages/web/src/features/triage/
│   ├── triage-page.tsx                          # uses the chooser; key m focuses it
│   └── place-chooser.tsx                        # new: section choice + position field + Place
└── e2e/us3-order.spec.ts                        # + typed position into a non-suggested section
```

**Structure Decision**: the app's existing three-package layout; the pure rules go to `shared`
(where the suggestion already lives and is unit-tested), the control to the triage feature folder.

## Complexity Tracking

No violations.
