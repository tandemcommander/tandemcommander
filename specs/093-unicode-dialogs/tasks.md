# Tasks: Unicode text in dialogs (feature 093)

Revised after the measurement in the product (spec *Clarifications*, plan).
Every stage: check the sites at HEAD first, implement, Debug build, saltests,
strict guard, probe, independent review, fixes, fix-log, commit.

## Phase 1 - Setup

- [X] T001 Baseline: saltests 12,828/0, strict guard 0; Win32 semantics probe in probe/B1Probe.cs; pre-change Debug build preserved at build\tandemcommander\Debug_x64_pre093
- [X] T002 Commit spec artefacts
- [X] T003 Measure the product: probe/dialogs_probe.ps1, probe/baseline_result.txt (56 PASS, 25 LOSSY); revise spec, plan, tasks

## Phase 2 - User Stories 1-3: loops and attached helpers (S1)

- [X] T004 [US2] src/find.cpp Find thread loop and the secondary loops in src/finddlg1.cpp: wide
- [X] T005 [US3] src/common/sheets.cpp Configuration holder loop: wide
- [X] T006 src/salamdr1.cpp main loop: `IsDialogMessageW`
- [X] T007 [US2] src/common/winlib.cpp `CWindow::AttachToWindow` follows the control's kind; audit `WindowProc` overrides of helpers attached to text fields (`CComboboxEdit` src/execute.cpp, `CEditLBEdit` src/edtlbwnd.cpp, key forwarders)
- [X] T008 src/common/winlib.cpp overflow in `CTransferInfo::EditLine` / `SalGetWindowTextU8` cuts at a whole character; saltests for the pure part
- [X] T009 Probe: extend dialogs_probe.ps1 with the five modal dialogs not driven yet (Convert, Make File List, compare arguments, Change Icon, volume label) and the in-place list editor; run on the pre-change build (negative control) and the new build
- [X] T010 Independent review; fixes; commit `[093] S1 ...`

## Phase 3 - User Story 4: 7-Zip password (S2)

- [X] T011 [US4] src/plugins/7zip: Unicode password at the four sites, legacy retry (contract P1), wipe of the char buffers
- [X] T012 [US4] Engine probe + GUI probe (SC-004)
- [X] T013 [US4] Independent review; fixes; commit `[093] S2 ...`

## Phase 4 - User Story 5: command line (S3)

- [ ] T014 [US5] src/editwnd.cpp: Unicode control; typed-character switch, selection offsets, drop position, measuring
- [ ] T015 [US5] Probe: set, type, insert a name, run a command; editing regression
- [ ] T016 [US5] Independent review; fixes - or revert and record; commit `[093] S3 ...`

## Phase 5 - Polish (S4)

- [ ] T017 Gates: Debug + full Release builds, saltests, strict guard, probes of 087/088/089/092 and of this feature
- [ ] T018 Records: CHANGELOG, specs/NEXT-WORK.md, 069 REMAINING-WORK (B-1), CLAUDE.md, quickstart.md, fix-log.md
- [ ] T019 Commit
