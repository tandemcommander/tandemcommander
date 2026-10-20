# Tasks: Archives - F3 / F4 of long member names, the gzip name read whole

**Input**: `specs/260-archive-cache-long-names/` (plan.md, spec.md, research.md, contracts/, quickstart.md)
**Tests**: saltests (FR-008) and the hidden-desktop probe (SC-001..SC-004) are part of the feature.

## Phase 1: Setup

- [X] T001 Start `specs/260-archive-cache-long-names/fix-log.md` with the measurement of b8d1f7d0 (222 probe at HEAD, the gzip site by reading, the long-folder routes)
- [X] T002 Write the probe `specs/260-archive-cache-long-names/probe/cache260_probe.ps1` (rows VIEWLONG, EDITLONG, OVERLIMIT, CTL, GZLONG, GZOVER, GZCTL; registry backup/restore; fixture under %TEMP%\tc260) in the style of `specs/241-pack-long-nested-folder/probe/pack241_probe.ps1`
- [X] T003 Run the probe on the build before the change (label `before`) -> `specs/260-archive-cache-long-names/probe/result_before.txt`; expected FAIL in VIEWLONG, EDITLONG, GZLONG, GZOVER (negative control)

## Phase 2: Foundational

- [X] T004 Create `src/common/salcachename.h` with `SalCacheTmpPathFitsU8(folder, name, longTmpPath)` (legacy: bytes + 1 <= MAX_PATH; long: UTF-16 units <= MAX_PATH - 1) per `contracts/cache-tmp-path.md`
- [X] T005 Add `TestCacheTmpPath260` to `src/saltests/saltests.cpp` (include, call): short, 274-byte CJK name fits long / not legacy, 259 / 260 unit boundary, emoji as 2 units, legacy byte boundary

## Phase 3: User Story 1 - F3 / F4 of a long member name (P1)

**Goal**: the core's F3 / F4 of archive members take temporary paths up to 259 UTF-16 units.
**Independent test**: probe rows VIEWLONG, EDITLONG, OVERLIMIT, CTL.

- [X] T006 [US1] `src/cache.h` / `src/cache.cpp`: trailing `BOOL longTmpPath = FALSE` on `CDiskCache::GetName`, passed to `CCacheDirData::ContainTmpName` and `CCacheDirData::GetName`; both build the full path on the heap and decide with `SalCacheTmpPathFitsU8`
- [X] T007 [US1] `src/fileswn5.cpp` (F3 of an archive member): pass `TRUE`
- [X] T008 [US1] `src/fileswn6.cpp` (F4 of an archive member): pass `TRUE`
- [X] T009 [US1] `src/salamdr3.cpp` `CFileTimeStamps::CheckAndPackAndClear`: the copy's path on the heap (no `_TRUNCATE` cut)
- [X] T010 [US1] `src/salamdr3.cpp` `CFileTimeStamps::CopyFilesTo`: source / target paths on the heap; "too long name" when a wide path would exceed MAX_PATH - 1 units (the shell's limit), never a cut

## Phase 4: User Story 2 - gzip stored name (P2)

**Goal**: the gzip name is read whole; over 255 UTF-16 units it is refused.
**Independent test**: probe rows GZLONG, GZOVER, GZCTL.

- [X] T011 [P] [US2] `src/plugins/tar/gzip/gunzip.cpp`: ORIG_NAME into a growing heap buffer bounded at 64 KiB (beyond: skipped, too-long flag), the '/' and ':' handling kept
- [X] T012 [US2] `src/plugins/tar/fileio.h` / `fileio.cpp`: the too-long flag (`SetOldNameTooLong` / `IsOldNameTooLong`), `SetOldName` takes `const char*`
- [X] T013 [US2] `src/plugins/tar/untar.cpp` `CArchive::GetStreamHeader`: refuse a too-long flag or a decoded name with `SalNameTooLongForFileSystemU8` (include `../../common/salmaskname.h`) with `GetErrorText(ERROR_FILENAME_EXCED_RANGE)`, title IDS_GZERR_TITLE

## Phase 5: Polish & verification

- [X] T014 `python tools/check_encoding.py --strict` -> TOTAL: 0
- [X] T015 `.\build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed
- [X] T016 Probe after (label `after`) -> `probe/result_after.txt`, all PASS; regression `specs/222-name-length-units/probe/editname222_probe.ps1` -> `probe/regress_222.txt`
- [X] T017 Record before / after, commands and results in `fix-log.md`
- [X] T018 clang-format the changed sources (`src/cache.cpp`, `src/cache.h`, `src/fileswn5.cpp`, `src/fileswn6.cpp`, `src/salamdr3.cpp`, `src/common/salcachename.h`, `src/saltests/saltests.cpp`, the tar files) - only the changed lines
- [X] T019 `CHANGELOG.md`: an entry under the `— unreleased` heading (feature 260; FR-003 packing is proven by EDITLONG, no code task)

## Dependencies

T001-T003 before code (T003 needs the probe and the old build). T004 -> T005, T006. T006 -> T007, T008.
US2 (T011-T013) independent of US1. T014-T017 after all.

## Parallel

T011 (tar) can go alongside T006-T010 (core). T004/T005 before the core work.

## Implementation strategy

MVP = US1 (the measured refusal). US2 next; both verified by one probe run.
