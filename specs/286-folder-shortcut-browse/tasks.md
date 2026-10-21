# Tasks: A folder picked in Browse is handed back whole or refused - also a folder shortcut's target

**Input**: `specs/286-folder-shortcut-browse/` (spec.md, plan.md, research.md, data-model.md, contracts/, quickstart.md)
**Tests**: requested by the spec (FR-008, SC-001, SC-002): `saltests` checks and the hidden-desktop probe.

## Phase 1: Setup

- [ ] T001 Start the running log `specs/286-folder-shortcut-browse/fix-log.md` with the measurement before (probe `result_before.txt`: pick-long FAIL, pick-ctl PASS; folder-shortcut route not listed by the tree), the commands, the fixture-base deviation and the enumerated consumers (GetTargetDirectory callers, `SalSHGetPathFromIDListU8` users incl. `GetMyDocumentsOrDesktopPath`, the plug-in forwarder `CSalamanderGeneral::GetTargetDirectory`)

## Phase 2: Foundational

- [ ] T002 Add `SalIsFolderShortcutIni` and `SalFolderShortcutTargetU8` to `src/common/salshelllink.h` per `contracts/folder-shortcut-target.md` (heap names, wide `\\?\`-capable opens, target read whole into a `SAL_MAX_PATH_UTF8` heap buffer, `ERROR_FILENAME_EXCED_RANGE` when it does not fit `targetSize`)

## Phase 3: User Story 1 - a picked folder too long for the caller is refused (P1)

**Independent test**: probe rows `pick-long` (refused, field unchanged) and `pick-ctl` (whole).

- [ ] T003 [US1] `src/shellib.cpp` `SalSHGetPathFromIDListU8`: drop the code-page `SHGetPathFromIDList` fallback; add `BOOL* tooLong` (set when the wide path exists but its UTF-8 form does not fit); `u8Path` = "" on failure
- [ ] T004 [US1] `src/shellib.cpp` `DirectoryBrowse` (`BFFM_SELCHANGED`): enable OK for a file-system folder also when it is too long
- [ ] T005 [US1] `src/shellib.cpp` `GetTargetDirectoryAux`: decode into a local buffer, copy into `path` only on success; report `tooLong`; an item without a file-system path = FALSE
- [ ] T006 [US1] `src/shellib.cpp` `GetTargetDirectory`: on `tooLong` show `IDS_TOOLONGPATH` (`SalMessageBox`, `IDS_ERRORTITLE`) and return FALSE

## Phase 4: User Story 2 - a folder shortcut with a long target is refused (P1)

**Independent test**: `saltests` `TestFolderShortcut286` against real folder shortcuts.

- [ ] T007 [US2] `src/shellib.cpp` `ResolveNetHoodPath` returns BOOL and uses `SalFolderShortcutTargetU8(path, target, MAX_PATH)`: NOERROR -> copy, refusal -> FALSE (path unchanged), else keep the folder; declaration in `src/shellib.h`; `GetTargetDirectory` treats FALSE as "too long"
- [ ] T008 [P] [US2] `src/saltests/saltests.cpp` `TestFolderShortcut286`: pure `SalIsFolderShortcutIni` checks; real folder shortcuts in `%TEMP%` - short target, long CJK target (refused at `MAX_PATH`, whole with a large buffer), exact limit 259 / 260 bytes, a shortcut folder whose own path + `\target.lnk` exceeds `MAX_PATH` bytes, another class id, `{}`, no `desktop.ini`, no `target.lnk`; negative control: the old rule (`3 * MAX_PATH` buffer + `strlen < MAX_PATH`) drops the long target silently; register it in the test list

## Phase 5: Polish & verification

- [ ] T009 Update `specs/286-folder-shortcut-browse/probe/fsc286_probe.ps1`: the folder-shortcut route rows become INFO rows (the tree does not list a folder shortcut in an ordinary folder) - only `pick-*` rows give a verdict
- [ ] T010 Build `.\build.cmd`, run `saltests`, `python tools/check_encoding.py --strict`; record numbers in `fix-log.md`
- [ ] T011 Run the probe after the fix -> `specs/286-folder-shortcut-browse/probe/result_after.txt`; record before / after in `fix-log.md`
- [ ] T012 Record in `fix-log.md` what is owed to a person (network location with a long target, GUI) and the out-of-scope finding (plug-in twin `ResolveNetHoodFolderW` reads the target into `WCHAR[MAX_PATH]`) for an Inbox item

## Dependencies

T001 -> T002 -> (T003 -> T004 -> T005 -> T006) -> T007; T008 after T002 (parallel with T003-T007); T009 any time; T010 after T003-T008; T011 after T009, T010; T012 last.

## Implementation strategy

US1 and US2 share `GetTargetDirectory`; both are P1 and land together. MVP = T002-T008.
