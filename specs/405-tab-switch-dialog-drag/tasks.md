# Tasks: A tab switch that shows a dialog never leaves the tab strip in drag mode

**Input**: Design documents from `specs/405-tab-switch-dialog-drag/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: requested by the spec (FR-005 unit checks, FR-006 probe).

## Phase 1: Setup

- [X] T001 Start the running log `specs/405-tab-switch-dialog-drag/fix-log.md` with the measurement at 09eaa097 (probe `result_before.txt`, the sites, the callers of `OnLButtonDown`)

## Phase 2: Foundational

- [X] T002 Add the pure rule `SalTabArmDragAfterSwitch(BOOL downAtPress, BOOL downAfterSwitch)` to `src/common/saltabs.h` and `src/common/saltabs.cpp` (table of data-model.md)
- [X] T003 Add `TestTabStrip405` with the four rows of the rule to `src/saltests/saltests.cpp` and call it next to `TestTabStrip404`

## Phase 3: User Story 1 - Switching away from a tab that asks a question (P1)

**Goal**: no capture, no pending drag after a switch during which the button went up.
**Independent test**: probe `tabs405_probe.ps1` rows RELEASED and NOBUTTON.

- [X] T004 [US1] In `CTabWindow::OnLButtonDown` (`src/tabwnd.cpp`, `case tspTab`) read `GetKeyState(VK_LBUTTON)` at the start of the handler and after `SwitchToTab`; arm `WaitForDrag` / `SetCapture` only when `SalTabArmDragAfterSwitch` allows it
- [X] T005 [US1] In `CTabWindow::OnLButtonDown` (`src/tabwnd.cpp`) cancel a pending gesture (`WaitForDrag`, `Dragging`, `PressedClose >= 0`) with `CancelGesture()` before the hit test is acted on (FR-003)
- [X] T006 [US1] Build (`build.cmd`), run `saltests`, run `tabs405_probe.ps1 -Label after` -> `specs/405-tab-switch-dialog-drag/probe/result_after.txt`

## Phase 4: User Story 2 - A real drag still works (P2)

**Goal**: drags held from the press to the release unchanged.
**Independent test**: `tabs405_probe` row HELD; `tabs404_probe` (all rows).

- [X] T007 [US2] Run `specs/404-panel-tabs-rounded-look/probe/tabs404_probe.ps1` with `-Label after405` on the hidden desktop -> `specs/405-tab-switch-dialog-drag/probe/result_tabs404.txt`; expect 29 PASS / 0 FAIL / 1 NOT DRIVEN

## Phase 5: Polish

- [X] T008 Encoding guard `python tools/check_encoding.py --strict` -> TOTAL 0; clang-format the changed sources (`src/tabwnd.cpp`, `src/common/saltabs.*`, `src/saltests/saltests.cpp`)
- [X] T009 Check the manual under `help/` for a description of tab dragging that would need a sentence (expected: none)
- [X] T010 Add the person check (real FTP question, real mouse) to the release checklist item; record before / after in `specs/405-tab-switch-dialog-drag/fix-log.md`
- [ ] T011 Add the CHANGELOG `## [Unreleased]` entry in `CHANGELOG.md` and the entry in `specs/FEATURE-HISTORY.md` (run step 8)

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009 -> T010 -> T011. US2 depends on the US1 change (it is its regression check).

## Parallel opportunities

T002/T003 (rule and its checks) can be written together; T008 and T009 are independent.

## Implementation strategy

MVP = US1 (T001-T006); US2 is the regression proof; then polish.
