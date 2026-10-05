# Tasks: feature 112

- [X] T001 Preserve the pre-change build (`Debug_x64_pre112`); `.specify/feature.json`
- [X] T002 Research (phase 0, `research.md`; addendum after implementation)
- [X] T003 Spec, plan, tasks, checklist; decisions in spec.md Clarifications
- [X] T004 [US1, US2] S1 rule `CSalCacheEditPin` (`src/common/salcacheedit.h`)
- [X] T005 [US1, US2] S2 cache: `crtCacheEdit`, `LockObjFlags`, `EditPin`, `Flush()`, deferred mark in `WaitSatisfied`, invariant guard in `GetName` (`cache.h`, `cache.cpp`)
- [X] T006 [US3] S3 `CFileTimeStampsAddResult`, `RemoveLastAdded` (`fileswnd.h`, `salamdr3.cpp`); `ExecuteFromArchive` tracks and locks before the launch (`fileswn6.cpp`)
- [X] T007 S4 saltests `TestCacheEdit112` (14,169 -> 14,236 / 0)
- [X] T008 S5 probe `probe/diskcache_edit_probe.ps1` written and parse-checked
- [X] T009 S5 probe on `Debug_x64_112` (14 / 0) and `Debug_x64_pre112` (4 PASS / 10 FAIL) - fix-log "GUI results"
- [X] T010 S6 regressions on `Debug_x64_112`: 109 diskcache 18/0, 108 namecoll 30/0, `-CacheKeyRows` 2/0, 096 archedit 17/17
- [X] T011 S6 gates: Debug + full Release build, saltests, strict encoding guard, encodings of touched sources
- [X] T012 Hostile re-read of the diff; records (fix-log, CHANGELOG, NEXT-WORK; the CLAUDE.md entry proposed in the fix-log); no commit
