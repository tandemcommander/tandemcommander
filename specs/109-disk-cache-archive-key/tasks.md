# Tasks: feature 109

- [X] T001 Preserve the pre-change build (`Debug_x64_pre109`); `.specify/feature.json`
- [X] T002 Research: every builder / comparer / flush of a disk-cache key, the plug-in-facing cache services and their contract, persistence (`research.md`)
- [X] T003 Measurement probe `probe/diskcache_probe.ps1` on `Debug_x64_pre109` (`probe/diskcache_result_pre109.txt`)
- [X] T004 Spec, plan, tasks, checklist; decisions in spec.md Clarifications
- [X] T005 [US1-US3] S1 key rule `SalNameIdentityKeyAlloc` / `SalNameIdentityFoldUnit` (`salunicode.{h,cpp}`); `CSalHeapString::Adopt` / `Swap`
- [X] T006 [US4] S1 `SalArchiveSharesCacheKey` (`salsamefile.h`)
- [X] T007 [US1-US4] S2 core: the stored key (`fileswnd.h`, `fileswn1.cpp`, `fileswn2.cpp` `SetArchiveCacheKey109`), both builders (`fileswn5.cpp`, `fileswn6.cpp`), both flushes + the same-archive test (`fileswn2.cpp`, `fileswn9.cpp`); `cache.h` dead `NameEqual` removed
- [X] T008 S3 saltests `TestDiskCacheKey109`
- [X] T009 S4 probe on this build and on `Debug_x64_pre109`
- [X] T009a [US5] Rows `stale-same` / `stale-subst`: the stale copies of a changed archive (pre-existing for one path, spread by the first version to the SUBST pair); the freshness test in `PrepareCloseCurrentPath`
- [X] T013 Independent review (REJECT): blocker - an equal key trusted without identity (`resubst`): `SalArchiveCacheKeyChoice` + unique keys; should-fix - the freshness test compared with the refresh marker: compared with the other panel's listing; nit - `OfferArchiveUpdateIfNeeded` by name OR key; probe rows `resubst`, `renet` on both builds; saltests, gates, regressions again
- [X] T010 Regression: 108 namecoll, 096 archedit, 097 arcwork subset, 095 longarc (`probe/regress_*_109.txt`)
- [X] T011 Gates: Debug + full Release build, saltests, strict encoding guard, encodings of touched sources
- [X] T012 Hostile re-read of the diff; records (fix-log, CHANGELOG, NEXT-WORK; the CLAUDE.md entry proposed in the fix-log); no commit (the maintainer commits after an independent review)
