# Fix log: feature 112 - a flush of the disk cache never throws away a pending edit

Branch `112-cache-pending-edit` (from `111-pictview-shown-image`, HEAD `be6f6943`). Pre-change build
preserved as `build\tandemcommander\Debug_x64_pre112` (incremental build of HEAD first - nothing to
do - then copied; the nested `Intermediate` folders of that copy removed, 341 MB).
`build\tandemcommander\Debug_x64_111` untouched.

**Working constraint of this session**: the maintainer used the installed Tandem Commander during
the day (it shares `HKCU\Software\Tandem Commander` with every GUI probe), so NO GUI run was made:
no `tandemcommander.exe` started, no registry change. Everything else is done; the probe is written
and parse-checked; the runs are listed in `quickstart.md` (T009, T010 pending).

## T002 - research

Phase-0 research (`research.md` 1-5, written before the work, read-only) plus an addendum with three
corrections found while implementing:
- R re-entering the changed archive does NOT reach L's copy: 109's `SalArchiveCacheKeyChoice` gives
  R a unique key when the archive's size/time differ from L's listing. Probe row `own-reenter` keeps
  it with the both-builds expectation. The reachable triggers are L's own look-ups.
- The reorder of `ExecuteFromArchive` (section 5) opens a small window of its own (a refresh of this
  panel during the launch would pack, release and flush the copy the editor is about to open; the
  GetName request used to keep it) - closed in the same change by holding refreshes over the launch.
- The probe detects L's refresh by `IDS_ARCHIVEREFRESHEDIT` (only L has pending edits).

## T004/T005 - the rule and the cache

- `src/common/salcacheedit.h` (new, header-only, pure): `CSalCacheEditPin` - `EditLocks`,
  `StaleAfterEdit`; `OnFlush(inUse)` -> `scfaDelete` / `scfaMarkOutOfDate` / `scfaDeferStale`;
  `OnEditLockAdded(&outOfDate)` (a mark set before the lock becomes the deferred one);
  `OnLockRemoved(wasEdit)` (TRUE = mark out of date now: the last edit lock went after a deferred
  flush); `Normalize(&outOfDate)` (the look-up's invariant guard). Invariant: `EditLocks > 0` =>
  never out of date; `StaleAfterEdit` => `EditLocks > 0`.
- `src/cache.h`: `crtCacheEdit` (core only; `crtCache` + an edit lock); `LockObjOwner`
  (`TDirectArray<BOOL>`) -> `LockObjFlags` (`TDirectArray<DWORD>`: `CACHE_LOCK_OWNER`,
  `CACHE_LOCK_EDIT`); `CCacheData::EditPin`, `CCacheData::Flush()`; comments of `FlushCache`,
  `FlushOneFile`, `AssignName` (a FALSE return after the name was found has consumed the GetName
  request - recorded, pre-existing).
- `src/cache.cpp`: `AssignName` stores the flags, `Cached` as for `crtCache`, then counts an edit
  lock; `WaitSatisfied` closes the handle by the owner flag, and when the removed lock was the last
  edit lock after a deferred flush, `SetOutOfDate()` BEFORE `*lastLock` is computed - so
  `CDiskCache::WaitSatisfied` deletes an unused copy at once (109's freshness semantics kept);
  `FlushCache` / `FlushOneFile` decide through `Flush()` (the old two branches for a record without
  edit locks); `GetName` calls `Normalize` on a prepared record (TRACE_E if it ever acts).
  Everything runs under the cache monitor (`Enter`/`Leave`), as before.

## T006 - F4 (`ExecuteFromArchive`) and `AddFile`

- `fileswnd.h` / `salamdr3.cpp`: `CFileTimeStampsAddResult` (`ftsarAdded`, `ftsarAlreadyTracked`,
  `ftsarFailed`); `AddFile` returns it (FALSE meant both "already tracked" and "failed"); a failure
  forgets an archive name that this call alone had set (it used to stay set with an empty list);
  `RemoveLastAdded()`.
- `fileswn6.cpp`: after the extraction, under `BeginStopRefresh`: read the copy's stamp if not read
  yet (a copy that already existed - its stamp was read AFTER the launch: an editor that wrote first
  made its edit part of the stamp, dropped as "unchanged"), `AddFile`, and for `ftsarAdded`
  `AssignName(..., ExecuteAssocEvent, FALSE, crtCacheEdit)`; then `AssocUsed = TRUE`, launch,
  `EndStopRefresh`. `ftsarAlreadyTracked` -> `ReleaseName` (the copy holds this panel's edit lock).
  `ftsarFailed` -> `ReleaseName`, "Insufficient memory." (`IDS_PACKERR_NOMEM`, an existing string),
  no launch (it used to release - delete - the copy the editor had just opened). A failed
  `AssignName` -> `RemoveLastAdded`, `FlushOneFile` (the request is gone; an unused copy is deleted,
  a copy another panel edits is pinned), the same message, no launch.

## T007 - saltests `TestCacheEdit112`

The rule (every method, two edit locks, the taken-over mark, `Normalize` both ways); the research
scenarios under the old rule and the new one through a record model that takes cache.cpp's steps
(look-up, assign, release, lock removal, flush, save): S1 own-F3 (old: 1 loss, new 0), own-F4, S6
shared, a flush during the extraction, no flush (cached as before), a viewer's copy (re-created as
before); 40,000 random sequences of 16 steps: without edit locks the new rule equals the old one
step by step (0 mismatches - the plug-ins' and viewers' use unchanged), with them the invariant
holds after every step, no pending edit is extracted over, the deferred mark arrives with the last
edit lock and the guard never acts; the old rule loses edits in the same sequences.
saltests **14,169 -> 14,236 / 0**.

## T008 - the probe (written, not run)

`probe/diskcache_edit_probe.ps1` (helpers copied from 109's probe, ASCII + CRLF, parse-checked with
the PowerShell parser): one archive `t.zip` / `t.7z` with `x.txt` (tag 1) and `y.txt` (tag 2); F4 =
`cmd /c echo edited112>>`, F3 = external `cmd /c type ... >> view.log`; per-row refresh fixture in
`Configuration\Drive Special Settings` (`off`: Fixed Automatic Refresh 0; `net`: a `net use` drive
with Remote Automatic Refresh 0 and Remote Do Not Refresh on Activation 1; `on`: defaults); L's
refresh detected by `IDS_ARCHIVEREFRESHEDIT` -> row CLOSED (controls: required). Rows: `own-F3`,
`own-F4`, `ext-ctrlR`, `ext-x` (each also `@net`), `own-F3_7z`, `own-reenter`, `shared`,
`stamp-race`, controls `own-F3-auto`, `ext-ctrlR-auto`. Verdict: member tags + edit markers read
back, what each F3 was given, whether each leave offered an Archive Update. Expectations per build in
`quickstart.md`.

## T011 - gates

| Gate | Result |
|---|---|
| Debug build (`build.cmd`) | BUILD SUCCEEDED; no compiler warning in a changed file (the pre-existing `zip.cpp(5913)` C4244 when `cache.h` recompiled it) |
| saltests | **14,236 checks, 0 failed** (14,169 before) |
| `python tools\check_encoding.py --strict` | TOTAL: 0 |
| Full Release build (`build.cmd full release`, after the last code change) | BUILD SUCCEEDED, 0 errors; 20 plug-ins in `plugins.ver`, 189 language modules, runtime closure OK |
| clang-format (VS 2022 LLVM) on the changed hunks | no difference (the files' pre-existing differences are unchanged) |
| Encodings | UTF-8 BOM + CRLF kept (`cache.h`, `cache.cpp`, `fileswn6.cpp`, `fileswnd.h`, `salamdr3.cpp`; new `salcacheedit.h` BOM + CRLF like `salarcedit.h`); `saltests.cpp` no BOM, CRLF; `saltests.vcxproj` CRLF; probe ASCII + CRLF; no control characters; spec files UTF-8 without BOM, LF; `CHANGELOG.md`, `NEXT-WORK.md` CRLF |

## Pending (GUI, `quickstart.md`)

- T009: `diskcache_edit_probe` on `Debug_x64` and `Debug_x64_pre112`; every loss row must FAIL on the
  pre-112 build (or be CLOSED on both, with the `@net` variant carrying the evidence).
- T010: regressions 109 diskcache (18/0), 108 namecoll (30/0) + `-CacheKeyRows` (2/0), 096 archedit
  (17/17).

## Hostile re-read of the diff (author)

- **Thread safety**: `EditPin` is touched in `AssignName`, `WaitSatisfied` (cache-handles thread),
  `Flush` (main thread, plug-in worker threads through `RemoveFilesFromCache`) and `GetName` - all
  under the cache monitor; `GetName` calls `Normalize` after re-entering the monitor (the blocking
  wait leaves it). No new lock, no callback out of the cache.
- **Lock counting**: an edit lock is counted when its entry is added (after both arrays grew - an
  allocation failure changes nothing) and uncounted when that entry is removed (`WaitSatisfied`
  matches by handle; `ExecuteAssocEvent` is only ever an edit lock, so an entry with that handle is
  always one). No underflow (guarded). The destructor ignores the pin (the record is gone).
- **Every path that releases an edit lock**: `PrepareCloseCurrentPath` (leave, reopen, exit -
  `SetEvent` + `WaitForIdle` + `ResetEvent`, before the own flush, so the own flush never meets the
  own pins), `OfferArchiveUpdateIfNeededAux` (the same order), critical shutdown with changed files
  (never released, copies left for a manual repack - as before; a flush then defers, nothing reads
  the copy afterwards), unattended close (returns before anything), crash (nothing released - as
  before). A panel never drops its list without releasing (only `CheckAndPackAndClear` clears it).
- **Plug-in cache users**: they pass `crtCache` / `crtDirect`; with no edit lock `OnFlush` is the old
  branch, `OnLockRemoved(FALSE)` does nothing, `Normalize` does nothing - proven step by step in
  saltests; their keys cannot meet the core's archive keys. Interface 107 unchanged.
- **F3 (`ViewFile`)**: unchanged; it now gets the pending copy instead of re-extracting over it.
- **`AssocUsed`** is set only for a tracked copy (it was set also after a failed `AddFile`).

## Code-only review (coordinator): ACCEPT pending GUI - findings applied

Lock accounting, thread safety, the `GetName` guard and the F4 reorder verified by the reviewer;
saltests 14,236 / 0 re-run. Applied (still no GUI run):

- **SF1 (recorded, design kept)**: an UNTOUCHED tracked copy is pinned too. L F4 `x.txt`, closes the
  editor without saving; another program changes `x.txt` in the archive; R Ctrl+R (flush); L without
  automatic refresh: L's F3 shows the OLD `x.txt` (before 112: the new one), and L's second F4 edits
  the old content - its update on leaving overwrites the external change (before 112 that F4
  re-extracted the new member). Ctrl+R or leaving the archive in L ends it. Recorded in spec.md
  (Clarifications, Edge Cases), CHANGELOG and NEXT-WORK next to the per-member warning follow-up.
  **Refinement evaluated and rejected**: re-create a pinned stale copy in `GetName` (or at the
  deferred-mark point) when its file still has the size and write time recorded at F4 ("untouched").
  (1) An editor open with unsaved work leaves the file untouched; re-extracting under it changes
  nothing for the user - its later save writes the old-base content over the new member anyway, and
  then the panel's stamp no longer matches the re-extracted file (it would be offered even when the
  user saved nothing). (2) It can lose an edit: a save within the volume's time resolution with an
  equal size (FAT/exFAT 2 s; an FTP-mounted or WebDAV TEMP), or a tool that restores the write time,
  leaves size and time equal - the copy would be extracted over the edit, the exact loss 112 removes.
  (3) The cache does not know the F4 stamp (it lives in `CFileTimeStamps`); the record would need it
  through `AssignName`. Not implemented; the per-member warning follow-up covers the case without a
  heuristic.
- **SF2**: spec.md Clarification "What does a look-up see meanwhile?" said R's F3 shows L's edited
  copy of the old member - wrong since 109 (R's reopen of a changed archive gets a unique key and
  shows the archive's current member). Rewritten; research.md addendum corrects phase-0 section 3
  (b)'s "Con" the same way.
- **NIT1**: `ExecuteFromArchive` launches the editor / association with a heap copy of the name
  (`CSalHeapString launchName`, any length; `launchS` points into it). `name` and `s` point into the
  disk-cache record's `TmpName`, which only the lock keeps alive; in the already-tracked branch the
  request is released before the launch, and a release re-entered during the launch (Ctrl+R ends
  `StopRefresh` by force, `CM_ACTIVEREFRESH` in `mainwnd3.cpp`, and refreshes the panel) would leave
  them dangling. A failed copy = the low-memory refusal (release, message, no launch).
- **NIT2**: the comment of the `ftsarFailed` branch now says that it also covers "another archive"
  (unreachable: the list is emptied whenever the panel leaves its archive) and that the message is
  the low-memory one, the only reachable cause.
- **NIT4 (probe)**: refuses to run unless the current thread's desktop is a non-default one
  (`GetThreadDesktop` + `GetUserObjectInformationW(UOI_NAME)`; `Default` / `Winlogon` -> "NOT RUN",
  exit 3 - the query was checked in this session: it returns `Default` on the user's desktop);
  `Set-NetDrive` removes a mapping it made that is not reachable before trying the next letter;
  NOT DRIVEN rows say "no evidence either way"; quickstart notes the non-elevated `\\localhost\C$`
  use of 103/107/109 and how to report a NOT DRIVEN `@net` row.

Gates after the fixes: see T011 (re-run).

## Commit before the GUI runs

Committed after the code-only review with all GUI runs still owed (the maintainer uses the
installed program during the day; it shares the registry key with the probes). The build of this
commit is preserved as `build\tandemcommander\Debug_x64_112`; the evening runs use it (not
`Debug_x64`, which later features rebuild). Results and any fix follow in a separate commit.

## Recorded, not changed

- A per-member warning when the member itself changed in the archive since the F4 (row `ext-x`: L's
  edit of the old member overwrites the external change after the usual notice and list, as before
  when L refreshed first) - needs a new string and a dialog change: follow-up.
- Own-delete archiver plug-ins (research S10): on an out-of-date copy `CleanFromDisk` only QUEUES the
  plug-in's delete and the core extracts into the same name at once - the queued delete can remove
  the fresh copy (pre-existing, only demoplug uses it, off by default).
- `ViewFile` (F3) ignores `AssignName`'s result; on failure the record keeps neither request nor lock
  (an orphan until the next flush or exit) - pre-existing, harmless (no edit).
- `CCacheData::IsLocked()` returns TRUE when the record is NOT in use (the name is inverted) - kept,
  commented where 112 uses it (`Flush()` passes `!IsLocked()` as "in use").
- The low-memory refusal is not drivable without fault injection (code reading only).

## CLAUDE.md entry (proposed)

- 112-cache-pending-edit: **a flush of the disk cache never throws away a
  pending edit.** NEXT-WORK item 5, queue entries 2a (109's review) and 3.
  With both panels on one archive and an F4 edit pending in the left one,
  the right panel's flush (after its own update, or after reopening an
  archive another program changed) marked the left copy out of date; the
  next F3 / F4 of that member deleted it and extracted the member over the
  edit - the stamp then matched and nothing was offered (every release;
  only while the left panel did not refresh in between: automatic refresh
  off, a share without notifications, Ctrl+R in the right panel).
  - **Rule** (`src/common/salcacheedit.h`, `CSalCacheEditPin`): the panel's
    lock on a tracked copy is a core-only EDIT lock (`crtCacheEdit`,
    `CACHE_LOCK_EDIT` in `LockObjFlags`, was `LockObjOwner`); a flush that
    meets it defers the out-of-date mark (`StaleAfterEdit`), set in
    `CCacheData::WaitSatisfied` when the last edit lock goes - then an
    unused copy is deleted at once (109's freshness kept). A mark set
    between look-up and lock is taken over; `GetName` guards the invariant.
    Without an edit lock the rule is the old one step by step (plug-ins
    unchanged; saltests random parity).
  - **F4** (`ExecuteFromArchive`): stamp, `AddFile` (three results,
    `CFileTimeStampsAddResult`) and the edit lock BEFORE the launch, under
    `BeginStopRefresh`; a copy that cannot be tracked is released and not
    edited (`IDS_PACKERR_NOMEM`) - it used to be deleted under the editor;
    the stamp of an existing copy was read after the launch (a fast editor's
    write became "unchanged").
  - Research correction: R re-entering the changed archive cannot reach the
    copy (109 gives it a unique key).
  - Trade-off (review SF1): an UNTOUCHED tracked copy is pinned too - after
    another program changed that member, the panel that opened it shows and
    edits the old content until Ctrl+R / leave; a size/time "untouched" test
    was rejected (it can extract over an edit). Follow-up: a per-member
    "changed in the archive since F4" warning (needs a string).
  - The launch uses a heap copy of the copy's name (the record's `TmpName`
    lives only as long as its lock; a forced Ctrl+R during the launch).
  - Probe `probe/diskcache_edit_probe.ps1` (refresh off / `net use` drive
    with no refresh, controls with refresh on, the left panel's refresh
    detected): GUI runs pending. saltests 14,169 -> 14,236. Interface stays
    107, no new string, no registry change. Records:
    `specs/112-cache-pending-edit/fix-log.md`.
