# Tasks: Opening a folder found by quick search goes straight to the new folder

**Input**: `specs/376-qs-enter-no-flash/` - plan.md, spec.md, research.md, quickstart.md
**Tests**: the hidden-desktop probe is the test (measurement before, after); no new saltests
rule (no pure decision changes).

## Phase 1: Setup

- [X] T001 Record the before-measurement and the code trace in specs/376-qs-enter-no-flash/fix-log.md (probe/result_before.txt, before_flash.png)

## Phase 2: Foundational

- [X] T002 Add the trailing `BOOL paint = TRUE` parameter to `RefreshListBox`, `BOOL deferPaint = FALSE` to `EndQuickSearch` and `QFEndView`, the method `QFFinishDeferredPaint()` and the member `BOOL QFPaintDeferred` (with comments, feature 376) in src/fileswnd.h
- [X] T003 Initialise `QFPaintDeferred = FALSE` next to the other QF members in the `CFilesWindow` constructor in src/fileswn1.cpp
- [X] T004 Implement the layout-only mode in `CFilesWindow::RefreshListBox` in src/fileswn2.cpp: with `paint == FALSE` call `ListBox->SetItemsCount(count, xOffset, topIndex, TRUE)` only (no scroll bars, no boundary correction, no header, no items); with `paint == TRUE` clear `QFPaintDeferred` and draw as today

## Phase 3: User Story 1 - no intermediate parent listing (P1)

**Goal**: Enter on a folder in a filtered panel draws the new folder's listing directly.
**Independent test**: probe rows FLASH (PARENT 0 in every round), CTRL.

- [X] T005 [US1] In src/fileswn0.cpp: `EndQuickSearch(deferPaint)` passes it to `QFEndView`; `QFEndView(repaint, deferPaint)` with a filtered view and `deferPaint` lays out without drawing (`RefreshListBox(-1, -1, FocusedIndex, TRUE, FALSE, FALSE)`), sets `QFPaintDeferred` and leaves `QFUpdateIndication` to the finish; add `QFFinishDeferredPaint()` (draws the laid-out listing once if still owed, then `QFUpdateIndication()`)
- [X] T006 [US1] In `CFilesWindow::Execute` in src/fileswn2.cpp: a scope guard declared before the filtered-view block, armed when that block calls `EndQuickSearch(TRUE)`; its destructor calls `QFFinishDeferredPaint()` on every return; update the 244 comment there
- [X] T007 [US1] Build (`.\build.cmd`) and run the probe (quickstart V1) -> probe/result_after.txt; FLASH PASS in every round; the settled class `NEW` (>= 70 % normal background, < 5 % tint) is the FR-004 check that the search ended; compare the start of the `NEW` run with the before-run (307-309 ms) for SC-003

## Phase 4: User Story 2 - everything around the opening stays (P2)

**Goal**: return position, Back history, failure paths and feature 244 unchanged.
**Independent test**: probe rows LOC, BACK, DENY, GONE; qs244 probe; saltests.

- [X] T008 [US2] Add the failure rows to specs/376-qs-enter-no-flash/probe/qs376_probe.ps1: DENY (a folder whose listing is denied to the user - access denied, panel stays) and GONE (a matching folder deleted just before Enter); each must end with the whole parent folder drawn, untinted (classifier PARENT against its own Esc reference or plain background below the rows), panel still in the parent; restore the ACL in `finally`
- [X] T009 [US2] Run the extended probe before the fix (a copy of the old exe or the build of `main` in a worktree) to know the failure rows' baseline, and after the fix -> probe/result_after.txt
- [X] T010 [US2] Run the feature 244 probe (quickstart V2) -> probe/result_qs244.txt, FAIL 0; run saltests (quickstart V3), 0 failed

## Phase 5: Polish

- [X] T011 [P] `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s); clang-format the changed sources
- [X] T012 Record after-measurements, decisions and the out-of-scope finding (other path-change routes, R4) in specs/376-qs-enter-no-flash/fix-log.md; add the Inbox item (`measure:376`) if the other routes are confirmed to draw the parent

## Dependencies

T001 -> T002 -> T003, T004 -> T005 -> T006 -> T007 -> T008 -> T009 -> T010 -> T011, T012.
US2 depends on US1 (same code path). No parallel work worth splitting (three files, one change).

## Implementation strategy

MVP = US1 (T002-T007). US2 proves nothing else moved and covers the failure paths that the guard
exists for.
