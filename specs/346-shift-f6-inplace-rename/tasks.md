# Tasks: Shift+F6 renames the focused item in place

**Input**: `specs/346-shift-f6-inplace-rename/` (plan.md, spec.md, research.md, contracts/keyboard-and-menu.md)
**Tests**: `saltests` checks for the pure key rule (working method) and the hidden-desktop probe.

## Phase 1: Setup

- [ ] T001 Start `specs/346-shift-f6-inplace-rename/fix-log.md` with the before-measurement (probe `before`: 7 FAIL rows, commands) and copy the probe to `specs/346-shift-f6-inplace-rename/probe/rip346_probe.ps1` with its `before` result

## Phase 2: Foundational

- [ ] T002 Create the pure rule header `src/common/salrenamekey.h` (`SalIsRenameInPlaceKey(vk, ctrl, shift, alt)`, `SalIsRenameInPlaceHotKey(WORD hotKey)`)
- [ ] T003 Add `saltests` checks for both functions in `src/saltests/saltests.cpp` (Shift+F6 yes; F6, Ctrl+F6, Alt+F6, Ctrl+Shift+F6, Alt+Shift+F6, Shift+F5, Shift+F7 no)
- [ ] T004 Add `CM_QUICKRENAMEINPLACE 2954` to `src/resource.rh2`

## Phase 3: User Story 1 - Rename in place from the keyboard (P1)

**Goal**: Shift+F6 opens the in-place editor on the focused item. **Independent test**: probe rows S6-FILE, S6-ESC, S6-ENTER, S6-FOCUS, S6-DIR, S6-UTF8.

- [ ] T005 [US1] Revive `QuickRenameOnIndex(int index)` in `src/fileswn5.cpp` (caret + visible, label rect via `GetItemRect` + `GetIndex`, `QuickRenameIndex`/`QuickRenameRect`, `QuickRenameBegin`) and its declaration in `src/fileswnd.h`
- [ ] T006 [US1] Handle `CM_QUICKRENAMEINPLACE` in `src/mainwnd3.cpp` next to `CM_RENAMEFILE` (calls `activePanel->QuickRenameOnIndex(activePanel->GetCaretIndex())`)
- [ ] T007 [US1] In `CFilesWindow::OnSysKeyDown` (`src/fileswn0.cpp`), after `Plugins.HandleKeyDown`, post `CM_QUICKRENAMEINPLACE` when `SalIsRenameInPlaceKey` holds

## Phase 4: User Story 2 - Nothing where it is not possible (P2)

**Independent test**: probe rows S6-UPDIR, ARCHIVE.

- [ ] T008 [US2] Confirm `QuickRenameOnIndex` / `QuickRenameBegin` return without an editor for `..`, an empty panel, an archive and an FS without `FS_SERVICE_QUICKRENAME`, and when the editor is already open (`src/fileswn5.cpp`)

## Phase 5: User Story 3 - Keys kept, shortcut discoverable (P2)

**Independent test**: probe rows CS6, KEEPS, MENU, F2; menu and help read.

- [ ] T009 [US3] `IsSalHotKey`: Shift+F6 reserved; `IsSalHotKeyKeptAtLoad`: Shift+F6 kept (`src/keyboard.cpp`, using `SalIsRenameInPlaceHotKey`)
- [ ] T010 [US3] Add `IDS_MENU_FILES_RENAMEINPLACE 13019` to `src/texts.rh2` and `"Rename in Place\tShift+F6"` to `src/lang/texts.rc2`
- [ ] T011 [US3] Add the Files menu row after `IDS_MENU_FILES_RENAME` in `src/menu4.cpp` (`CM_QUICKRENAMEINPLACE`, `MNTS_B | MNTS_I | MNTS_A`, `&EnablerQuickRename`)
- [ ] T012 [P] [US3] List Shift+F6 in `help/src/hh/salamand/shortcuts_keyboard.htm` and in `help/src/hh/salamand/advwork_rename.htm`

## Phase 6: Polish

- [ ] T013 Build (`.\build.cmd`), saltests, encoding guard (`python tools/check_encoding.py --strict`)
- [ ] T014 Run the probe `after` on the hidden desktop; record in `fix-log.md`; investigate the Ctrl+Shift+F6 timeout seen in the before run
- [ ] T015 Two-stage `.slt` refresh of module `salamand` (stop-rules §2.13), then `.\build.cmd full`
- [ ] T016 `CHANGELOG.md` entry under `## [Unreleased]`

## Dependencies

T002 → T003, T007, T009; T004 → T006, T007, T011; T005 → T006; T010 → T011 → T015; all → T013 → T014.
Parallel: T012 with any code task; T002/T004/T010 together.

## Implementation strategy

MVP = Phase 3 (US1); US2 is mostly verification of existing guards; US3 adds the menu, help and
hot-key reservation.
