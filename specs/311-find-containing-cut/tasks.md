# Tasks: Find's Containing text and the viewer's Find text are never cut

**Input**: Design documents from `specs/311-find-containing-cut/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/refusal.md, quickstart.md

**Tests**: the hidden-desktop probe is the test (spec SC-001); no new `saltests` rule (the refusal
reuses 251's tested `SalWTextFitsU8`).

## Phase 1: Setup

- [ ] T001 Start `specs/311-find-containing-cut/fix-log.md` with the measurement of step 3 (commands, 8 FAIL rows at 95145b44)
- [ ] T002 Move the measurement probe into `specs/311-find-containing-cut/probe/grep311_probe.ps1` (label `grep311_probe (feature 311)`, fixture `%TEMP%\tc311_grep`, backup `%TEMP%\tc311_backup.reg`), add rows `grep-manage` (CM_FIND_MANAGE 2248) and `view-copy` (Find with 66 letters + `Z`, then Containing 67 letters, CM_FIND_ALTVIEW 2222, the viewer's Find field must not be the cut 66 letters); copy the before results into `specs/311-find-containing-cut/probe/result_before.txt`

## Phase 2: Foundational

- [ ] T003 Run the probe's two new rows before the change and record them in `specs/311-find-containing-cut/fix-log.md`

## Phase 3: User Story 1 - Find never searches for a cut Containing text (P1)

**Independent test**: probe rows `grep`, `grep-regex`, `grep-hex`, control `grep-ctl`.

- [ ] T004 [US1] In `CFindDialog::Validate` (`src/finddlg1.cpp`), after 291's Named check: `if (!DlgItemTextFitsU8(HWindow, IDC_FIND_CONTAINING, &ti, GREP_TEXT_LEN)) return;` with a `feature 311` comment

## Phase 4: User Story 2 - Options commands never write a cut text back (P1)

**Independent test**: probe rows `grep-add`, `grep-manage`, `grep-ignore`.

- [ ] T005 [US2] In `src/finddlg1.cpp` `CM_FIND_ADD_CURRENT`, `CM_FIND_MANAGE`, `CM_FIND_IGNORE`: after the Named check, refuse with `DlgItemTextFitsU8(HWindow, IDC_FIND_CONTAINING, NULL, GREP_TEXT_LEN)` (the command does nothing)

## Phase 5: User Story 3 - A stored option without Containing keeps the whole field (P2)

**Independent test**: probe row `grep-option`.

- [ ] T006 [US3] In `CFindDialog::LoadControls` (`src/finddlg1.cpp`): keep the Containing field whole as 291 keeps Named (`keepGrep` via `SalGetWindowTextU8Alloc` before `Data` changes, put back after `TransferData(ttDataToWindow)`, no memory -> TRACE_E and return without loading; free on every path); the "expand when Containing has text" test also counts `keepGrep`

## Phase 6: User Story 4 - The viewer's Find never searches for a cut text (P2)

**Independent test**: probe rows `view-find`, `view-ctl`, `view-copy`.

- [ ] T007 [P] [US4] Declare `virtual void Validate(CTransferInfo& ti);` in `CFindSetDialog` (`src/viewer.h`) and implement it in `src/viewer.cpp` with `DlgItemTextFitsU8(HWindow, IDC_FINDTEXT, &ti, FIND_TEXT_LEN)` (include `dialogs.h` if not reachable)
- [ ] T008 [US4] In `CFindDialog::UpdateInternalViewerData` (`src/finddlg1.cpp`): return before copying when `SalWindowTextFitsU8(GetDlgItem(HWindow, IDC_FIND_CONTAINING), FIND_TEXT_LEN)` is FALSE

## Phase 7: Polish & verification

- [ ] T009 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [ ] T010 `build.cmd` -> `BUILD SUCCEEDED`; `saltests.exe` -> 0 failed
- [ ] T011 Run `probe/grep311_probe.ps1` after the change -> all rows PASS; save `probe/result_after.txt`
- [ ] T012 Negative control: a build with the Validate check (T004) disabled must FAIL `grep`; record and restore
- [ ] T013 Regression: 291's probe `specs/291-masks-cut-rest/probe/mask291_probe.ps1` all PASS -> `probe/regress_291.txt`
- [ ] T014 Record before / after, commands and results in `specs/311-find-containing-cut/fix-log.md`

## Dependencies

T001-T003 before the code; T004-T008 independent of each other except that T004-T006, T008 share
`src/finddlg1.cpp` (sequential); T007 is in other files ([P]). T009-T014 after all code tasks.

## Parallel example

T007 (`viewer.h` / `viewer.cpp`) can be written while T004-T006 are edited in `finddlg1.cpp`.

## Implementation strategy

MVP = US1 (the search refuses); US2-US4 complete the item (nothing cut written back or stored). One
build and one probe run cover all stories.
