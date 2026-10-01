# Tasks: Unicode dialogs (feature 093)

Every stage: check the sites at HEAD first (the research's line numbers are
from an earlier branch), implement, Debug build, saltests, strict guard,
probe, independent review, fixes, fix-log, commit.

## Phase 1 — Setup

- [ ] T001 Baseline: saltests count, strict guard total; copy the Win32 semantics probe to specs/093-unicode-dialogs/probe/B1Probe.cs; preserve a pre-change Debug build for the negative controls (build\tandemcommander\Debug_x64_pre093)
- [ ] T002 Commit spec artefacts `[093] Spec, research, plan, contract, tasks`

## Phase 2 — Foundational (S0)

- [ ] T003 src/common/winlib.cpp, winlib.h: `CWindow::AttachToWindow` follows the control's kind (contract D3); audit `WindowProc` overrides of classes attached to text fields (`CComboboxEdit` in src/execute.cpp, `CEditLBEdit` in src/edtlbwnd.cpp, `CKeyForwarderWindow`)
- [ ] T004 src/common/winlib.cpp: overflow in `CTransferInfo::EditLine` and `SalGetWindowTextU8` cuts at a whole character (contract D4); saltests for the pure part
- [ ] T005 src/salamdr1.cpp: main loop `IsDialogMessageW` (contract D5)
- [ ] T006 specs/093-unicode-dialogs/probe/dialogs_probe.ps1: driver with the three channels (IsWindowUnicode, prefill, posted characters) and the outcome check; first run on the already-Unicode Create Directory dialog and on Change Directory as the expected failure
- [ ] T007 Independent review; fixes; commit `[093] S0 …`

## Phase 3 — User Story 1: modal path dialogs (S1)

- [ ] T008 [US1] `unicodeWnd TRUE`: `CChangeDirDlg`, `CPackDialog`, `CUnpackDialog`, `CFilterDialog`, `CConvertFilesDlg`, `CChangeIconDialog`, `CDriveInfo` (src/dialogs3.cpp); `CSelectDialog`, `CCompareArgsDlg` (src/dialogs2.cpp); `CFileListDialog` (src/dialogs.cpp); per dialog audit of attached helpers, notifications and code-page reads
- [ ] T009 [US1] src/execute.cpp `BrowseCommand` / `BrowseDirCommand` and the `WM_GETTEXT` in Convert: wide reads
- [ ] T010 [US1] Probe every dialog of T008 (SC-001, SC-002) with the negative control on the pre-change build
- [ ] T011 [US1] Independent review; fixes; commit `[093] S1 …`

## Phase 4 — User Story 2: Find (S2)

- [ ] T012 [US2] `CFindDialog` and its sub-dialogs (src/finddlg1.cpp, finddlg2.cpp, filter.cpp) Unicode; loops in src/find.cpp and the secondary loops in src/finddlg1.cpp wide; combo edit helpers
- [ ] T013 [US2] Probe: typing into Named / Look in / Containing through the real loop; a search in a non-code-page folder; menu and shortcuts regression; stored histories
- [ ] T014 [US2] Independent review; fixes; commit `[093] S2 …`

## Phase 5 — User Story 3: Configuration (S3)

- [ ] T015 [US3] `unicodeWnd` parameter on `CPropSheetPage` / `CCommonPropSheetPage` (src/common/sheets.cpp, src/salamand.h); holder loop wide
- [ ] T016 [US3] Pages: Hot Paths, User Menu, Command Shell (src/dialogs4.cpp), Viewers, Editors (src/dialogs5.cpp), Packers, Unpackers, Archiver Locations (src/dialogsp.cpp, with its code-page reads/writes → UTF-8 helpers); `CEditListBox` in-place edit wide (src/edtlbwnd.cpp); notifications in both forms
- [ ] T017 [US3] Probe: stored values after OK; unchanged-on-OK (FR-007); label editing; tree navigation
- [ ] T018 [US3] Independent review; fixes; commit `[093] S3 …`

## Phase 6 — User Story 4: 7-Zip password (S5)

- [ ] T019 [US4] Measure the password path (engine probe with archives made by the 7-Zip program); record
- [ ] T020 [US4] src/plugins/shared/winliblt.{h,cpp}: optional default-off `unicodeWnd` on `CDialog`; src/plugins/7zip: prompts created wide, password held and handed over as Unicode, one retry with the legacy form (contract P1), wiping kept
- [ ] T021 [US4] Engine probe + GUI probe of the prompt (SC-004)
- [ ] T022 [US4] Independent review; fixes; commit `[093] S5 …`

## Phase 7 — User Story 5: command line (S4)

- [ ] T023 [US5] src/editwnd.cpp: control created wide; typed-character switch, selection offsets, drop position, measuring in UTF-16 units
- [ ] T024 [US5] Probe: insert a non-code-page name, type, run a command; editing regression
- [ ] T025 [US5] Independent review; fixes — or revert and record; commit `[093] S4 …`

## Phase 8 — Polish (S6)

- [ ] T026 Gates: Debug + full Release builds, saltests, strict guard, probes of 087/088/089/092 and of this feature; SC-006 sample (message box, About, master password stay code-page windows)
- [ ] T027 Records: CHANGELOG, specs/NEXT-WORK.md, specs/069-finish-encoding-fixes/REMAINING-WORK.md (B-1), CLAUDE.md, quickstart.md, fix-log.md
- [ ] T028 Commit

## Dependencies

S0 blocks everything. S1, S2, S3 are independent of each other after S0 but
share files (run in order). S5 depends only on S0's helper semantics. S4 last.
