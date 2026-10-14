# Tasks: an archive's copies are never another archive's across a re-pointed letter

## Phase 1: Setup / measurement

- [x] T001 Add case `resubst-both` to `specs/109-disk-cache-archive-key/probe/diskcache_probe.ps1`
- [x] T002 Run it on the build before (`Debug_x64` at `bce0812a`); keep `specs/144-archive-key-repointed-drive/probe/result_pre144.txt` (FAIL: B's member replaced)
- [x] T003 Start `specs/144-archive-key-repointed-drive/fix-log.md`

## Phase 2: User Story 1 + 2 (P1)

- [x] T004 [US1] `src/fileswnd.h`: `CSalFileIdentity ZIPArchiveIdentity`, `BOOL ZIPArchiveCacheKeyFailed`, accessors
- [x] T005 [US1] `src/fileswn1.cpp`: initialise both (constructor), forget both in `SetZIPArchive`; `GetArchiveCacheKey` returns FALSE after a failure
- [x] T006 [US1] `src/fileswn2.cpp` `SetArchiveCacheKey109`: read and store the own identity at every open; `theirs` = the other panel's stored identity; set the failure flag on both low-memory returns
- [x] T007 [US1] Build Debug, `saltests`, `check_encoding.py`
- [x] T008 [US1] 109 probe `-Only resubst-both,resubst` on the build
- [x] T009 [US2] Whole 109 probe; 108 `namecoll_probe.ps1 -CacheKeyRows`; 112 `diskcache_edit_probe.ps1`

## Phase 3: Polish

- [x] T010 Refute-first review (agent); fix findings
- [x] T011 Records: fix-log, `specs/FEATURE-HISTORY.md` `- 144-`, `specs/NEXT-WORK.md` A.2 + queue 108 entry 3, `CHANGELOG.md` 0.1.11
- [x] T012 Commit
