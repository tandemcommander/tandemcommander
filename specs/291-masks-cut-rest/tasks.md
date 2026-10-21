---

description: "Task list for feature 291 - masks and the view name never cut"
---

# Tasks: Recycle Bin, Find, viewer and compare masks and the view name are never cut

**Input**: Design documents from `specs/291-masks-cut-rest/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/refusal.md, quickstart.md

**Tests**: the hidden-desktop probe `probe/mask291_probe.ps1` (written and run before the change,
`probe/result_before.txt`: 12 FAIL) is the feature's test; `saltests` and 251's / 270's probes are
regression checks.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [ ] T001 Start `specs/291-masks-cut-rest/fix-log.md` with the measurement at c01e1801 (probe command, 12 FAIL / 5 controls PASS, registry restored identical) and the consumers enumerated in plan.md

---

## Phase 2: Foundational

No shared code: 251's `DlgItemTextFitsU8` (`src/dialogs3.cpp`) and `SalGetWindowTextU8Alloc` /
`SalGetWindowTextWAlloc` (`src/common/winlib.cpp`) exist.

---

## Phase 3: User Story 1 - Recycle Bin masks are never stored cut (Priority: P1) 🎯 MVP

**Goal**: the System page refuses Recycle Bin masks that do not fit 260 bytes, whatever the choice.

**Independent Test**: probe rows `rb-mask`, `rb-unused`, control `rb-ctl`.

- [ ] T002 [US1] In `CCfgPageSystem::Validate` (`src/dialogs4.cpp`) add `if (!DlgItemTextFitsU8(HWindow, IDE_RECYCLEMASKS, &ti, MAX_PATH)) return;` first, before the `useRecycle == 2` branch, with a feature-291 comment (Transfer stores the field whatever the radio)

---

## Phase 4: User Story 2 - Find never searches with a cut "Named" mask (Priority: P1)

**Goal**: Find refuses a Named text that does not fit before any search; Add Current / Manage /
Ignore refuse before reading the field; a stored option without Named keeps the whole field text.

**Independent Test**: probe rows `find-named`, `find-add`, `find-ignore`, `find-option`, control `find-ctl`.

- [ ] T003 [US2] In `CFindDialog::Validate` (`src/finddlg1.cpp`) add the check `DlgItemTextFitsU8(HWindow, IDC_FIND_NAMED, &ti, NAMED_TEXT_LEN)` first inside the `GetControl` block, before the backups and the syntax check
- [ ] T004 [US2] In `CFindDialog::DialogProc` (`src/finddlg1.cpp`) cases `CM_FIND_ADD_CURRENT`, `CM_FIND_MANAGE` (before `FindManageInUse = TRUE`) and `CM_FIND_IGNORE` (before `FindIgnoreInUse = TRUE`): `if (!DlgItemTextFitsU8(HWindow, IDC_FIND_NAMED, NULL, NAMED_TEXT_LEN))` return as the case already returns, nothing else done
- [ ] T005 [US2] In `CFindDialog::LoadControls` (`src/finddlg1.cpp`): when the option has no Named text and the field's text does not fit (`SalWindowTextFitsU8`), take its whole wide text (`SalGetWindowTextWAlloc`) and set it back after `TransferData(ttDataToWindow)` (`SetWindowTextW`); no memory -> `TRACE_E(LOW_MEMORY)`, return without loading; text that fits -> read as before

---

## Phase 5: User Story 3 - Viewer and compare masks are never stored cut (Priority: P2)

**Goal**: the Viewer page and Compare Directories refuse masks that do not fit.

**Independent Test**: probe rows `view-text`, `view-hex`, `cmp-files`, `cmp-dirs-unused`, controls `view-ctl`, `cmp-ctl`.

- [ ] T006 [P] [US3] In `CCfgPageViewer::Validate` (`src/dialogs4.cpp`) inside each `ti.IsGood()` block, before its `EditLine`: `if (!DlgItemTextFitsU8(HWindow, IDC_VIEW_INTEXT, &ti, MAX_PATH)) return;` and the same for `IDC_VIEW_INHEX`
- [ ] T007 [P] [US3] In `CCompareDirsDialog::Validate` (`src/dialogs6.cpp`) first check `IDE_COMPARE_IGNORE_FILES`, then `IDE_COMPARE_IGNORE_DIRS` (`MAX_PATH`), whatever the check boxes, return on a refusal

---

## Phase 6: User Story 4 - A view name is never stored cut (Priority: P3)

**Goal**: the Views in-place name edit refuses a name that does not fit 30 bytes and stores nothing.

**Independent Test**: probe rows `vname`, `vname-ascii`, control `vname-ctl`.

- [ ] T008 [US4] In `CCfgPageView::DialogProc` `LVN_ENDLABELEDIT` (`src/dialogs4.cpp`): read the edit whole (`SalGetWindowTextU8Alloc`, NULL -> `TRACE_E(LOW_MEMORY)`, nothing stored), `CleanName`; `strlen(name) >= VIEW_NAME_MAX` -> free, `SalMessageBox(HWindow, LoadStr(IDS_TOOLONGPATH), LoadStr(IDS_ERRORTITLE), MB_OK | MB_ICONEXCLAMATION)`, nothing stored; else store as before; the code-page fallback (no edit control) unchanged; free the heap copy

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T009 Run `python tools/check_encoding.py --strict` (TOTAL: 0 finding(s)) and `.\build.cmd` (BUILD SUCCEEDED)
- [ ] T010 Run `build\tandemcommander\Debug_x64\saltests\saltests.exe` (0 failed)
- [ ] T011 Run the probe after the change on the hidden desktop (`probe/result_after.txt`): 34 / 0, registry restored identical
- [ ] T012 Negative control: disable one check (`FALSE &&`), rebuild, run its rows - they must FAIL; restore, rebuild, PASS again (`probe/result_negative_control.txt`)
- [ ] T013 [P] Regression: 270's probe (`specs/270-mask-filter-label-fits/probe/mask270_probe.ps1`, 24 / 0) and 251's (`specs/251-dialog-text-fits/probe/dlg251_probe.ps1`, 42 / 0), results in `specs/291-masks-cut-rest/probe/`
- [ ] T014 Record the implementation, checks and results in `specs/291-masks-cut-rest/fix-log.md`

---

## Dependencies & Execution Order

- T001 first; T002-T008 independent of each other (T003-T005 one file, in order; T002, T006, T008 one file, in order); T009-T014 after all of them.
- The stories are independent; US1 (Recycle Bin, the data-loss case) is the MVP.

## Parallel Example

```text
T006 (dialogs4.cpp) and T007 (dialogs6.cpp) can be written in parallel; T013's two probes run one after another (one hidden desktop).
```

## Implementation Strategy

MVP = US1 (T002); then US2, US3, US4; one build and one probe run cover all.
