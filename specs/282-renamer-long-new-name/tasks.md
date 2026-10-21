# Tasks: The Renamer builds a new name of any length the file system accepts

**Input**: `specs/282-renamer-long-new-name/` (plan.md, spec.md, research.md, data-model.md, quickstart.md)
**Tests**: the GUI probe `probe/ren_longnew_probe.ps1` (written and run before the fix - 11 / 7).

## Phase 1: Setup

- [ ] T001 Confirm the before-run is recorded (`probe/result_before.txt`, 11 PASS / 7 FAIL) in specs/282-renamer-long-new-name/fix-log.md

## Phase 2: Foundational

- [ ] T002 Add `REN_MAX_NAME` (= `SAL_MAX_PATH_UTF8`) and widen `CSourceFile::NameLen` to 29 bits in src/plugins/renamer/crenamer.h
- [ ] T003 Give `CRenamer::Rename` a `newNameSize` parameter (declaration) in src/plugins/renamer/crenamer.h and `GetManualModeNewName` one in src/plugins/renamer/rendlg.h

## Phase 3: User Story 1 - A long item renamed to another long name (P1)

**Independent test**: probe rows long-new, long-undo, manual-long, long-rel, long-rel-deep PASS.

- [ ] T004 [US1] `CRenamer::Rename`: guard the folder part (`pathLen + 2 <= newNameSize`), replace every `MAX_PATH` cap by `newNameSize`, `tmp` on the heap freed on every return, in src/plugins/renamer/crenamer.cpp
- [ ] T005 [US1] `BuildScript`: `newName` = `malloc(REN_MAX_NAME)` (none → `Error(IDS_LOWMEM)`), passed with its size, freed at the end, in src/plugins/renamer/rendlg2.cpp
- [ ] T006 [US1] `GetManualModeNewName`: the size parameter, the folder-part guard, `GetEditLineU8(..., newNameSize - pathLen)` in src/plugins/renamer/rendlg2.cpp
- [ ] T007 [US1] Preview: `NewNameCache` on the heap (`REN_MAX_NAME`), `Rename` / the manual line with that size, a growing wide buffer for the list view texts, in src/plugins/renamer/preview.h and src/plugins/renamer/preview.cpp

## Phase 4: User Story 2 - Items from "Include subdirectories" follow the same limit (P1)

**Independent test**: probe rows sub-long-file, sub-long-dir PASS.

- [ ] T008 [US2] `ReloadSourceFiles`: `pathBuf` on the heap (`REN_MAX_NAME`, none → `Error(IDS_LOWMEM)` and an empty listing), `dirLen + 2 <= REN_MAX_NAME`, freed at the end, in src/plugins/renamer/rendlg.cpp
- [ ] T009 [US2] `LoadSubdir`: `SalPathAppend(..., REN_MAX_NAME)`, the find data and converted name on the heap, `item->NameLen < REN_MAX_NAME`, the depth guard (1024 levels → the existing too-long-path refusal), in src/plugins/renamer/rendlg.cpp and src/plugins/renamer/rendlg.h
- [ ] T010 [US2] Preview path column: the folder whole through a growing buffer (no `lstrcpyn` cut), in src/plugins/renamer/preview.h and src/plugins/renamer/preview.cpp

## Phase 5: User Story 3 - Still refused, never cut (P2)

**Independent test**: probe rows over-comp, short-ctl PASS.

- [ ] T011 [US3] Check every refusal path of T004-T009 returns the existing error with nothing renamed (code reading, recorded in specs/282-renamer-long-new-name/fix-log.md)

## Phase 6: Polish

- [ ] T012 Encoding guard `python tools/check_encoding.py --strict` → TOTAL: 0; `.\build.cmd` → BUILD SUCCEEDED; `saltests` → 0 failed (record in specs/282-renamer-long-new-name/fix-log.md)
- [ ] T013 Run the probe after the fix → `probe/result_after.txt` 20 / 0 (specs/282-renamer-long-new-name/probe/)
- [ ] T014 Regression probes 199, 206, 207, 209 → `probe/regress_*.txt` all PASS (specs/282-renamer-long-new-name/probe/)
- [ ] T015 Record before / after and decisions in specs/282-renamer-long-new-name/fix-log.md

## Dependencies

T002-T003 before all; US1 (T004-T007) and US2 (T008-T010) touch different functions (T007 and T010 share preview files: sequential); US3 after US1 + US2; Polish last.

## Parallel opportunities

T004 (crenamer.cpp) and T008-T009 (rendlg.cpp) are independent files.

## Implementation strategy

MVP = US1 (the item's main defect); then US2; one build and probe run for all.
