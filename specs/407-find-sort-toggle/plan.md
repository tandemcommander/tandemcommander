# Implementation Plan: Find - a second sort by the same result column reverses the order

**Branch**: `407-find-sort-toggle` | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/407-find-sort-toggle/spec.md`

## Summary

The Find window's result list (`CFoundFilesListView`, `src/finddlg1.cpp`) remembers its sort
(column + direction). Every user request (header click, View menu, Ctrl+F3..F6) goes through one
rule: the same column reverses, another column starts ascending. The comparison keeps folders
before files and reverses the column order (with its tie-break columns) inside each group in the
descending direction; the duplicates comparison is reversed as a whole. The header item of the
sorted column gets `HDF_SORTUP` / `HDF_SORTDOWN`. A new search forgets the sort. The pure rules
live in `src/common/salfindsort.h` with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI, comctl32 v6 (manifest `src/manifest.xml` - needed for the header sort arrows)
**Storage**: N/A (the sort state lives in the window object only; nothing persisted)
**Testing**: `saltests` (pure rules), hidden-desktop probe `probe/find_sort_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core module `salamand`)
**Performance Goals**: no slower than before (one QuickSort instead of two in the normal mode)
**Constraints**: no new UI strings, no registry change, no plug-in interface change
**Scale/Scope**: one window class, one new header, about 150 lines

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status |
|---|---|
| I Build reproducibility | PASS - one new header under `src/common/`, no new dependency |
| II Backward compatibility (0.1.0) | PASS - nothing stored; the first sort of a column is the old order; Hide duplicate names keeps its result |
| III Incremental modernization | PASS - upstream structure kept, the decision moved to a tested header |
| IV Windows commitment | PASS - the standard list-header arrows |
| V Plug-in architecture | PASS - no plug-in interface touched |
| VI UI consistency | PASS - the panel's sort model (toggle on the same column, folders first) |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/407-find-sort-toggle/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/find_sort_probe.ps1, result_*.txt
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salfindsort.h      # new: SalFindSortColumnAllowed, SalFindSortNext, SalFindSortNextKey,
                              #      SalFindSortOrder, SalFindSortDirected, SalFindSortHeaderFormat
src/find.h                    # CFoundFilesListView: SortState, SortItems(sortBy, toggle), ResetSort,
                              #      UpdateSortArrows; CompareFunc / CompareDuplicatesFunc get the direction
src/finddlg1.cpp              # SortItems, CompareFunc, QuickSort*, the arrows; StartSearch resets the sort
src/finddlg2.cpp              # OnHideDuplicateNames: SortItems(1, FALSE)
src/saltests/saltests.cpp     # TestFindSort407
```

**Structure Decision**: core only; the rules header is header-only (`src/common/`), included by
`finddlg1.cpp` and `saltests.cpp`.

## Complexity Tracking

None.
