# Tasks: a pending edit is never packed into the archive a re-pointed name leads to

## Phase 1: Measurement

- [x] T001 109 probe: op `replace`, cases `resubst-pending`, `replace-pending` (`specs/109-disk-cache-archive-key/probe/diskcache_probe.ps1`)
- [x] T002 Run on the build before; keep `specs/145-pending-edits-repointed/probe/result_pre145.txt`

## Phase 2: User Stories 1 + 2 (P1)

- [x] T003 [US1] `src/common/salfileio.h/.cpp`: `SalGetFinalPathOfHandleU8Alloc`, `SalGetFinalPathU8Alloc` uses it
- [x] T004 [US1] `src/fileswnd.h`, `src/fileswn1.cpp`: `ZIPArchiveFinalPath`, `TakeZIPArchiveFinalPath`, `ArchiveNameLeadsElsewhere`; forgotten in `SetZIPArchive`
- [x] T005 [US1] `src/fileswn2.cpp`: the open takes the final path from its handle; the refresh's change test
- [x] T006 [US1] `src/salamdr3.cpp` `CheckAndPackAndClear`: refuse before `PackCompress`
- [x] T007 Build, `saltests`, `check_encoding.py`; the two cases on the build (`probe/result_cases.txt`)
- [x] T008 [US2] Whole 109 probe, 108 (both), 112 on the build

## Phase 3: Polish

- [x] T009 Refute-first review; fix findings
- [x] T010 Records (fix-log, FEATURE-HISTORY, NEXT-WORK A.2a, CHANGELOG 0.1.11); commit
