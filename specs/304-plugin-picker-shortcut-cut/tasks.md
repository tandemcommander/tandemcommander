# Tasks: Plug-in folder picker never cuts a folder shortcut's target

**Input**: `specs/304-plugin-picker-shortcut-cut/` (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)
**Tests**: required by FR-004 (saltests checks of the pure rule) and SC-001 / SC-002 (end to end).

## Phase 1: Setup

- [X] T001 Record the measurement before (programs `probe/measure*.cpp`, results) in specs/304-plugin-picker-shortcut-cut/fix-log.md

## Phase 2: Foundational

- [X] T002 Add the pure rule `SplFileDlgDetail::WholeFolderShortcutTargetW(answer, listName)` (plain form, 259-unit threshold, equal / prefix → list name, else NULL) per data-model.md in src/plugins/shared/splfiledlg.h

## Phase 3: User Story 1 - a long target is never cut (P1)

**Goal**: the picker returns the whole target or refuses; never 259 cut units.
**Independent test**: saltests end-to-end block on a volume without 8.3 names.

- [X] T003 [US1] `ResolveNetHoodFolderW(path, BOOL* refused = NULL)`: read `GetPath` into a 32,768-unit heap buffer, for 259+ units read the item-list name (`GetIDList` + `SHGetNameFromIDList(SIGDN_FILESYSPATH)`), decide with `WholeFolderShortcutTargetW`, set `*refused` in src/plugins/shared/splfiledlg.h
- [X] T004 [US1] `SplBrowseForFolderU8`: a refused target shows `SplShowNameTooLongW` and picks nothing in src/plugins/shared/splfiledlg.h
- [X] T005 [US1] saltests: pure-rule checks for every row of data-model.md (short answer unchanged; 259 equal; `\\?\` / `\\?\UNC\` plain form; prefix → list name; mismatch, NULL list name, not-a-prefix → NULL; NULL / "" answer) in src/saltests/saltests.cpp
- [X] T006 [US1] saltests: end-to-end folder shortcuts whose item list names a 250 / 259 / 260 / 300 / 400-unit target, fixture in %TEMP% and, when %TEMP% has 8.3 names, next to saltests.exe; assert the result names the target folder by identity or the pick is refused - never a cut path; negative control: the raw `GetPath` answer is cut on a volume without 8.3 names (printed when reproduced) in src/saltests/saltests.cpp

## Phase 4: User Story 2 - everything else unchanged (P2)

**Independent test**: the existing 121 checks of `ResolveNetHoodFolderW` (no desktop.ini, no target.lnk, short target, trailing backslash, UNC, NULL / "") pass unchanged.

- [X] T007 [US2] Check the existing checks keep their meaning and add `refused == FALSE` assertions for the not-a-shortcut cases in src/saltests/saltests.cpp

## Phase 5: Polish

- [X] T008 Encoding guard `python tools/check_encoding.py --strict` → TOTAL: 0
- [X] T009 `.\build.cmd` → BUILD SUCCEEDED; saltests → 0 failed
- [X] T010 Repeat the measurement (`probe/measure3.cpp` against the new header) on D: and C:; record before / after in specs/304-plugin-picker-shortcut-cut/fix-log.md
- [X] T011 Record the person step (pick a network location with a long target in PictView / UnCAB / Undelete - real mouse, NOT DRIVEN) in specs/304-plugin-picker-shortcut-cut/fix-log.md

## Dependencies

T001 → T002 → T003 → T004; T005 after T002; T006 after T003; T007 after T003; T008-T011 last.
Parallel: T005 with T003/T004 (different files).

## Implementation strategy

MVP = Phase 1-3 (the defect); Phase 4 guards compatibility; Phase 5 verifies.
