# Implementation Plan: a flush of the disk cache never throws away a pending edit (feature 112)

**Branch**: `112-cache-pending-edit` (from `111-pictview-shown-image`) | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

| Stage | Content |
|---|---|
| S0 research | phase-0 research (`research.md` 1-5): every flush and what precedes it, the scenarios, designs (a)-(c), the probe design, queue entry 3 |
| S1 rule | `src/common/salcacheedit.h` (header-only, pure): `CSalCacheEditPin` (`EditLocks`, `StaleAfterEdit`; `OnFlush`, `OnEditLockAdded`, `OnLockRemoved`, `Normalize`), `CSalCacheFlushAction` |
| S2 cache | `cache.h`: `crtCacheEdit` (core only), `LockObjOwner` (BOOL) -> `LockObjFlags` (`CACHE_LOCK_OWNER`, `CACHE_LOCK_EDIT`), `CCacheData::EditPin`, `CCacheData::Flush()`; `cache.cpp`: `AssignName` counts the edit lock (a mark set between look-up and lock becomes the deferred one), `WaitSatisfied` sets the deferred mark when the last edit lock goes, `FlushCache` / `FlushOneFile` through `Flush()`, `GetName` guards the invariant (`Normalize`, TRACE_E) |
| S3 F4 | `fileswnd.h` / `salamdr3.cpp`: `CFileTimeStampsAddResult` (`ftsarAdded`, `ftsarAlreadyTracked`, `ftsarFailed`), `AddFile` forgets an archive name it set alone on failure, `RemoveLastAdded`; `fileswn6.cpp` `ExecuteFromArchive`: stamp + `AddFile` + `AssignName(..., crtCacheEdit)` before the launch under `BeginStopRefresh`; failure -> release, `IDS_PACKERR_NOMEM`, no launch |
| S4 tests | saltests `TestCacheEdit112`: the rule, the research scenarios old vs new, a record model driven through cache.cpp's steps (40,000 random sequences: parity without edit locks, invariant, no loss, deferred mark delivered; the old rule loses edits) |
| S5 probe | `probe/diskcache_edit_probe.ps1` (from 109's probe): rows with automatic refresh off (fixed drive) and through a `net use` drive with no refresh at all, controls with refresh on, L's refresh detected; run on this build and on `Debug_x64_pre112` - pending (GUI runs only after 18:00 / with no installed instance running) |
| S6 gates | Debug + full Release builds, saltests, strict guard, encodings; regressions 109 diskcache, 108 namecoll, 096 archedit (pending GUI) |

Not touched (recorded): plug-in cache services and their semantics; the own-delete queued-delete race
(S10); a per-member "changed in the archive meanwhile" warning (needs a string).

Pre-change build: `build\tandemcommander\Debug_x64_pre112` (HEAD `be6f6943`, incremental build had
nothing to do; copied without the `Intermediate` folders).
