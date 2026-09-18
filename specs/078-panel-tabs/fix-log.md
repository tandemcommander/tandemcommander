# Feature 078 — Panel Tabs: running log

Kept up to date by every task in `tasks.md`. A ticked task there means
"verified", and the evidence is here.

## Status checklist per task

| Task | Status | Note |
|---|---|---|
| T001 | done | this log |
| T002-T008 | done | scaffolding, ids 2860-2880 / 5956-5957 / IDC_TABSTRIP 958 / IDH_TABSTRIP 143 / IDC_PANELTABS 6235 / IDS 14212-14223, strings, Appearance checkbox (`ta&bs`), translator words |
| T009-T011 | done | `src/common/saltabs.*` + `TestPanelTabs078()`: saltests 1353 -> 1405 checks, 0 failed |
| T012-T018 | done | `CPathHistory::IsLocked`, `Configuration.PanelTabs` ("Panel Tabs", default on), `CPanelTab`/`CPanelTabs`, `CFilesWindow` members, `CaptureActiveTab`, `SwitchToTab`, histories over all tabs |
| T019-T020 | done | `CTabWindow` (paint, hit test, hot tracking, click/plus/close/list/middle/drag/context), `ToggleTabStrip`, `SetTabsEnabled`, panel + main layout, `GetDirectoryLineHeight` = strip + line, start-up wiring |
| T021-T026 | done | tab operations, strip interactions, title follows `DirectoryLineSetText`, list button, activation/colour/font/lock hooks, Appearance page + FR-005 confirmation + post-OK relayout |

## Decisions taken while implementing

- **T017 verification (research R4)**: `CPathHistory::AddPath` (`src/salamdr3.cpp:1988`) returns early when the new path equals the "actual" item (top of the list, or the item before `ForwardIndex`), and `ChangeActualPathData` (`:1942`) updates only when the path matches the actual item. So swapping `PathHistory` to the target tab **before** `ChangeDir` is correct as designed: the leaving panel's cursor was recorded by the explicit `RefreshPathHistoryData()` call, `ChangeDir`'s own call is a no-op on the target history, and `DirectoryLineSetText` does not duplicate the target's top entry. No `RemoveCurrentPathFromHistory` needed.
- `ToggleTabStrip` lives in `src/paneltabs.cpp` next to the other tab code, not in `fileswn2.cpp` (tasks T020 said "modelled on `ToggleDirectoryLine`" - it is, byte for byte in shape); `fileswn*.cpp` gain only hook lines.
- The strip repaints itself whole on hot-track changes through the shared `ItemBitmap` cache (one `BitBlt`, no flicker) instead of item-wise `GetDC` painting; simpler and the strip is small.
- Hovered *background* tabs use `CurrentColors[HOT_PANEL]` (their fill is `COLOR_BTNFACE`); hovered *active* tabs use `HOT_ACTIVE`/`HOT_INACTIVE` (caption fill) - the palette's intent, contract §3 refined.
- `SalTabTitleFromLocation`: a UNC root is returned whole for plugin file systems too (`nethood:\server` -> `\server`) - found by the unit test.
- The first tab owns the panel's `CPathHistory` from the constructor on (the panel pointer always refers to the active tab's history); the destructor no longer deletes it.
- Tooltips answer through `CopyToolTipAnswer` with `LoadStrU8`; the FR-005 confirmation is composed with `LoadStrU8` + `_snprintf_s` and shown with `SalMessageBox` (forwards to `SalMessageBoxEx`, UTF-8-aware as in cmdshell.cpp).

## Verification results

- 2026-09-18 Phase 2 checkpoint: `build.cmd` exit 0 (Debug x64, encoding guard inside), `saltests.exe`: 1405 checks, 0 failed. Screenshot of the running Debug build: each panel shows a one-tab strip (`Downloads` / `Release_x64`) with the `+` button above the Directory Line; Middle Toolbar and panel content laid out below it.

## Deviations from the plan

- The first wiring script was re-run after a failed anchor and doubled the first group of edits (its idempotency check was wrong); the affected files were reverted with `git checkout` and re-applied once - no trace in the tree, recorded for honesty.
