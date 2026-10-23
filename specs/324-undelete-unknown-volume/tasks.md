# Tasks: Undelete warns when it cannot tell the restore target's volume

**Input**: Design documents from `specs/324-undelete-unknown-volume/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

Tests: the spec asks for `saltests` checks (FR-006, SC-003) - included.

## Phase 1: Setup

- [ ] T001 Start `specs/324-undelete-unknown-volume/fix-log.md` with the measurement of step 3 (commands, output of `probe/measure_volume.py`, the core's code trace)

## Phase 2: Foundational (the shared rule)

- [ ] T002 Create `src/common/salsamevolume.h` (header-only, wide API, on `salsamefile.h`): `SalVolumeSerialMatch`, `SalVolumeGuardSame`, `SalWPathRootLength`, `SalWPathCutLast`, `SalGetNearestVolumeIdentityW` (step up only on file / path not found), `SalVolumeGuardForPaths` (identity reads only when the core is unsure) - per data-model.md
- [ ] T003 Add `TestSameVolume324()` to `src/saltests/saltests.cpp`: the full decision table (12 rows), serial match (zero / attribute-only / 32-bit / 64-bit), root length and cut for `\\?\X:\`, `\\?\UNC\srv\share\`, `\\?\Volume{..}\`, `X:\`, relative; real-FS block under `%TEMP%`: junction `Zálohy` -> the volume root, junction -> a volume-GUID subfolder, missing targets below them, an access-free missing drive path - `SalVolumeGuardForPaths(target, root, FALSE, TRUE)` answers same, and the identity of a missing child equals its existing parent's
- [ ] T004 Register the call in `main()` of `src/saltests/saltests.cpp` and the include

## Phase 3: User Story 1 - the same-partition warning (P1)

**Goal**: the restore warning is shown when the target's volume cannot be told.
**Independent test**: T003's fixture rows; the elevated GUI run is a person step.

- [ ] T005 [US1] In `src/plugins/undelete/fs2.cpp` add `UndPathsMayShareVolume(path1, path2)`: the core's `PathsAreOnTheSameVolume` with the estimation flag, then `SalVolumeGuardForPaths` on `SplU8ToWExtAlloc` forms (a conversion failure = unknown = same)
- [ ] T006 [US1] Use it for the `IDS_SAMEPARTITION` test in `CPluginFSInterface::CopyOrMoveFromFS` (`src/plugins/undelete/fs2.cpp`)

## Phase 4: User Story 2 - the temporary folder of View (P2)

- [ ] T007 [US2] Use it for both tests in `CPluginFSInterface::GetTempDirOutsideRoot` (`src/plugins/undelete/fs2.cpp`), argument order as before

## Phase 5: Polish & verification

- [ ] T008 Encoding guard `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [ ] T009 `.\build.cmd` -> `BUILD SUCCEEDED`; `saltests.exe` -> `0 failed` (record numbers in `fix-log.md`)
- [ ] T010 Negative control: with `SalVolumeGuardSame` returning the core's answer alone, the 324 fixture rows of `saltests` fail (record, then restore)
- [ ] T011 Re-run `probe/measure_volume.py` (after) and record; record the GUI restore as NOT DRIVEN (elevation) in `fix-log.md`

## Dependencies

T001 -> T002 -> T003/T004 -> T005 -> T006, T007 -> T008..T011. US1 and US2 share T005 only.

## Parallel opportunities

T003 and T005 touch different files once T002 exists.

## Implementation strategy

MVP = US1 (T001-T006); US2 is one more call site of the same helper.
