# Research (phase 0): feature 112 - a flush must not throw away a copy with a pending edit

Read-only research at HEAD `018ec169` (branch `111-pictview-shown-image`, its uncommitted PictView
work does not touch any file named here). Nothing was built or run. Line numbers are of the working tree.

Backlog: NEXT-WORK item 5, queue entry 2a (from 109's review) and entry 3 (`AddFile` on low memory, from 108).

## 1. Code paths

### 1.1 The cache (`src/cache.h`, `src/cache.cpp`)

`CDiskCache` (monitor, `Enter`/`Leave` = one critical section) -> `CCacheDirData` per `SAL<hex>.tmp`
folder -> `CCacheData` per copy. A record has `Name` (the key), `TmpName` (the file), the `Preparing`
mutex, `LockObject[]` + `LockObjOwner[]` (handles; signalled = that user is done), `NewCount`,
`Prepared`, `Cached`, `OutOfDate`, `Detached`, `OwnDelete`/`OwnDeletePlugin` (`cache.h:37-152`).

| What | Where | Behaviour |
|---|---|---|
| mark stale | `CCacheData::SetOutOfDate` `cache.h:138-142` | `Cached = FALSE; OutOfDate = TRUE` - nothing else, the file stays |
| flush by prefix | `CCacheDirData::FlushCache` `cache.cpp:680-707`, wrapper `CDiskCache::FlushCache` `1428-1438` | every key with `strncmp(key, prefix)`: unlocked (`IsLocked()` = no lock objects and `NewCount == 0`) -> record deleted with its file (`693-696`); locked -> `SetOutOfDate()` (`701`) |
| flush one | `CCacheDirData::FlushOneFile` `709-731`, `CDiskCache::FlushOneFile` `1440-1455` | the same for one key |
| look-up / re-extraction | `CDiskCache::GetName` `1130-1237` -> `CCacheDirData::GetName` `494-511` -> `CCacheData::GetName` `144-228` | on a `Prepared` copy: `attrs == -1 \|\| OutOfDate` (`177`) -> `Prepared = FALSE` (`197`), falls through: `OutOfDate = FALSE` (`219`), `*exists = FALSE`, **`CleanFromDisk()`** (`223`) deletes the file, returns the SAME `TmpName` - the caller extracts the member into it. No check whether the file was modified. |
| delete a file | `CCacheData::CleanFromDisk` `97-142` | `SalDeleteFile`; with `OwnDelete` it is queued to `DeleteManager` (asynchronous, plug-in deletes later - `130-139`) and reports success at once |
| prepared | `CCacheData::NamePrepared` `230-237` | stores size only (no time stamp) |
| assign a lock | `CCacheData::AssignName` `239-265` | adds the lock; `remove == crtCache && !OutOfDate` -> `Cached = TRUE` (`259-260`) |
| release a request | `CCacheData::ReleaseName` `269-283`; `CCacheDirData::ReleaseName` `591-613` | last reference and not cached -> record deleted at once (`604-608`) = file deleted |
| lock signalled | `CCacheData::WaitSatisfied` `285-309` -> `CDiskCache::WaitSatisfied` `1374-1408` (cache-handles thread, under the monitor) | last lock: cached -> `CheckCachedFiles` (100 MB LRU, only unlocked copies `647-661`), else `Release` = deleted |
| `DetachTmpFile` | `cache.cpp:663-678`, `1410-1426` | still no caller (109) |

`CCacheRemoveType` (`crtCache`, `crtDirect`, `cache.h:28-32`) is core-internal: no plug-in header
(`src/plugins/shared/*.h`) names it; plug-ins reach the cache only through the `CSalamanderGeneral`
services (`zip.cpp:3196-3306`) and `CSalamanderForViewFileOnFS`.

### 1.2 Who creates and locks an archive member's copy

- **F4 / Enter on an associated file**: `CFilesWindow::ExecuteFromArchive` `fileswn6.cpp:3375-3597`.
  Key from `GetArchiveCacheKey` (`3442`) + folder + name; `DiskCache.GetName` `3490`; extract
  (`PackUnpackOneFile` `3514`), `NamePrepared` `3531`; launch editor `3555-3563` / association
  `3564-3573`; for a copy that already existed (`exists == TRUE`) size/time are read **after** the
  launch (`3575-3586`); then `UnpackedAssocFiles.AddFile(...)` `3588`: TRUE -> `AssignName(dcFileName,
  ExecuteAssocEvent, FALSE, crtCache)` `3590`, FALSE -> `ReleaseName(dcFileName, FALSE)` `3594`.
  So **every copy a panel tracks for editing holds exactly one lock = that panel's `ExecuteAssocEvent`**
  (manual-reset event, one per panel, `fileswn1.cpp:1503`), and only tracked copies hold it.
- **F3**: `CFilesWindow::ViewFile` `fileswn5.cpp:786-990`: same key (`802-817`; `:0x<ptr>` suffix only for
  byte-identical duplicate names `861-873`, which F4 refuses `fileswn6.cpp:3410-3426`), `GetName` `884`,
  extract `909`, `NamePrepared` `924`, viewer lock `AssignName` `983` (`crtCache` or `crtDirect`) or
  `ReleaseName` `987`. F3 and F4 of one member share ONE record (since 108).

### 1.3 How edits are tracked: `CFileTimeStamps` (per panel)

- `CFilesWindow::UnpackedAssocFiles` (`fileswnd.h:867`), class `fileswnd.h:298-345`, items
  `CFileTimeStampsItem` `278-294` (`ZIPRoot`, `SourcePath` = the SAL folder, `FileName`, `LastWrite`,
  `FileSize`, `Attr`). `AssocUsed` + `ExecuteAssocEvent` (`fileswnd.h:865`) belong to it.
- `AddFile` `salamdr3.cpp:3114-3169`: returns FALSE for **already tracked** (`3151-3158`, same copy by
  `SalEditedCopyIsSame`, 108) **and** for low memory (`3121-3123`, `3141-3142`, `3162-3166`) and an
  archive-name mismatch (`3128-3132`).
- `CheckAndPackAndClear` `salamdr3.cpp:3398-3545`: an item whose file on disk still has the stored time
  AND size is dropped (`3439-3454`); only "not there" drops an unreadable one (096, `3419-3438`); the rest
  -> `CArchiveUpdateDlg` (`dialogs5.cpp:1397-`; Cancel asks `IDS_ARCREALLYIGNOREALL`, "Copy to" exists)
  -> `PackCompress` per (zip root, source path) group (`3477-3535`). Then the list is cleared.
- The cache does not know this list. The only link is the lock handle.

### 1.4 Every flush and what precedes it

| Caller | Lines | Before the flush | Flushes |
|---|---|---|---|
| `PrepareCloseCurrentPath` (leave, reopen, exit) | `fileswn2.cpp:1237`; pack `1287`; release own locks `1292-1297` (`SetEvent` + `WaitForIdle`); "other panel shows it" `1308-1342` (keys equal + archive unchanged against the OTHER panel's listing, 109); flush `1343-1352` | own edits packed, own copies released | `key\` when own files changed OR the other panel does not (freshly) show the archive |
| callers of it | `ChangePathToDisk` `fileswn2.cpp:1813`; `ChangePathToArchive` `2311` (also the reopen of a changed archive, `2490-2519`, which first shows `IDS_ARCHIVEREFRESHEDIT` "Archive ... has changed. Archive will be reopened in panel." when `AssocUsed`); `ChangePathToPluginFS` `2997`; `ChangePathToDetachedFS` `3549`; exit `mainwnd3.cpp:7084/7086` (left then right, modal) | | |
| `OfferArchiveUpdateIfNeededAux` (before an archive operation, drag start) | `fileswn9.cpp:1245-1278`, pack `1257`, release `1258-1260`, flush `1263-1275` | own edits packed, own copies released | `key\` if own files changed |
| `OfferArchiveUpdateIfNeeded` | `fileswn9.cpp:1280-1321` | this panel's Aux (`1284`, it FLUSHES), then the other panel's Aux when it shows the same archive by name or key (`1290-1303`) | |
| callers | `mainwnd3.cpp:3663` (F5/F6/F8/... from an archive), `fileswn9.cpp:1344` (drag), `salshlib.cpp:637` (paste) | | |
| plug-in services | `RemoveFilesFromCache` `zip.cpp:3297-3306` -> `FlushCache`; `RemoveOneFileFromCache` `3286-3295` -> `FlushOneFile` | nothing | the plug-in's own prefix (FTP `ftp://user@host...`, SFTP `<fs>:user@host:port...` `sftp/fs.cpp:955`, undelete `<fs>:` `undelete/fs1.cpp:71-75`, demoplug `dfs:`) |

The core's archive keys start with the folded archive path (`C:\...`, `\\...`); no shipped plug-in
prefix can match one. Plug-in FS copies (FTP/SFTP/regedt/undelete `AllocFileNameInCache` /
`GetFileFromCache` / `MoveFileToCache`) are viewer copies: there is **no edit tracking for a plug-in
FS** (only `ExecuteFromArchive` calls `AddFile`).

Refresh of the OTHER panel (the thing that closes the window today): an archive panel watches the
archive's folder (`SetPath`, `fileswn1.cpp:250-299`; `Path` = the archive's folder) when "automatic
refresh" is on for that drive type (`Configuration\Drive Special Settings\{Fixed|Remote|Removable|CDROM}
Automatic Refresh`, defaults all on - `dialogs4.cpp:390-397`, names `mainwnd2.cpp:419-428`). The
notification posts `WM_USER_REFRESH_DIR` -> `RefreshDirectory` (`fileswn0.cpp:2690-2693`) ->
`ChangePathToArchive(forceUpdate)` -> size/time differ -> reopen -> its own `PrepareCloseCurrentPath`
packs first. Without monitoring: refresh only on app activation (`CFilesWindow::Activate`
`fileswn6.cpp:204-245`, from `mainwnd3.cpp:6183-6184`; `SkipOneActivateRefresh`; network drives
honour `Remote Do Not Refresh on Activation`), Ctrl+R (`CM_ACTIVEREFRESH` 740, `CM_LEFTREFRESH` 724,
`CM_RIGHTREFRESH` 725, `resource.rh2:96-117`, `mainwnd3.cpp:3505-3545`), or a
`PostChangeOnPathNotification` - which the archive update does **not** send (none in `pack*.cpp` /
`CheckAndPackAndClear`; `AcceptChangeOnPathNotification` `fileswn7.cpp:2291-2331` would refresh a
non-auto panel).

## 2. Scenarios

Mechanism: a flush finds the other panel's tracked copy LOCKED (its `ExecuteAssocEvent`) ->
`SetOutOfDate` (`cache.cpp:701`) -> the next `GetName` on that key from either panel deletes the file
with the unpacked edit (`cache.cpp:177-197, 219-227`) and the caller extracts the member into the
same name. The tracking panel's item keeps its time stamp of the FIRST extraction: if the member did
not change in the archive, the new copy has the same time and size -> dropped as "unchanged" at
`salamdr3.cpp:3442-3454` -> nothing offered, edit lost silently. If the member did change, the new
content is offered (the user's edit is still gone).

| # | Scenario | Reachable? |
|---|---|---|
| S1 | **Two panels, one archive, own update in R of another member Y** (R: F4 Y, leave / reopen / exit-of-tab). R's `PrepareCloseCurrentPath` packs Y (`1287`), flushes `key\` (`1348`) -> L's copy of X out of date. Trigger: L F3/F4 on X, **or R itself** after re-entering the archive F3/F4 on X (same key). | **Yes, when L does not refresh in between.** Default config: the archive's folder is watched, L's refresh is posted at R's `EndStopRefresh` and runs before the user's next key; L reopens, shows `IDS_ARCHIVEREFRESHEDIT`, packs X - no loss (109 never drove it: "the other panel's auto refresh closed the window in every probe row"). Opens with: automatic refresh off for the drive type (a Configuration choice, common for network drives), a share / file system that sends no change notifications, an update leaving size and time equal (FAT 2-s time + same-size stored member). Every release. |
| S2 | Same, R's update by an archive operation (F5/F6/F8/drag/paste) | **No.** `OfferArchiveUpdateIfNeeded` packs BOTH panels before anything else (`fileswn9.cpp:1284`, `1300`). This panel's flush (`1271`) runs before the other panel's pack, but `CheckAndPackAndClear` reads the file on disk and out-of-date does not delete it. |
| S3 | Exit with edits in both panels | **No.** `mainwnd3.cpp:7084-7086` closes left then right, modal; no `GetName` in between. |
| S4 | **Archive changed externally**, both panels show it, L has a pending edit of X. R refreshes first (snooper, or Ctrl+R): freshness test fails (`fileswn2.cpp:1333-1340`) -> flush -> L's copy out of date. | Same condition as S1: with monitoring both panels' refreshes are queued and L packs right after (no loss); without monitoring the user's Ctrl+R in R opens it, then L F3/F4 X loses the edit (if X itself changed externally the external X is offered instead of the edit). |
| S5 | Forced reopen (`RefreshForConfig` `fileswn0.cpp:3460-3473`, `RefreshPanelPath(panel, TRUE)`) | Without own edits: fixed by 109 (freshness against the other panel's listing; both markers -> keep). With own edits in R: = S1. Configuration OK refreshes both panels synchronously (`SendMessage`), L packs at once - no window. |
| S6 | Both panels track the SAME copy (F4 X in L and in R) | R packs the shared file (with the edit), flush, L's later F4 re-extracts the packed content; L's time differs -> offered again (harmless repack). Only an edit saved between R's pack and L's re-F4 is lost. Narrow. |
| S7 | One panel only | **No.** Every flush of the own key comes after the own pack + release (`1287/1294`, `1257/1258`); a panel's tabs (078) are sequential `ChangeDir`s through `PrepareCloseCurrentPath`. |
| S8 | F3 vs F4 | Both reach `CCacheData::GetName` with a `tmpName` -> identical deletion. F3: the viewer shows the original, the edit is gone and nothing is offered (the more silent one). F4: the editor shows the original - the user may notice; the new edit is offered, the first is gone. F3's `:0x<ptr>` key (byte-identical duplicates) never meets an F4 key. |
| S9 | Plug-in file systems | **No edit to lose** (no `CFileTimeStamps` for FS); their prefixes cannot reach core archive keys. Design (a) would have to cope with `RemoveFilesFromCache` from plug-in worker threads; (b) does not. |
| S10 | Own-delete archiver plug-ins (`GetCacheInfo` ownDelete; only demoplug, off) | Pre-existing, separate: on an out-of-date copy `CleanFromDisk` only QUEUES the plug-in's delete (`cache.cpp:130-139`) and returns TRUE; the core then extracts into the same `TmpName` - the queued delete can remove the fresh copy. Recorded, not part of 112. |

Found on the way (small, pre-existing, recorded): for a copy that already existed (F3 first, or the
other panel's copy) `ExecuteFromArchive` reads the stamp **after** launching the editor
(`fileswn6.cpp:3575-3586`). An editor/association that writes before that read (a script; the 109
probe's `cmd /c echo >>` editor) makes the stored stamp include the edit -> "unchanged" at close ->
edit lost. A human editor is too slow to hit it. The fix is the reorder of section 5.

## 3. Design options

### (a) The cache asks a registry of edited copies (callback from `salamdr3` into `cache`)
`FlushCache`/`GetName` call back "is `TmpName` tracked by a panel's `CFileTimeStamps`?".
- Pro: one source of truth (the list itself); could also tell modified vs untouched.
- Con: wrong layering (cache.cpp would walk `MainWindow->Left/RightPanel` lists); runs inside the cache
  monitor and possibly on a plug-in worker thread (`RemoveFilesFromCache`) while the main thread
  mutates the list - needs a new lock around both lists; deadlock risk (main thread holds the list and
  calls into the cache). The cache already has the same information in a thread-safe form: the lock.

### (b) Tracked copies are pinned: a flush never marks them out of date (deferred mark) - **recommended**
The panel's `ExecuteAssocEvent` lock already means "a panel tracks this copy for update". Make it an
explicit edit lock and defer the stale mark until the last edit lock goes:
- `cache.h`: new core-only `CCacheRemoveType` value (e.g. `crtCacheEdit` = `crtCache` + "edit lock"),
  passed only at `fileswn6.cpp:3590`; `CCacheData` gets `int EditLocks` (or a per-lock BOOL array
  beside `LockObjOwner`) and `BOOL OutOfDateAfterEdit`.
- `FlushCache` (`cache.cpp:698-702`) and `FlushOneFile` (`723-727`): locked with `EditLocks > 0` ->
  `OutOfDateAfterEdit = TRUE` instead of `SetOutOfDate()`; otherwise unchanged.
- `CCacheData::WaitSatisfied` (`285-309`): when an edit lock is removed and `EditLocks` reaches 0 and
  `OutOfDateAfterEdit` -> `SetOutOfDate()` **before** `lastLock` is evaluated by the caller, so
  `CDiskCache::WaitSatisfied` (`1383-1397`) sees "not cached" and deletes an unused copy at once - 109's
  freshness semantics are kept (`stale-same` cannot regress: a copy that escaped one flush is dropped
  when its panel lets go).
- `GetName` unchanged: `OutOfDate` is never TRUE while an edit lock exists (a copy marked before the
  first F4 is re-extracted before the lock is assigned - correct, nothing edited yet).
- Behaviour: in S1/S4 L's next F3/F4 gets the edited copy (as before the flush); R, after re-entering,
  also gets it (same key = one record; the sharing of every release, now just not destroyed). When L
  reopens (snooper, activation, Ctrl+R, leave) its pack runs first and offers X; then the deferred mark
  frees the copy. Plug-ins: no API or behaviour change (they never pass the new type; their prefixes
  never meet core keys; if one did, the pin protects). Thread-safe: all under the cache monitor.
- Con: in S4 (external change of X itself) R's F3 shows L's edited OLD-base X until L packs - accepted:
  it is exactly what L's pending update will write, and `stale-same` without an edit stays fixed. A
  tracked but untouched copy is also kept until L lets go (L reopens anyway at its next refresh).

### (c) `GetName` refuses to recreate a copy modified since it was prepared
Store the copy's time/size at `NamePrepared`; on `OutOfDate` with a different file on disk keep it.
- Pro: needs no knowledge of who edits; would also keep an edit nobody tracks.
- Con: changes plug-in semantics (an FTP/SFTP view copy re-fetched after `RemoveFilesFromCache` would be
  kept if a viewer/editor touched it - stale remote content), so it must be restricted to core records
  = (b)'s flag anyway; misses a copy whose editor has not saved yet (re-extracted under the open editor,
  which later saves into the fresh file - works by luck); time-stamp heuristics (granularity, editors
  that restore mtime); and with an own-delete plug-in the S10 race remains. `NamePrepared` would need a
  time from every caller (F3 passes only the size).

### What should happen when the archive really changed and the user edited the old copy?
Today (with monitoring): L's reopen shows `IDS_ARCHIVEREFRESHEDIT`, then 096's Archive Update dialog
lists X; *Update* packs the old-base edit over the external X (the user is told the archive changed and
sees the list - informed, but not told that X itself changed). (b) keeps exactly that and removes the
silent loss. "Keep both / warn per member" (compare the member's new listing time with the stamp taken
at F4) needs a new string and a dialog change - recommend recording it as a follow-up, not part of 112.

**Recommendation: (b)**, with the deferred mark. Small, local to `cache.{h,cpp}` + one call site,
no plug-in interface change (interface stays 107), no new string, no registry change; saltests cannot
link `cache.cpp` (needs the core), so the rule is proven by the probe (section 4) plus code reading.
Optional hardening in the same change: an out-of-date record that still has an edit lock must never be
re-extracted (assert / TRACE_E in `CCacheData::GetName`).

## 4. Reproduction on the hidden desktop (`tools/run_on_hidden_desktop.ps1`)

Base: copy `specs/109-disk-cache-archive-key/probe/diskcache_probe.ps1` (helpers, `Set-ProbeConfig`,
`Invoke-ArcFix` with several members - `arcfix.py` takes `members` and tags them 1..n, `Run-Steps`,
`Find-Tmp`, view log, registry backup/restore, refusal while another `tandemcommander.exe` runs).
Changes:
1. **Open the window**: in `Set-ProbeConfig` add `reg add "...\0.1\Configuration\Drive Special Settings"
   /v "Fixed Automatic Refresh" /t REG_DWORD /d 0` for the `-NoAutoRefresh` rows (TEMP is on a fixed
   drive). Positive control rows run with it on and must show L's reopen. The probe must DETECT whether
   L refreshed: a served window with "has changed. Archive will be reopened" (`IDS_ARCHIVEREFRESHEDIT`) or
   an Archive Update dialog for L before L's own leave = "window closed, row not driven". If the hidden
   desktop delivers activation refreshes (`CFilesWindow::Activate`), fall back to a `net use` drive
   (109's `Set-NetDrive`, `\\localhost\C$\...`) with `Remote Automatic Refresh`=0 and
   `Remote Do Not Refresh on Activation`=1.
2. **Member choice**: archives with `x.txt` (tag 1) and `y.txt` (tag 2); extend `f3`/`f4` with
   `Arg = <downs>` (Home, Down x n: 1 = x.txt, 2 = y.txt).
3. Verdict per archive = tag + marker count per member (`arcfix.py read`), views from `view.log`, and
   "no Archive Update window for L" where loss is silent.

Rows (ZIP; one 7z variant of S1-F3):

| Row | Steps (panel: op) | Before 112 (expected) | After (b) |
|---|---|---|---|
| `own-F3` (S1, F3) | L cd t.zip; L f4 x; R cd t.zip; R f4 y; R leave (Update); L f3 x; L leave | F3 given x tag 1, **0 markers**; L leave: no update window; t.zip x=0 markers, y=1 | F3 x with 1 marker; L leave offers x; x=1, y=1 |
| `own-F4` (S1, F4) | ... as above, then L f4 x; L leave | x=1 marker (the second edit only), first lost | x=2 markers |
| `own-reenter` (S1, trigger in R) | L cd; L f4 x; R cd; R f4 y; R leave; R cd t.zip; R f3 x; R leave; L leave | R's F3 x 0 markers; final x=0 | R's F3 x 1 marker; final x=1 |
| `ext-ctrlR` (S4) | L cd; L f4 x; R cd; rewrite t.zip from outside with y tag 9 (x unchanged); R CM_ACTIVEREFRESH (740, R active); L f3 x; L leave | F3 0 markers, x=0, nothing offered | F3 1 marker; x=1, y=tag 9 |
| `ext-x` (S4, X itself changed) | as `ext-ctrlR` but the rewrite gives x tag 9 | F3 tag 9 / 0 markers; L offers x (the external content) - edit lost | F3 tag 1 + 1 marker (old base); L offers x; x = tag 1 + 1 (today's 096 overwrite - documented) |
| `shared` (S6) | L f4 x; R f4 x; R leave; L f3 x; L leave | R's F4 meets an existing copy, so its stamp is read after the `cmd` editor ran (section 2 race): R may see "unchanged" and pack nothing; L then packs both markers. Expect x=2 either way; use it to measure the race (does R offer?), not as a 2a row | same (the race is fixed only by section 5) |
| controls with auto refresh ON | `own-F3`, `ext-ctrlR` | L reopens before its F3 (window detected), x=1: row "window closed" on both builds | same |
| regression | 109 probe (18 rows incl. `stale-same`, `reuse`, `prefix`), 108 namecoll + `-CacheKeyRows`, 096 archedit, 097 arcwork ZIP/7z subset | unchanged | unchanged |

Probe hygiene: run every row on the pre-112 build first (copy of HEAD's Debug tree) - a row that does
not fail there is not evidence; wrap each run as 109 did (no `tandemcommander.exe` before, registry
SHA-256 before = after, scratch under `%TEMP%\tc112\`). The stamp race of section 2 (editor = `cmd /c
echo >>`) does not affect these rows: every first F4 extracts (`exists == FALSE`, stamp taken before the
launch at `3524-3528`); do not start a row with F3-then-F4 on the same member unless that race is the
subject.

## 5. `AddFile` on low memory (queue entry 3)

Today (`fileswn6.cpp:3555-3595`): the editor is launched first; then `AddFile` FALSE is read as
"already tracked" -> `ReleaseName(dcFileName, FALSE)` -> last reference, not cached ->
`CCacheDirData::ReleaseName` deletes the record (`cache.cpp:604-608`) -> `~CCacheData` ->
`CleanFromDisk` deletes the file the editor just opened. The edit is untracked; a later save recreates
an orphan in the SAL folder, never offered, removed with the folder at exit (`~CCacheDirData`
`cache.cpp:342-356`).

What it takes (one function, no new string):
- `AddFile` returns three states (added / already tracked / failed) - e.g. an enum or an out-param;
  callers: only `fileswn6.cpp:3588`.
- In `ExecuteFromArchive`: read the copy's stamp (also for `exists == TRUE`) and call `AddFile`
  **before** launching the editor/association. Failed -> `ReleaseName`, low-memory message
  (`TRACE_E(LOW_MEMORY)` + the existing generic low-memory text, as other F4 refusals do), do not launch.
  Added -> launch, then `AssignName(..., ExecuteAssocEvent, ..., crtCacheEdit)`. Already tracked ->
  launch, `ReleaseName`. This also fixes the stamp-after-launch race (section 2). If the launch fails
  after "added", the item stays unchanged and is dropped silently at close - harmless.
- `AssocUsed = TRUE` (`3596`) only when the copy is tracked.
- Reachability: needs a few-dozen-byte allocation to fail between extraction and tracking; not drivable
  in a probe without fault injection - verify by code reading (+ optional Debug-only injection switch).
- 109's other OOM note (`GetArchiveCacheKey` fallback re-creating sharing) is independent; a "no key"
  state that makes F3/F4 refuse could ride along but is not needed for 112.

## Addendum (implementation, 2026-10-05)

Phase 0 above was written before the work and is kept as it was; corrections found while
implementing:

- **S1's "or R itself after re-entering the archive" trigger is closed by 109.** When R enters the
  archive again after its own update, the archive's size and time differ from L's listing, so
  `SalArchiveCacheKeyChoice` (109) gives R a UNIQUE key (`sakUnique`: "not the file the other panel
  listed"); R's F3 / F4 use their own records and never meet L's copy, and R's flush (`key\x01n\`)
  cannot match L's key either. The probe keeps the row as `own-reenter` with the expectation of both
  builds (R's F3 gives the archive's x.txt, L's edit is packed). The reachable triggers are L's own
  look-ups (rows `own-F3`, `own-F4`, `ext-*`).
- **The reorder of section 5 opens a small window of its own, closed in the same change.** With the
  tracking and the edit lock before the launch, a refresh of THIS panel during the launch (a modal
  loop: an error box of `ExecuteAssociation`, DDE inside `ShellExecuteEx`) would pack the unchanged
  item, release the lock and flush - deleting the copy the editor is about to open; before, the
  GetName request kept it on disk until the launch. `ExecuteFromArchive` now holds refreshes
  (`BeginStopRefresh` / `EndStopRefresh`, the pair the extraction already uses) from the tracking to
  the end of the launch. `EditFileWith` already held them around its menu.
- **A mark set between the look-up and the edit lock** (a flush while the member is being extracted;
  the extraction already holds refreshes, so it is hardly reachable) is taken over as the deferred
  mark by `OnEditLockAdded`; the copy is then not cached. Covered by saltests.
- **Section 3 (b)'s "Con: in S4 R's F3 shows L's edited OLD-base X" is wrong** for the same reason:
  R's reopen of a changed archive gets a unique key, so R's F3 shows the archive's current member;
  only L keeps seeing its pinned copy (also an UNTOUCHED one - the trade-off recorded in spec.md,
  review SF1).
- **The probe's detection of L's refresh**: L is the only panel with pending edits in the loss rows,
  so `IDS_ARCHIVEREFRESHEDIT` ("Archive file ... has changed. Archive will be reopened in panel.")
  appears exactly when L reopens; R's reopen without edits shows nothing.
