# Implementation Plan: The parent of a share's root offers the server's shares

**Branch**: `284-share-root-parent` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/284-share-root-parent/spec.md`

## Summary

Without a Network plug-in, the root of `\\server\share` gets the `..` entry, and the four ways up
from it (`..` executed - Enter, double click, Backspace, Ctrl+PgUp, *Parent directory*; *Go to
root*; *Open in other panel* on `..`) hand `\\server\` to the panel's ordinary path change
(`CFilesWindow::ChangeDir`), which since feature 125 offers the server's share list
(`PickServerShare`). One pure rule decides "a share's root, and its server path":
`SalUncShareRootServerPath` in `src/common/saluncserver.h`, with `saltests` checks. Every plug-in
route stays first and unchanged.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI only; feature 125's `CUncSharesJob` / `PickServerShare`
**Storage**: none (nothing stored)
**Testing**: `saltests` (pure rule); hidden-desktop probe `probe/shareroot_probe.ps1` (Debug seam
`TC_PROBE_UNC_SHARES` of 125)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `src/`)
**Performance Goals**: none new - the share list waits as in 125 (400 ms quiet, then the wait window)
**Constraints**: no new UI string (FR-008); never cut a path (refuse); plug-in route untouched
**Scale/Scope**: four call sites + one listing decision + one header rule

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | no new dependency, no project change (header-only rule) | PASS |
| II. Backward compatibility | only the share root without a Network plug-in changes - from "nothing happens" to the share list; every other path and the plug-in route unchanged (FR-005, FR-006); no registry, no stored data | PASS |
| III. Incremental modernization | reuses 125's route; the rule in `src/common/` with tests | PASS |
| IV. Windows commitment | WinAPI only | PASS |
| V. Plugin architecture | no plug-in API change; the nethood route is checked first as before | PASS |
| VI. UI consistency | the same list, wait window and messages as Change Directory to `\\server\`; no new text | PASS |

Post-design re-check: unchanged - PASS.

## Project Structure

### Documentation (this feature)

```text
specs/284-share-root-parent/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── contracts/share-root-rule.md
├── checklists/requirements.md
└── probe/shareroot_probe.ps1, result_before.txt, result_after.txt
```

### Source Code (repository root)

```text
src/common/saluncserver.h   SalUncShareRootServerPath (new, pure, header-only)
src/saltests/saltests.cpp   TestUncShareRoot284 (checks of the rule)
src/fileswn3.cpp            ReadDirectory: `..` in a share's root also without the plug-in
src/fileswn2.cpp            Execute of `..`: the plug-in first, else ChangeDir("\\server\")
src/fileswn1.cpp            GotoRoot: the plug-in first, else in a share's root ChangeDir("\\server\")
src/fileswn8.cpp            OpenFocusedInOtherPanel: `..` of a share's root -> "\\server\" for the other panel
```

**Structure Decision**: core only; the four sites include `saluncserver.h` (it is header-only,
already included by `fileswnb.cpp` and `shares.cpp`).

## Complexity Tracking

None.
