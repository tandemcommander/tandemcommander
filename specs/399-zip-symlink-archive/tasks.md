# Tasks: ZIP updates an archive reached through a symbolic link

**Input**: `specs/399-zip-symlink-archive/` (plan.md, spec.md, research.md, data-model.md, quickstart.md)
**Tests**: required by the spec (FR-007 saltests; SC-001/002 probe).

## Phase 1: Setup

- [ ] T001 Record the before measurement (probe 14 PASS / 4 FAIL) and the consumers in specs/399-zip-symlink-archive/fix-log.md (done at start; check it is complete)

## Phase 2: Foundational (the shared rule)

- [ ] T002 Add `SalReplaceFollowsName(attrs, tag)` (pure), `SalFinalPathPlainW(final)` (pure, malloc'ed, NULL for a non-DOS/non-UNC form) and `SalReplaceTargetOfLinkW(name, h)` (FindFirstFileW tag + GetFinalPathNameByHandleW of the open handle; NULL when the name is not followed or cannot be resolved) to src/common/salsafereplace.h
- [ ] T003 Add `TestSafeReplace399` to src/saltests/saltests.cpp: pure rows (plain file, symlink tag, mount-point tag, a cloud / dedup tag, a directory, invalid attributes; `\\?\C:\a` -> `C:\a`, `\\?\UNC\s\sh\a` -> `\\s\sh\a`, `\\?\Volume{..}\a` -> NULL, `C:\a` -> NULL? no prefix -> as is); I/O rows: a real file link under %TEMP% (absolute and relative) -> the target's path; a plain file -> NULL; `SalReplaceWithTempW` onto the resolved path with a temporary file next to it -> the real file updated, the link still a link (skipped with a printed line when a link cannot be made); register it in main

## Phase 3: User Story 1 - add through a link (P1)

- [ ] T004 [US1] Add `char* ReplaceTarget` to `CZipPack` in src/plugins/zip/add_del.h; NULL in the constructor, freed in the destructor in src/plugins/zip/add_del.cpp
- [ ] T005 [US1] In `CZipPack::CreateTempFile` (src/plugins/zip/add.cpp): resolve once with `SalReplaceTargetOfLinkW(ZipName, ZipFile->File)`; when resolved and it fits U8_MAX_PATH, store `ReplaceTarget` (UTF-8 via SplWToU8Alloc), re-read `ZipAttr` from it (keep the old value when unreadable), and split the temporary file's folder from it instead of `ZipName`
- [ ] T006 [US1] In `CZipPack::ReplaceArchiveWithTemp` (src/plugins/zip/add.cpp): replace, set attributes and the newest time on `ReplaceTarget` when set (messages keep `ZipName`)

## Phase 4: User Story 2 - delete through a link (P1)

- [ ] T007 [US2] Check that `DeleteFromArchive` (src/plugins/zip/add_del.cpp) reaches the same `CreateTempFile` / `ReplaceArchiveWithTemp` with `ZipFile` open (no extra change expected); record in fix-log.md

## Phase 5: User Story 3 - a failed replace through a link (P2)

- [ ] T008 [US3] Confirm by the probe row add-symlink-locked that the 320 outcomes hold on the resolved target (message, nothing changed, nothing new)

## Phase 6: Polish

- [ ] T009 Build `.\build.cmd` -> BUILD SUCCEEDED; run saltests -> 0 failed
- [ ] T010 Run specs/399-zip-symlink-archive/probe/zipsymlink_probe.ps1 on the hidden desktop -> 18 PASS / 0 FAIL, save result_after.txt
- [ ] T011 `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s); clang-format the changed sources
- [ ] T012 Update specs/399-zip-symlink-archive/fix-log.md (after measurement, commands, results)

## Dependencies

T002 -> T003, T005; T004 -> T005 -> T006; T006 -> T007, T008; T009 -> T010; all -> T012.
Parallel: T003 with T004.

## Implementation Strategy

MVP = US1 (the same code serves US2 and US3); then the probe proves all three.
