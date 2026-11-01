# Implementation Plan: Opening a folder found by quick search goes straight to the new folder

**Branch**: `376-qs-enter-no-flash` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/376-qs-enter-no-flash/spec.md`

## Summary

Opening a folder from a quick-search-filtered panel ends the search first, and ending it lays out
**and draws** the parent's whole listing before the new folder is read (measured: ~290 ms of the
parent picture for a 30,000-file folder, 3 of 3 rounds). The fix keeps the order (full listing
back and laid out before the path change - rule 244, the remembered top index, the Back history)
but drops the drawing on this one route: a layout-only mode of `RefreshListBox`, a deferred-paint
flag, and a scope guard in `CFilesWindow::Execute` that draws the parent once if the opening did
not draw anything else (research R1-R3).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI/GDI only
**Storage**: N/A (no settings, no registry change)
**Testing**: hidden-desktop probe `probe/qs376_probe.ps1` (pixel sampling), feature 244 probe
`specs/244-quick-search-substring-filter/probe/qs244_probe.ps1 -Expect new`, saltests (no new
pure rule - the change is drawing order, not a decision)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `src/`)
**Performance Goals**: the time from Enter to the new listing does not grow (one layout of the
parent less drawing; a failure path draws once later instead of once earlier)
**Constraints**: standing rule 244 (`Dirs`/`Files` full before a path change, `QFSuspend` /
`EndQuickSearch` first); no UI string; no plug-in interface change
**Scale/Scope**: 3 files of the core (`fileswnd.h`, `fileswn0.cpp`, `fileswn2.cpp`)

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no build or dependency change - PASS |
| II Backward compatibility | behaviour identical except the missing intermediate drawing; settings, registry, plug-in ABI untouched - PASS |
| III Incremental modernization | a small targeted change, measured before/after - PASS |
| IV Windows commitment | WinAPI only - PASS |
| V Plugin architecture | no `spl_*.h` change; the archive / plug-in-FS branches of `Execute` keep their calls - PASS |
| VI UI consistency | no new UI; the panel shows fewer intermediate states - PASS |

Post-design re-check: unchanged, PASS.

## Design

1. `CFilesWindow::RefreshListBox(..., BOOL wholeItemVisible, BOOL paint = TRUE)`:
   - `paint == FALSE`: everything up to the final block as today; then
     `ListBox->SetItemsCount(count, xOffset, topIndex, TRUE)` only (no scroll bars, no boundary
     correction, no header, no items); `IdleRefreshStates` and `WM_USER_SELCHANGED` as today.
   - `paint == TRUE`: as today, and `QFPaintDeferred = FALSE` (a full drawing pays an owed one).
2. `EndQuickSearch(BOOL deferPaint = FALSE)` passes it to `QFEndView(BOOL repaint, BOOL
   deferPaint = FALSE)`; with a filtered view and `deferPaint` it calls the layout-only
   `RefreshListBox(-1, -1, FocusedIndex, TRUE, FALSE, FALSE)`, sets `QFPaintDeferred = TRUE` and
   leaves `QFUpdateIndication()` to the finish.
3. `QFFinishDeferredPaint()`: if `QFPaintDeferred` - clear it and
   `RefreshListBox(-1, ListBox->GetTopIndex(), FocusedIndex, TRUE, FALSE)`; then always
   `QFUpdateIndication()`.
4. `CFilesWindow::Execute`: a small guard object (holds the panel, armed when the search is
   ended) declared before the filtered-view block; the block calls `EndQuickSearch(TRUE)` and
   arms it; its destructor calls `QFFinishDeferredPaint()` on every return.
5. `BOOL QFPaintDeferred` member, initialised FALSE with the other QF members.

Callers of `RefreshListBox` (≈60) and `EndQuickSearch` (≈20) keep their calls; the new
parameters are trailing with the old behaviour as default.

## Project Structure

### Documentation (this feature)

```text
specs/376-qs-enter-no-flash/
├── spec.md, plan.md, research.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/qs376_probe.ps1 (+ result_*.txt, before_flash.png)
```

No `data-model.md` (no data entities) and no `contracts/` (no external interface: no plug-in
API, no file format, no command-line change).

### Source Code (repository root)

```text
src/fileswnd.h     RefreshListBox / EndQuickSearch / QFEndView signatures, QFFinishDeferredPaint, QFPaintDeferred
src/fileswn0.cpp   EndQuickSearch, QFEndView, QFFinishDeferredPaint
src/fileswn1.cpp   QFPaintDeferred initialised (constructor, next to the other QF members)
src/fileswn2.cpp   Execute (guard), RefreshListBox (paint parameter)
```

## Complexity Tracking

None.
