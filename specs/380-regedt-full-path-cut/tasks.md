# Tasks: Registry Editor - a too long full key path is refused, never cut

**Input**: `specs/380-regedt-full-path-cut/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: the hidden-desktop probe `probe/regpath380_probe.ps1` (the item asks for it).

## Phase 1: Setup

- [ ] T001 Start `specs/380-regedt-full-path-cut/fix-log.md` with the step-3 measurements (ctypes, probe `result_before.txt`) and the inventory of research R5

## Phase 2: Foundational

(none - no shared code changes; `src/plugins/regedt/utils.h` stays as it is)

## Phase 3: User Story 1 - a typed relative path never lands in another key (P1) MVP

**Goal**: FR-001, FR-002. **Independent test**: probe rows LONG and CJK PASS, SHORT PASS.

- [ ] T002 [US1] In `src/plugins/regedt/fs2.cpp` `CPluginFSInterface::GetFullFSPath`: a failed `U8ToWStr` of the typed path sets `success = FALSE` after `Error(IDS_LONGNAME)`; the final `WStrToU8` into `path + l` is tested for `== 0` → `Error(IDS_LONGNAME)`, `success = FALSE` (never `>= 0`)
- [ ] T003 [US1] Build (`.\build.cmd`) and run the probe on the hidden desktop into `specs/380-regedt-full-path-cut/probe/result_after.txt` (quickstart step 3); record in `fix-log.md`

## Phase 4: User Story 2 - a rename never focuses a cut name (P2)

**Goal**: FR-003. **Independent test**: reading; every conversion result tested, failure → empty name.

- [ ] T004 [P] [US2] In `src/plugins/regedt/fs3.cpp` `CPluginFSInterface::QuickRename`: `WStrToU8(newName, MAX_PATH, keyName)` result `== 0` → `newName[0] = 0`
- [ ] T005 [P] [US2] In `src/plugins/regedt/fs5.cpp` (rename by Move, `nextFocus`): `WStrToU8(nextFocus, 2 * MAX_PATH, targetName)` result `== 0` → `nextFocus[0] = 0`

## Phase 5: User Story 3 - Find's Focus never sends a cut path (P3)

**Goal**: FR-004. **Independent test**: reading.

- [ ] T006 [P] [US3] In `src/plugins/regedt/finddlg2.cpp` (`CMD_FINDFOCUS`): test both `WStrToU8` results; on `== 0` show `Error(IDS_LONGNAME)` and do not call `PostFocusCommand`

## Phase 6: Polish

- [ ] T007 `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`; `.\build.cmd` → `BUILD SUCCEEDED` after all edits
- [ ] T008 Re-run `grep -n "WStrToU8" src/plugins/regedt/*.cpp` and confirm SC-002 in `fix-log.md`
- [ ] T009 Final probe run after all edits (`result_after.txt`), registry restored identical; `fix-log.md` before / after

## Dependencies

T001 → T002 → T003; T004-T006 independent of each other and of T002 (different files); T007-T009 after all.

## Implementation strategy

MVP = US1 (T002-T003); US2 and US3 are small guards of the same kind.
