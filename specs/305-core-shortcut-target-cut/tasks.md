# Tasks: The core never follows a shortcut to a cut target path

**Input**: `specs/305-core-shortcut-target-cut/` (plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md)
**Tests**: required by FR-005 (saltests checks of the pure rule, a fake link, end to end) and SC-001 / SC-002.

## Phase 1: Setup

- [ ] T001 Copy the measurement program to specs/305-core-shortcut-target-cut/probe/measure_core.cpp and record the measurement before (R1) in specs/305-core-shortcut-target-cut/fix-log.md

## Phase 2: Foundational

- [ ] T002 Add the pure functions `SalPlainPathAllocW(p)` and `SalShellLinkWholeTargetW(answer, listName)` (259-unit threshold, plain forms, equal / prefix → list name, else NULL) per data-model.md in src/common/salshelllink.h

## Phase 3: User Story 1 - a long target is never followed cut (P1)

**Goal**: every core reader of a shortcut target gets the whole target or a refusal; never 259 cut units.
**Independent test**: saltests end-to-end block on a volume without 8.3 names; the GUI probe.

- [ ] T003 [US1] `SalShellLinkGetPathU8`: for an answer of 259+ units - `SLGP_RAWPATH` → `HRESULT_FROM_WIN32(ERROR_FILENAME_EXCED_RANGE)`; otherwise read the item-list name (`GetIDList` + `SHGetNameFromIDList(SIGDN_FILESYSPATH)`), decide with `SalShellLinkWholeTargetW`, NULL → `ERROR_FILENAME_EXCED_RANGE`; convert the whole result to UTF-8 (does not fit → `E_FAIL`, as before); update the header comment in src/common/salshelllink.h
- [ ] T004 [US1] `SalFolderShortcutTargetU8`: a reader result of `ERROR_FILENAME_EXCED_RANGE` becomes its own `ERROR_FILENAME_EXCED_RANGE` (too long - refuse), other failures `S_FALSE` as before, in src/common/salshelllink.h
- [ ] T005 [US1] saltests `TestShellLinkWholeTarget305`: the pure rule - every row of data-model.md (short answer unchanged; 259 equal; `\\?\` / `\\?\UNC\` plain form; prefix → list name; case ignored; other name, shorter list name, UNC vs drive, NULL / "" list name → NULL; NULL / "" answer → NULL); `SalPlainPathAllocW` rows, in src/saltests/saltests.cpp
- [ ] T006 [US1] saltests: `SalShellLinkGetPathU8` with the fake link `CFakeLink304` - 259-unit answer without item list → `ERROR_FILENAME_EXCED_RANGE`, "" ; item list naming another folder → refused; `SLGP_RAWPATH` 259+ → refused without reading the item list; a short answer → as before, item list not read; S_FALSE / failure passed on, in src/saltests/saltests.cpp
- [ ] T007 [US1] saltests: end to end - plain `.lnk` and folder shortcuts whose item list names targets of 250 / 259 / 260 / 300 / 400 units in %TEMP% and next to saltests.exe; `SalShellLinkGetPathU8` (UNCPRIORITY) returns the target folder by identity, plain form, whole on a volume without 8.3 names; RAWPATH: whole under 259, refused for a cut; `SalFolderShortcutTargetU8` with `MAX_PATH` → whole or `ERROR_FILENAME_EXCED_RANGE`, with `SAL_MAX_PATH_UTF8` → whole; negative control printed (raw GetPath cut reproduced), in src/saltests/saltests.cpp
- [ ] T008 [US1] GUI probe: `probe/mklnk305.cpp` (writes a `.lnk` from an item list built folder by folder) and `probe/lnk305_probe.ps1` in the style of specs/181-shortcut-long-folder/probe/lnk_probe.ps1 (fixture `<build>\tc305`, registry backed up / restored / verified): rows ENTER-300 and FOCUS-300 (838) end in the whole 300-unit target; ENTER-250 control, in specs/305-core-shortcut-target-cut/probe/

## Phase 4: User Story 2 - everything else unchanged (P2)

**Independent test**: the existing checks of features 128 (`TestShellLink128`), 181, 194 and 286 pass unchanged.

- [ ] T009 [US2] Read the existing 128 / 286 checks against the new return codes (`FAILED` / `S_FALSE` / `tooLong`) and keep their meaning; record in specs/305-core-shortcut-target-cut/fix-log.md

## Phase 5: Polish

- [ ] T010 Encoding guard `python tools/check_encoding.py --strict` → TOTAL: 0
- [ ] T011 `.\build.cmd` → BUILD SUCCEEDED; saltests → 0 failed; negative control (the rule returning the answer as it is) → the 305 rows fail; restored
- [ ] T012 Repeat the measurement (`probe/measure_core.cpp` against the new header) on D: and C:; run the probe before (main build) and after; record in specs/305-core-shortcut-target-cut/fix-log.md
- [ ] T013 Record what is not driven (a drop onto the shortcut - real mouse; Browse For Folder on a network location - the dialog tree) in specs/305-core-shortcut-target-cut/fix-log.md

## Dependencies

T001 → T002 → T003 → T004; T005 after T002; T006 / T007 after T004; T008 after T003; T009 after T004; T010-T013 last.
Parallel: T005 with T003 / T004 (different files); T008's helper with T005-T007.

## Implementation strategy

MVP = Phase 1-3 (the defect); Phase 4 guards compatibility; Phase 5 verifies.
