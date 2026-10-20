# Tasks: case twins are addressed exactly (261)

**Input**: `specs/261-case-twins-exact-match/` (spec.md, plan.md, research.md, contracts/name-rules.md)
**Tests**: requested by the project's method - `saltests` checks of the pure rules and the probe.

## Phase 1: Setup

- [ ] T001 Start `specs/261-case-twins-exact-match/fix-log.md` with the before measurement (`probe/result_before.txt`: 5 FAIL) and the reachability findings (folder sizes unreachable)

## Phase 2: Foundational (the rules)

- [ ] T002 Add `SalNamePickIndex`, `SalHasCaseTwinInRun`, `SalTwinAwarePairCmp` with a feature-261 comment block to `src/common/salnamerun.h` (contract `contracts/name-rules.md`)
- [ ] T003 Add `TestNameRules261` (pick: exact / single CI / two CI / none / WTF-8; twin in run; pair cmp; a merge simulation of CMPTWIN1, CMPTWINR, CMPSINGLE, CMPSUB on sorted string lists) and call it in `src/saltests/saltests.cpp`

## Phase 3: User Story 1 - Compare Directories pairs the exact twin (P1)

**Independent test**: probe rows CMPTWIN1, CMPTWIN2, CMPTWINR, CMPSUB, CMPSINGLE.

- [ ] T004 [US1] Add a static pair comparison (first key `RegSetStrICmpEx`, twin detection on both lists, `SalTwinAwarePairCmp`) in `src/mainwnd5.cpp` and use it in the panel merge of files and of directories
- [ ] T005 [US1] Use the same comparison in the sub-folder check (files and directories loops of `ReadDirsAndFilesAux`'s caller) in `src/mainwnd5.cpp`

## Phase 4: User Story 2 - viewer next / previous (P2)

**Independent test**: probe rows VIEWNEXT, VIEWPREV.

- [ ] T006 [US2] In WM_USER_ENUMFILENAMES of `src/fileswnb.cpp`: the name at the remembered index counts only when byte-identical; otherwise `SalNamePickIndex` over `Files`

## Phase 5: User Story 3 - User Menu compare names and Ctrl+X (P3)

**Independent test**: `saltests` (the pick rule); person step for the GUI.

- [ ] T007 [P] [US3] User Menu compare name 2: `SalNamePickIndex` over the other panel's dirs + files, then the files / dirs kind check, in `src/mainwnd3.cpp`
- [ ] T008 [P] [US3] Ctrl+X ghosting in the other panel: `SalNamePickIndex` over its `Dirs` / `Files` in `src/shellsup.cpp`

## Phase 6: Polish & verification

- [ ] T009 `python tools/check_encoding.py --strict` -> TOTAL: 0; `.\build.cmd` -> BUILD SUCCEEDED; `saltests` -> 0 failed
- [ ] T010 Probe `probe/twin261_probe.ps1` after -> 0 FAIL (`probe/result_after.txt`); regression `cmp232_probe.ps1` -> 16 / 0 (`probe/result_cmp232.txt`)
- [ ] T011 Negative control: the probe or saltests against a deliberately broken rule fails; record in `fix-log.md`
- [ ] T012 Record after-measurements, checks and the person step (User Menu, Ctrl+X) in `specs/261-case-twins-exact-match/fix-log.md`

## Dependencies

T001 -> T002 -> T003; T002 -> T004..T008 (T004 -> T005; T006, T007, T008 independent); all -> T009 -> T010 -> T011 -> T012.

## Parallel examples

T007 and T008 touch different files and can be done together after T002.

## Implementation strategy

MVP = Phase 3 (Compare Directories, the item's named Expected); then US2, US3; verify once at the end.
