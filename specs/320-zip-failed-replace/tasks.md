# Tasks: ZIP leaves the archive and no stray file after a failed replace

**Input**: `specs/320-zip-failed-replace/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: requested by the spec (SC-001..SC-003): saltests checks and the hidden-desktop probe.

## Phase 1: Setup

- [ ] T001 Record the measurement at 4252bcb6 and the decisions in specs/320-zip-failed-replace/fix-log.md (probe/result_before.txt kept)

## Phase 2: Foundational (blocks US1 and US2)

- [ ] T002 Declare `int ReplaceArchiveWithTemp();` in `CZipPack` in src/plugins/zip/add_del.h and implement it in src/plugins/zip/add.cpp: wide names with `SplU8ToWExtAlloc`, `SalReplaceWithTempW(wZip, wTemp, TRUE, TRUE, &err)` (include `../../common/salsafereplace.h`), results mapped per research.md R2 (done: `SetFileAttributesU8(ZipName, ZipAttr | FILE_ATTRIBUTE_ARCHIVE)`, return 0; kept: `DeleteFileU8(TempName)`, return `IDS_ERRRESTORE`; left at temp: `ProcessError(IDS_ERRCREATE, err, ZipName, PE_NORETRY | PE_NOSKIP, NULL, TempName)`, return `IDS_NODISPLAY`; both gone: `ProcessError(IDS_ERRACCESS, err, ZipName, PE_NORETRY | PE_NOSKIP, NULL)`, return `IDS_NODISPLAY`; no memory: delete the temporary file, `IDS_LOWMEM`)

## Phase 3: User Story 1 - adding to a held archive (P1)

**Independent test**: probe rows add-locked, add-ctl, add-sharedel.

- [ ] T003 [US1] In `CZipPack::PackNormal` (src/plugins/zip/add.cpp) replace `ClearReadOnlyAttr` + `DeleteFileU8` + `MoveFileU8` + `SetFileAttributesU8` with `ErrorID = ReplaceArchiveWithTemp();`

## Phase 4: User Story 2 - deleting from a held archive (P1)

**Independent test**: probe rows del-locked, del-ctl, del-sharedel.

- [ ] T004 [US2] In `CZipPack::DeleteFromArchive` (src/plugins/zip/add_del.cpp) the same replacement as T003

## Phase 5: User Story 3 - never deleted first (P2)

**Independent test**: saltests TestSafeReplace320.

- [ ] T005 [P] [US3] Add `TestSafeReplace320` to src/saltests/saltests.cpp (after TestSafeReplace105, called after it): a stream target `host:zip.zip` -> srrFailedKept, the stream and the host unchanged, the temporary file kept for the caller; a target held with sharing read + write -> srrFailedKept / 32, unchanged; held with read + write + delete -> srrDone; the replacement's last-write time kept and the target's named stream kept after srrDone

## Phase 6: Polish

- [ ] T006 Build (`.\build.cmd`), saltests (0 failed), negative control of the saltests checks, encoding guard; record in fix-log.md
- [ ] T007 Probe after the change: specs/320-zip-failed-replace/probe/result_after.txt (all rows PASS, registry identical); negative control: the probe on the before build already FAILs add-locked / del-locked (result_before.txt)
- [ ] T008 clang-format the changed lines of src/plugins/zip/add.cpp, add_del.cpp, add_del.h, src/saltests/saltests.cpp

## Dependencies

T001 -> T002 -> T003, T004 (same member; different files); T005 independent of T002-T004; T006-T008 last.
MVP: T002 + T003 (US1).
