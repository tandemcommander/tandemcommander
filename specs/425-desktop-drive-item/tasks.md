# Tasks: A real Desktop drive item; Shell Folders named for what they are

**Input**: `specs/425-desktop-drive-item/` (plan.md, spec.md, research.md, data-model.md, contracts/probe-seams.md)
**Tests**: requested by the spec (FR-009: a hidden-desktop probe) and the project rules (pure rules in `saltests`).

## Phase 1: Setup

- [X] T001 Start `specs/425-desktop-drive-item/fix-log.md` with the measurement of step 3 (probe `result_before.txt`, 2 PASS / 8 FAIL / 3 NOT DRIVEN at 472d20a8)

## Phase 2: Foundational

- [X] T002 Write the pure rules `SalDesktopPathToU8`, `SalDesktopFolderUsable`, `SalShellFolderOpensAsDisk` in `src/common/saldesktop.h` (header-only, no `windows.h` dependency beyond the types)
- [X] T003 Add `TestDesktopDrive425` to `src/saltests/saltests.cpp` (whole / none / too long / exact fit / lone surrogate; usable = directory only, invalid attributes refused; opens-as-disk truth table: zip and link file paths, no path, virtual folder) and register it

## Phase 3: User Story 1 - Desktop opens the Desktop folder (P1)

**Independent test**: probe rows MENU-DESKTOP, BAR-DESKTOP, SAVED, OPT-OFF, REGRESS, OPEN-MENU, OPEN-BAR, ERR-NONE, ERR-MISSING.

- [X] T004 [US1] Append `drvtDesktop` after `drvtWSLMenu` in `src/drivelst.h`
- [X] T005 [US1] Add `ChangeDriveShowDesktop` to `src/cfgdlg.h`, default TRUE in `src/dialogs4.cpp`, save / load `Change Drive Show Desktop` in `src/mainwnd2.cpp`
- [X] T006 [US1] Add `IDS_DESKTOPDRIVE` (14163, "Desktop") and `IDS_DESKTOPNOTFOUND` (14164) to `src/texts.rh2` and `src/lang/texts.rc2`
- [X] T007 [US1] Add `IDC_CHD_SHOWDESKTOP` (6305) "Des&ktop" after Documents on `IDD_CFGPAGE_CHANGEDRIVE` in `src/lang/lang.rc` / `src/lang/lang.rh` (controls below 13 DLU down) and transfer it in `src/dialogs5.cpp`
- [X] T008 [US1] Add `SAL_ICONSET_NAME_DESKTOP` ("OpenDesktop") to `src/common/saliconset.h`
- [X] T009 [US1] Build the item after Documents, include it on the drive bar (icon only), tooltip, no context menu in `src/drivelst.cpp`
- [X] T010 [US1] `GetDesktopPathU8` with the Debug seam `TC_PROBE_DESKTOP_FILE` in `src/shellib.cpp` (declared in `src/consts.h`)
- [X] T011 [US1] `CFilesWindow::ChangePathToDesktop` in `src/fileswn3.cpp` / `src/fileswnd.h` (message + no change when there is no usable folder, `IDS_TOOLONGPATH` when it does not fit) and the `drvtDesktop` cases of `CFilesWindow::ChangeDrive` and `CDriveBar::Execute` in `src/toolbar6.cpp`

## Phase 4: User Story 2 - Shell Folders entry (P2)

**Independent test**: probe row MENU-PLUGIN.

- [X] T012 [US2] `IDS_DRIVEMENUTEXT` = "-\tShell Folders" in `src/plugins/folders/lang/lang.rc2`

## Phase 5: User Story 3 - A real folder inside fld: opens as a disk path (P2)

**Independent test**: probe rows FLD-CPL, FLD-USER, FLD-DOCS, FLD-DRIVE, FLD-ZIP.

- [X] T013 [US3] Debug seam `TC_PROBE_FLD_DUMP` (LIST line) in `src/plugins/folders/fs2.cpp` and (EXEC line, `.pick` gate, files never run) in `src/plugins/folders/fs1.cpp`; build and run the probe as the negative control (fld: rows FAIL for disk items, PASS for Control Panel)
- [X] T014 [US3] In `CPluginInterfaceForFS::ExecuteOnFS` (`src/plugins/folders/fs1.cpp`): a file-system folder whose path is an existing directory opens through `ChangePanelPathToDisk`; everything else as today

## Phase 6: Polish & cross-cutting

- [X] T015 Manual: `help/src/hh/salamand/configuration_chdrv.htm`, `navigating_chdrvmenu.htm`, `windows_drivebar.htm` (the Desktop item, its check box, Shell Folders)
- [X] T016 Two-stage `.slt` refresh for the modules `salamand` and `folders` (stop-rules §2.13), pins where DeepL drifts, `slt --verify`
- [X] T017 `python tools/check_encoding.py --strict`, `python tools/brand/fluent-icons/check_iconset.py`, `build.cmd full`, `saltests`
- [X] T018 Probe `desktop_probe.ps1` after the fix -> `probe/result_after.txt`; record before / after in `fix-log.md`
- [X] T019 `CHANGELOG.md` entry under `## [Unreleased]`, FEATURE-HISTORY entry, closing report (run step 8)

## Dependencies

T002-T003 before T010-T014 (the rules are used there). US1 (T004-T011), US2 (T012) and US3 (T013-T014) are independent of each other; T016 after T006/T007/T012; T018 after all.

## Parallel examples

T006, T007, T008 touch different files ([P] in spirit); T012 is independent of US1.

## Implementation strategy

MVP = US1 (the item #31 asked for); US2 and US3 complete the maintainer's decision and ship in the same feature.
