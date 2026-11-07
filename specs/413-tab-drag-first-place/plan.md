# Implementation Plan: Panel tabs - a drag reaches the first place; the dark strip looks as high as the default one

**Branch**: `413-tab-drag-first-place` | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/413-tab-drag-first-place/spec.md`

## Summary

Two defects of the variant F tab strip (404). (1) The drag slot rule `SalTabDragSlot` needs a
dragged left below 0 for slot 0 while moving left, but `CTabWindow::UpdateDrag` clamps the left to
the run, so the first place is unreachable: moving left, tab j now gives way once the left is **at
or below** j widths (a ceiling division), symmetric to moving right (at or above). Only lefts that
are whole multiples of the width change their slot. (2) The dark strip is not lower in pixels
(measured equal); the inactive panel's active tab has the colour of the face and almost of the
strip, so it has no shape. A new pure rule `SalTabActiveFill` keeps the caption colour unless it is
within 24 (largest channel) of the strip background or the face colour, and then lifts it toward
the caption text colour by the smallest hundredth that gives 24 from both (at most halfway; never
under High Contrast). `CTabWindow::Paint` uses it for the active tab's shape and its close glyph.

## Technical Context

**Language/Version**: C++20, MSVC v143, pure WinAPI
**Primary Dependencies**: none new (nanosvg / GDI paint of 404 unchanged)
**Storage**: N/A (no configuration change)
**Testing**: `saltests` (`TestTabStrip413` next to `TestTabStrip404`), probe `tabs413_probe` on the
hidden desktop, `tabs404_probe` and `tabs405_probe` as regression
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core)
**Performance Goals**: the fill rule runs once per paint, at most 50 mixes - negligible
**Constraints**: the default theme and the dark active panel stay pixel-identical (FR-006)
**Scale/Scope**: `src/common/saltabs.cpp/.h`, `src/tabwnd.cpp` (one line of `Paint`),
`src/saltests/saltests.cpp`, the 404 probe's dark inactive expectation, the manual's drag paragraph

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency, no build change - PASS |
| II. Backward compatibility | no stored data, no plug-in API; drag behaviour changes only at the exact multiples of the width while moving left - PASS |
| III. Incremental modernization | pure rules in `src/common/saltabs.*` with saltests - PASS |
| IV. Windows commitment | GDI paint unchanged - PASS |
| V. Plug-in architecture | not touched - PASS |
| VI. UI consistency | the dark inactive panel's tab gets the same visibility as the default theme's; no new strings, no dialog - PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/413-tab-drag-first-place/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/saltabs-413.md
├── fix-log.md
└── probe/tabs413_probe.ps1, result_before.txt, result_after.txt, captures_*
```

### Source Code (repository root)

```text
src/common/saltabs.h / saltabs.cpp   SalTabDragSlot (changed), SalTabActiveFill (new)
src/tabwnd.cpp                       CTabWindow::Paint - the active tab's fill
src/saltests/saltests.cpp            TestTabStrip413
specs/404-panel-tabs-rounded-look/probe/tabs404_probe.ps1 + evidence baseline for dark inactive
help/src/hh/salamand/windows_tabstrip.htm   the drag paragraph names the ends
```

**Structure Decision**: core only; decisions as pure functions in `src/common/` (CLAUDE.md working
method).

## Complexity Tracking

None.
