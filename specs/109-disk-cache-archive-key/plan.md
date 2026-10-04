# Implementation Plan: an archive's temporary copies belong to that archive only (feature 109)

**Branch**: `109-disk-cache-archive-key` (from `108-archive-edit-name-collision`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S0 measure | every builder and comparer of a disk-cache key (`research.md` 0); `probe/diskcache_probe.ps1` on `Debug_x64_pre109`: two archives whose names fold together (F4, F3, F4+F3; ZIP, 7z), one archive through two spellings (ASCII case, accented case, 8.3, SUBST, `\\localhost\C$`), the prefix flush, a changed archive shown in both panels (`stale-*`), ordinary reuse |
| S1 rule | `salunicode.{h,cpp}`: `SalNameIdentityKeyAlloc` (key equality = `SalNameEqualOrdinalCI`), `SalNameIdentityFoldUnit` (ntdll `RtlUpcaseUnicodeChar`, the table `CompareStringOrdinal` uses); `salsamefile.h`: `SalArchiveSharesCacheKey`; `salheapstr.h`: `Adopt`, `Swap` |
| S2 core | `fileswnd.h` / `fileswn1.cpp`: `ZIPArchiveCacheKey`, `GetArchiveCacheKey`, `TakeArchiveCacheKey`, `SetZIPArchive` forgets the key; `fileswn2.cpp`: `SetArchiveCacheKey109` (own key, the other panel's for the same file, or a unique key when an equal key names another file - `SalArchiveCacheKeyChoice`), `PrepareCloseCurrentPath` (same-archive test by key - and only while the archive on disk keeps the size and time the other panel listed; flush key + `\`); `fileswn5.cpp` (F3) / `fileswn6.cpp` (F4): the key + the offset of the name inside the archive by the key's length; `fileswn9.cpp`: flush key + `\`; `cache.h`: the dead `NameEqual` removed |
| S3 tests | saltests `TestDiskCacheKey109`: the fold proven against `CompareStringOrdinal` over all units, key tables, random strings, every pair the old key merged, legacy tier, flush prefix, `SalArchiveSharesCacheKey` table and real files (case, 8.3, `\\localhost\C$`) |
| S4 probe | `diskcache_probe.ps1` new vs pre-109; regressions 108 namecoll, 096 archedit, 097 arcwork subset, 095 longarc (`probe/regress_*_109.txt`); full Release build; records |

Not touched (recorded): `cache.cpp` (keys compared byte for byte - the plug-ins' contract), the
plug-in-facing cache services, `CCacheDirData::DetachTmpFile` (no caller).

Pre-change build: `build\tandemcommander\Debug_x64_pre109`.
