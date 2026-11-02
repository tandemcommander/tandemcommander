# Implementation Plan: Filter dialog keeps a long panel filter whole after a refused edit

**Branch**: `392-filter-dialog-backup` | **Date**: 2026-11-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/392-filter-dialog-backup/spec.md`

## Summary

`CFilterDialog::Validate` (`src/dialogs3.cpp`) checks the typed filter by writing it into the
panel's own `CMaskGroup` and "restores" the group from a `char[MAX_PATH]` backup - a filter longer
than 259 bytes (a tab's filter, up to 1000 bytes) is cut, unprepared, and its extended mode reset.
The fix checks the typed text in a local `CMaskGroup` that carries the panel filter's mode; the
panel's group is never written by `Validate`. `Transfer` (runs only after a good `Validate`) stores
the accepted text as before.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new (core `CMaskGroup`, winliblt `CTransferInfo`)
**Storage**: none changed (the panel filter in memory; the registry is written as before)
**Testing**: hidden-desktop probe `probe/flt392_probe.ps1` (098's library); build; saltests (no
pure rule changes - the decision is "do not write the panel's group", no header needed)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core)
**Performance Goals**: n/a (one extra 1 KB stack object during OK)
**Constraints**: CLAUDE.md "a path or name is never cut" (a mask group is user text kept whole);
plug-in ABI untouched (`CMaskGroup` is core-internal; the plug-in interface wraps it unchanged)
**Scale/Scope**: one function, ~10 lines

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency, no build change - PASS |
| II. Backward compatibility | registry layout, filter syntax, dialog and history unchanged; only a cut that lost data goes away - PASS |
| III. Incremental modernization | a local change in one function - PASS |
| IV. Windows commitment | WinAPI only - PASS |
| V. Plug-in architecture | no plug-in interface touched - PASS |
| VI. UI consistency | no UI string, dialog or resource changes; the error box and its selection unchanged - PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/392-filter-dialog-backup/
├── plan.md, research.md, data-model.md, quickstart.md
├── fix-log.md, closing-report.md (at the end)
└── probe/flt392_probe.ps1, result_*.txt
```

### Source Code (repository root)

```text
src/dialogs3.cpp    CFilterDialog::Validate - check a local copy, never the panel's group
```

**Structure Decision**: core only; no header, no resource.

## Complexity Tracking

None.
