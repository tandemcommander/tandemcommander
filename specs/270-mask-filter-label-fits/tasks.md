# Tasks: typed masks, filter, volume label and hot path name are never cut

**Input**: `specs/270-mask-filter-label-fits/` (spec.md, plan.md, research.md, data-model.md, contracts/refusal.md, quickstart.md)
**Tests**: the hidden-desktop probe `probe/mask270_probe.ps1` (requested by the spec's success criteria); no new pure rule.

## Phase 1: Setup

- [ ] T001 Record the before measurement (probe 11 rows, 7 FAIL) in specs/270-mask-filter-label-fits/fix-log.md and keep probe/result_before*.txt

## Phase 2: Foundational

- [ ] T002 Confirm `DlgItemTextFitsU8` (src/dialogs.h, src/dialogs3.cpp) is declared for dialogs2.cpp and dialogs3.cpp, and `SalGetWindowTextU8Alloc` (src/common/winlib.h) for dialogs4.cpp - no new helper

## Phase 3: User Story 1 - a mask never selects or converts other files (P1)

**Independent test**: probe rows `sel-mask`, `unsel-mask`, `conv-mask`, `sel-ctl`, `conv-ctl`.

- [ ] T003 [P] [US1] `CSelectDialog::Validate` in src/dialogs2.cpp: `DlgItemTextFitsU8(HWindow, IDE_FILEMASK, &ti, MAX_PATH)` first; return on a refusal (before the syntax check)
- [ ] T004 [P] [US1] `CConvertFilesDlg::Validate` in src/dialogs3.cpp: the same check first, before the syntax and the convert-action checks

## Phase 4: User Story 2 - a filter is never cut (P2)

**Independent test**: probe rows `flt`, `flt-unused`, `flt-ctl`.

- [ ] T005 [US2] `CFilterDialog::Validate` in src/dialogs3.cpp: the check on `IDE_FILTER` before the `useFilter` branch

## Phase 5: User Story 4 - a hot path name typed with F2 is never stored cut (P2)

**Independent test**: probe rows `hp-label`, `hp-label-ctl`; 251's probe `hp-*` rows.

- [ ] T006 [P] [US4] `CCfgPageHotPath::DialogProc` `LVN_ENDLABELEDIT` in src/dialogs4.cpp: read the edit with `SalGetWindowTextU8Alloc`, `CleanName`, `SetName`, free; NULL (no memory) -> TRACE_E, nothing stored; the code-page fallback (no edit control) unchanged

## Phase 6: User Story 3 - a volume label is never written cut (P3)

**Independent test**: probe row `vol`.

- [ ] T007 [US3] `CDriveInfo::Validate` in src/dialogs3.cpp: the check on `IDE_VOLNAME` in the `ttDataFromWindow` branch before reading `newName` / `SetVolumeLabel`

## Phase 7: Polish & verification

- [ ] T008 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [ ] T009 `.\build.cmd` -> `BUILD SUCCEEDED`; `saltests.exe` -> `0 failed`
- [ ] T010 Probe after: specs/270-mask-filter-label-fits/probe/result_after.txt - every row PASS (vol NOT DRIVEN only when elevated)
- [ ] T011 Negative control: revert one site (e.g. T003) temporarily, rebuild, its row FAILs; restore, rebuild
- [ ] T012 Regression: 251's probe specs/251-dialog-text-fits/probe/dlg251_probe.ps1 -> 42 / 0 (result in specs/270-mask-filter-label-fits/probe/regress_251.txt)
- [ ] T013 Record after / commands / results in specs/270-mask-filter-label-fits/fix-log.md

## Dependencies

T001 -> T002 -> (T003, T004, T005, T006, T007 independent; T004, T005, T007 share dialogs3.cpp, so in sequence) -> T008-T013.

## Parallel example

T003 (dialogs2.cpp) and T006 (dialogs4.cpp) in parallel with the dialogs3.cpp tasks T004 -> T005 -> T007.

## Implementation strategy

MVP = US1 (the mask that can lead a file operation to other files); the rest are small and go in
the same change; one probe run checks them all.
