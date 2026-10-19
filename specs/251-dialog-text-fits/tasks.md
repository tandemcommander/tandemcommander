# Tasks: 251 - typed text is never cut to the caller's buffer

Tests: the spec asks for `saltests` checks of the rule (SC-003) and the probe (SC-001).

## Phase 1: Setup

- [X] T001 Probe `specs/251-dialog-text-fits/probe/dlg251_probe.ps1` (214's driver, 098's library) with the 12 rows of the spec; run on the build before (`build\tandemcommander\Debug_x64_pre251`) into `specs/251-dialog-text-fits/probe/result_before.txt` - refusal rows FAIL, `mfl-ctl` PASS

## Phase 2: Foundational (blocks every story)

- [X] T002 `SalWTextFitsU8` declaration and definition in `src/common/salunicode.h` / `src/common/salunicode.cpp` (contract `contracts/text-fits.md`)
- [X] T003 `saltests` checks of `SalWTextFitsU8` in `src/saltests/saltests.cpp`: ASCII 259 / 260 chars in 260, 86 / 87 CJK in 259 / 260, a surrogate pair (4 bytes), a lone surrogate (3), the empty text and NULL, `bufSize` 0 and negative
- [X] T004 `SalWindowTextFitsU8` and `SalGetWindowTextU8Alloc` in `src/common/winlib.h` / `src/common/winlib.cpp` (INSIDE_SALAMANDER section beside `SalGetWindowTextU8`)
- [X] T005 `DlgItemTextFitsU8` in `src/dialogs3.cpp` (declared in `src/dialogs.h`): the 214 `CopyMoveTargetTextFits` generalised; 214's two calls (`CCopyMoveDialog::Validate`, `CCopyMoveMoreDialog::Validate`) use it

## Phase 3: User Story 1 - Make File List (P1)

Independent test: probe rows `mfl-name`, `mfl-line`, `mfl-ctl`.

- [X] T006 [US1] `CFileListDialog::Validate` in `src/dialogs.cpp`: refuse `IDC_FL_LINE` (MAX_PATH) before `ValidateMakeFileList`; refuse `IDC_FL_FILENAME` (MAX_PATH) when the destination is File, before `SalGetFullName`
- [X] T007 [US1] `CFileListDialog::Transfer` in `src/dialogs.cpp`: from the window, store the file name only when it fits (otherwise keep `Configuration.FileListName`)
- [X] T008 [US1] `IDC_FL_FNBROWSE` in `src/dialogs.cpp`: refuse instead of browsing from a cut name

## Phase 4: User Story 2 - user menu, viewers, editors (P1)

Independent test: probe rows `um-cmd`, `um-args`, `vw-cmd`, `ed-cmd`.

- [X] T009 [US2] `CCfgPageUserMenu::StoreControls` in `src/dialogs4.cpp`: whole texts (`SalGetWindowTextU8Alloc`) into the item
- [X] T010 [US2] `CCfgPageUserMenu::Validate` in `src/dialogs4.cpp`: every item first - Command / Initial directory MAX_PATH, Arguments USRMNUARGS_MAXLEN; refuse (`IDS_TOOLONGPATH`), select the item, mark the field
- [X] T011 [P] [US2] `CCfgPageViewers::StoreControls` / `Validate` and `CCfgPageEditors::StoreControls` / `Validate` in `src/dialogs5.cpp`: the same, MAX_PATH for all three fields

## Phase 5: User Story 3 - hot paths, drives, Edit New default (P2)

Independent test: probe rows `hp-path`, `hp-name`, `drv-goto`, `en-default`.

- [X] T012 [US3] `CCfgPageHotPath::StoreControls` / `StoreName` in `src/dialogs4.cpp`: whole text, no code-page fallback; `CCfgPageHotPath::Validate`: every slot's path (HOTPATHITEM_MAXPATH) and name (MAX_PATH) - refuse, select the slot, mark the field
- [X] T013 [US3] `CCfgPageDrives::Validate` (new, declared in `src/cfgdlg.h`) in `src/dialogs5.cpp`: an edited `IDE_DRVSPEC_ONERRGOTO` must fit MAX_PATH
- [X] T014 [US3] Edit New "Save as default" in `src/dialogs3.cpp`: refuse when the name does not fit MAX_PATH, the default unchanged

## Phase 6: User Story 4 - browse buttons (P3)

Independent test: probe row `drv-browse`.

- [X] T015 [US4] Refuse instead of browsing from a cut path: `CCfgPageDrives` `IDB_BROWSECOMMAND` (`src/dialogs5.cpp`), `InvokeDirectoryMenuCommand` `DIRECTORY_COMMAND_BROWSE` (`src/salamdr3.cpp`), `CCompareArgsDlg` `IDB_UMC_BROWSENAME1/2` (`src/dialogs2.cpp`)

## Phase 7: Polish

- [X] T016 `python tools/check_encoding.py --strict` TOTAL 0; `.\build.cmd` BUILD SUCCEEDED; `saltests` 0 failed
- [X] T017 Probe after into `specs/251-dialog-text-fits/probe/result_after.txt` (every row PASS); before once more from the final probe file; 214's `cm_text_probe.ps1` into `specs/251-dialog-text-fits/probe/regress_214.txt`
- [ ] T018 `specs/251-dialog-text-fits/fix-log.md`: work, measurements after, review

## Dependencies

Phase 2 (T002 -> T003, T002 -> T004 -> T005) blocks Phases 3-6; the story phases are independent
of each other; Phase 7 last. MVP: Phase 3 (Make File List, the file-writing case).
