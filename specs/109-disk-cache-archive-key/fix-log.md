# Fix log: feature 109 - an archive's temporary copies belong to that archive only

Branch `109-disk-cache-archive-key` (from `108-archive-edit-name-collision`, HEAD 8f673f3c).
Pre-change build preserved as `build\tandemcommander\Debug_x64_pre109` (incremental build of HEAD
first - nothing to do - then copied without `Intermediate`). All GUI runs on the hidden desktop
(`tools\run_on_hidden_desktop.ps1`), each wrapped: no `tandemcommander.exe` running,
`HKCU\Software\Tandem Commander` exported before and compared after - SHA-256 prefix
`1AB614304771DBE0` before and after every run (the probes also back up / restore / verify the key
themselves). Scratch under `%TEMP%\tc109\`; the probe's SUBST letter (`T:`) removed after each row
that made it (checked: "exists now: False"). No network drive mapping touched.

## T002/T003 - measured first

Route, every key site, the plug-in contract and persistence: `research.md` 0. Measurement probe
`probe/diskcache_probe.ps1` (helpers copied from 108's probe; archives by 108's `arcfix.py`; F4 =
`cmd /c echo edited109>>"$(FullName)"`; F3 = an external viewer `cmd /c type "$(FullName)">>view.log`,
so what each F3 was GIVEN is read back; archives entered by Change Directory in the panel of the step).

`Debug_x64_pre109` (`probe/diskcache_result_pre109.txt`, plus `diskcache_result_pre109_reuseaccent.txt`
for the one row that a probe defect - PowerShell flattening a one-element array of pairs - left NOT
DRIVEN in the full run; fixed, re-run alone): **6 PASS / 8 FAIL** (+ the `stale-*` rows added later, `probe/diskcache_result_pre109_stale.txt`: `stale-same` FAIL, `stale-subst` PASS - T009a).

| Row | Before 109 |
|---|---|
| `twoarcF4_zip`, `twoarcF4_7z` (`ĥ` / `Ĺ`, F4 in each panel, leave both) | one copy; **both** archives end with `ĥ`'s x.txt + both edits |
| `twoarcF3_zip`, `twoarcF3_7z` | the second F3 given `ĥ`'s file |
| `twoarcF4F3_zip` | F3 in `Ĺ` given `ĥ`'s file with the pending edit |
| `alias-subst`, `alias-unc` | two copies of one member, 1 edit of 2 packed (the second update replaced the first after "overwrite?") |
| `prefix` (`p.zip.zip` edited; `p.zip` entered and left in the other panel; F4 again) | 1 edit of 2: the first edit deleted with the copy, the member extracted over it - no message |
| `alias-ascii`, `alias-accent` (ZIP, 7z), `alias-sfn`, `reuse`, `reuse-accent` | PASS - Change Directory already gives the archive its on-disk spelling (`ChangeDir`'s component enumeration), so case and 8.3 spellings shared one key |

The premise was right; the consequence is wider: the one shared copy is packed into BOTH archives,
F3 is affected, and a third defect of the same key (the prefix flush) loses edits silently.

## T005 - S1: the key rule (`salunicode.{h,cpp}`)

- `SalNameIdentityFoldUnit(WCHAR)`: ASCII upper case; other units through ntdll's
  `RtlUpcaseUnicodeChar` (looked up once; without it a non-ASCII unit stays itself - two keys, never
  one key for two names).
- `SalNameIdentityKeyAlloc(s, len, reserve)`: ASCII - upper-cased copy; valid WTF-8 - every unit
  folded, encoded back to WTF-8; not WTF-8 - `0xFF` + `CharLowerA` per byte; low memory (a valid
  string whose conversion buffer cannot be allocated) - NULL, never the legacy key. Contract:
  `strcmp(key(a), key(b)) == 0` <=> `SalNameEqualOrdinalCI(a, b)`.
- `CSalHeapString::Adopt` (take a malloc()ed buffer), `Swap` (`salheapstr.h`).

## T006 - S1: one file under two spellings (`salsamefile.h`)

`SalArchiveSharesCacheKey(a, b)`: `SalFileIdMatch == simEqual`, both snapshots known and equal, and
with weak ids (FAT/exFAT) also `SalFileMetaEqual`. Anything else FALSE.

## T007 - S2: the core

- `fileswnd.h`: `CFilesWindowAncestor::ZIPArchiveCacheKey` (`CSalHeapString`; `fileswnd.h` now
  includes the header-only `salheapstr.h`), `GetArchiveCacheKey(key, reserve)` (the stored key, or -
  when `SetArchiveCacheKey109` ran out of memory - the key built from `ZIPArchive`, the same on every
  use), `TakeArchiveCacheKey`; `SetZIPArchive` forgets the key (`fileswn1.cpp`).
- `fileswn2.cpp` `SetArchiveCacheKey109`, called by `ChangePathToArchive` right after
  `SetZIPArchive` / date / size: the own key; if the other panel shows an archive with equal size and
  time (`ZIPArchiveSize`, `ZIPArchiveDate`) under a different key, both identities are read
  (`SalGetFileIdentity(..., volumeTraits = TRUE)`) and on `SalArchiveSharesCacheKey` the other
  panel's key is taken. (After the review: also when the keys are EQUAL - `SalArchiveCacheKeyChoice`,
  see "Independent review".) The size/time pre-filter keeps the other panel's archive untouched in the
  common case (two different archives) - it may lie on a share that stopped answering.
- `fileswn2.cpp` `PrepareCloseCurrentPath`: "the other panel shows this archive" = the two keys are
  equal (was `StrICmp` of the names, which called `ĥ.zip` and `Ĺ.zip` one archive) AND the archive
  on disk still has the size and time this panel listed (`SalGetFileAttributesEx`; else - changed or
  gone - the copies are stale and flushed; after the review: compared with the OTHER panel's listing); the flush takes key + `\`. The freshness half was added
  after the first full probe run: the author's `stale-*` rows (T009a) showed the stale copies were
  pre-existing for one path and that the first version spread them to the SUBST pair.
- `fileswn9.cpp` `OfferArchiveUpdateIfNeededAux`: flush key + `\`.
- `fileswn5.cpp` (F3) / `fileswn6.cpp` (F4): the key from `GetArchiveCacheKey`; the name passed to
  the archiver is taken after the key's own length (`dcKeyLen`), not after `strlen(GetZIPArchive())`
  (no longer equal: case folding changes UTF-8 lengths, an adopted key is another spelling).
- `cache.h`: the dead `CCacheData::NameEqual` (`StrICmp` on keys, no caller) removed; `cache.cpp`
  unchanged - keys stay byte-compared, the plug-ins' contract.

Every builder, flush and same-archive test of an archive key now goes through
`GetArchiveCacheKey` - both sides in one change (grep: no `LowerCase` copy of `GetZIPArchive()` is
left).

## T008 - S3: saltests `TestDiskCacheKey109`

The fold proven against `CompareStringOrdinal(..., TRUE)` over all 65,536 units (each unit equals its
fold; neighbours equal in a sort by that comparison have one fold; surrogates unchanged, nothing
mapped to a surrogate; `ı`, `ſ`, Kelvin not folded to ASCII); archive-name pair tables (the CP1250
collisions incl. `ĥ`/`Ĺ` - the old key merged them - NFC/NFD, look-alikes, lone surrogates; equal
pairs incl. the length-changing U+023A/U+2C65 and `Č`/`č`, which the old key kept apart); the
reserve on all three paths; the legacy tier (`C1 80 80` vs `E1 80 80`); 40,000 random string pairs
and 20,000 random byte strings: key equality == `SalNameEqualOrdinalCI`, 0 mismatches; every pair of
BMP characters the old key merged (22,497 over every non-surrogate unit on CP1250 - 108's 19,015
counted assigned characters only): 0 mismatches; the flush prefix (`p.zip\` does not take
`p.zip.zip\x.txt`, the bare key did); `Adopt` / `Swap`; the `SalArchiveSharesCacheKey` table (other
file, other volume, shadow copy, snapshot unknown, no ids, unusable ids, FAT with equal / different
metadata, invalid); real files in `%TEMP%`: another case, the 8.3 name and `\\localhost\C$` share,
another file does not. saltests **13,835 -> 13,959 / 0** (after the review **13,973**: 14 rows of
`SalArchiveCacheKeyChoice`).

## T009 - the probe on this build

`probe/diskcache_result.txt` (the build after the review): **17 PASS / 0 FAIL / 1 NOT DRIVEN**, F3/F4
retries 0 - the NOT DRIVEN row is `renet` in its first form (a network drive cannot be re-mapped
under a panel showing its root - "W:\ is invalid"; a probe defect, the row now steps off first),
re-run alone: `probe/diskcache_result_renet.txt` PASS. So every row passes: **18 / 0**. The run
before the review (16 rows) is kept as `probe/diskcache_result_prereview.txt` (16 / 0).

| Rows | Before | After |
|---|---|---|
| 5 twoarc rows | FAIL | PASS - two copies (`0/1/1/2/1/0`), each archive its own x.txt with only its own edit; F3 given the right file |
| `alias-subst`, `alias-unc` | FAIL (2 copies, 1 edit) | PASS - one copy, both edits |
| `prefix` | FAIL (1 edit) | PASS - 2 edits, `p.zip` untouched |
| `alias-ascii`, `alias-accent` x2, `alias-sfn`, `reuse`, `reuse-accent` | PASS | PASS (reuse: one copy for F3 x2 and the other panel's F3, kept when one panel leaves, removed when the second leaves) |
| `stale-same` | FAIL (old content) | PASS - both F3 given tag 9 |
| `stale-subst` | PASS | PASS (the first version: FAIL, T009a) |

## T009a - a changed archive in two panels (found by the author, fixed)

Rows `stale-same` / `stale-subst` (both panels on `t.zip` - one path / a SUBST path -, F3 in the left
panel, `t.zip` rewritten from outside with x.txt tag 9, F3 in the right, then in the left panel):

| Build | stale-same | stale-subst |
|---|---|---|
| `Debug_x64_pre109` (`probe/diskcache_result_pre109_stale.txt`) | **FAIL** - both F3 given the old tag 1 | PASS (two keys) |
| first version of 109, without the freshness test (`probe/diskcache_result_stale_firstfix.txt`) | FAIL | **FAIL** - spread by the shared key |
| this build (`probe/diskcache_result.txt`) | PASS | PASS |

The first version's full run (14 rows, before the `stale-*` rows existed) is kept as
`probe/diskcache_result_firstfix.txt` (14 / 0).

## T010 - regression (this build)

| Probe | This build | Before / recorded |
|---|---|---|
| 108 `namecoll_probe` (`regress_namecoll108_109.txt`) | 28 PASS / 2 FAIL, every verdict identical to 108's own result | 28 / 2 (108; the two FAIL rows are `hL1_zip` / `hL2_zip`, the ZIP plug-in's own matching - feature 110) |
| 108 `namecoll_probe -CacheKeyRows` (`regress_cachekey108_109.txt`) | **2 PASS / 0 FAIL** (each archive its own x.txt + one edit) | 0 / 2 on 108 and before - the defect of this feature |
| 096 `archedit_probe` (`regress_archedit096_109.txt`) | 17 of 17 UPDATED | 17 of 17 |
| 097 `arcwork_probe`, ZIP/7z subset (`regress_arcwork097_109.txt`) | PASS 120, FAIL 0 | 120 / 0 |
| 095 `longarc_probe` (`regress_longarc095_109.txt`) | PASS 60, FAIL 0 | 60 / 0 |

After the review the 108 namecoll, 108 `-CacheKeyRows`, 096 and 097 runs were repeated on the final
build (the files above; identical results to the runs before). The 095 longarc run (60 / 0) was made
on the build before the freshness test and the review fixes; both act only when BOTH panels show an
archive, which that single-panel probe never does.

## T011 - gates

| Gate | Result |
|---|---|
| Debug build (`build.cmd`) | exit 0; no warning in a changed file (`zip.cpp(5913)` C4244 pre-existing) |
| saltests | **13,973 checks, 0 failed** (13,835 before; 13,959 before the review) |
| `python tools\check_encoding.py --strict` | TOTAL: 0 |
| Full Release build (`build.cmd full release`) | BUILD SUCCEEDED, 0 errors; warnings only in files not changed by 109 (`salamdr2.cpp` C4018 x2, `zip.cpp` C4244 - recompiled because `fileswnd.h` changed); 20 plug-ins in `plugins.ver`, 189 language modules, runtime closure OK |
| Encodings | UTF-8 BOM + CRLF kept (`salunicode.cpp`, `salheapstr.h`, `salsamefile.h`, `fileswnd.h`, `fileswn1/2/5/6/9.cpp`, `cache.h`); `salunicode.h` and `saltests.cpp` stay without BOM, CRLF; `CHANGELOG.md`, `NEXT-WORK.md` CRLF; the probe ASCII + CRLF; spec files UTF-8 without BOM, LF (as 108) |
| Hidden-desktop runs | 23 runs, every one: no `tandemcommander.exe` before, registry SHA-256 `1AB614304771DBE0...` before and after (identical), nothing left running, SUBST letter removed, the probe's `net use` drive (W:) removed, fixtures under `%TEMP%\tc109\dc` removed; no existing mapping touched |

## Independent review (REJECT, one driven blocker) and the fixes

The reviewer reproduced the probe (16 / 0) and drove extra rows, all PASS on the reviewed build: a
length-changing pair `ⱥq.zip` / `ɫq.zip` with nested edits, a 343-byte archive path, two panels on one
archive with edits in each (also the same member, also SUBST / UNC), `p.zip` / `p.zip.zip`. Verified by
reading: the key rule, the 0xFF tier, the key + `\` contiguity, `dcKeyLen` in F3 / F4.

- **BLOCKER - an adopted key outlived the spelling it came from.** `SetArchiveCacheKey109` checked the
  identity only when the keys DIFFERED; an equal key was trusted. Driven (`resubst`): SUBST `T:` ->
  folder A; the right panel opens `T:\arc.zip`; the left opens `A\arc.zip` and takes the key
  `T:\ARC.ZIP`; F3 in the left; the right goes back to disk; `T:` re-pointed to folder B; the right
  opens `T:\arc.zip` (another file): its own key equals the left panel's, so F3 gave A's x.txt, and F4
  + leave packed A's member + the edit into `B\arc.zip`. Passes on pre-109 (two keys). Also reachable
  through a re-mapped network drive or a replaced hard link. **Fixed**: a pure decision
  `SalArchiveCacheKeyChoice` (`salsamefile.h`) - whenever the keys could be shared (equal, or equal
  size and time), the identities are read; share only on a certain identity, or - for EQUAL keys -
  when the two NAMES are one name and nothing says "another file" (the sharing of every release for
  one path, kept for file systems without ids); otherwise an equal key is made unique: the own key +
  `0x01` (no path holds it) + a counter, so nothing is shared and `PrepareCloseCurrentPath`'s test
  follows. Size or time different with an equal key = unique. A low-memory failure to get the other
  key = unique. saltests: 14 choice rows. Probe rows `resubst` (SUBST, the two archives given equal
  size and time, so the identity read decides) and `renet` (a `net use` drive to `\\localhost\C$\...`,
  re-mapped; natural times), on both builds: `probe/diskcache_result_pre109_review.txt` (resubst PASS
  on pre-109 - two keys there), `diskcache_result_pre109_renet.txt` PASS, this build PASS for both
  (`diskcache_result.txt`, `diskcache_result_renet.txt`). The reviewed build itself is gone (rebuilt);
  its `resubst` FAIL is the reviewer's measurement, the rule rows in saltests cover the decision.
- **SHOULD-FIX - the freshness test compared with this panel's listing**, which
  `RefreshForConfig` (`fileswn0.cpp`) and the plug-in service `RefreshPanelPath(panel, TRUE)`
  (`zip.cpp`) set to the "refresh me" marker (size -1): the forced reopen then flushed `key\` although
  nothing changed, marking a copy the OTHER panel still edits out of date - a re-F4 there before its own
  reopen extracts the member over the edit (before 109 these copies were kept). **Fixed**: the disk
  state is compared with the OTHER panel's listing (the state the kept copies come from); if that is
  the marker, with this panel's; if both are markers, the copies are kept (no information). **Not
  driven**: the one-panel trigger, Ctrl+wheel in a Thumbnails panel (`filesbx1.cpp`), reads the real
  keyboard (`GetKeyState(VK_CONTROL)`), which a hidden desktop cannot provide; the Configuration
  dialog's OK refreshes BOTH panels, so the other panel reopens and packs its edits at once (no loss
  to show); `RefreshPanelPath(force)` comes only from PictView's configuration. The deeper hole the
  reviewer named - a flush can mark a copy with a pending edit out of date at all (also after an own
  update in the other panel, every release) - is not changed here: queued in NEXT-WORK item 5 (the
  cache does not know `CFileTimeStamps`; it needs its own design).
- **NIT - `OfferArchiveUpdateIfNeeded`** (`fileswn9.cpp`) decided "the same archive in the other panel"
  by name only: now name OR equal key, so for a SUBST / UNC pair that shares copies the other panel's
  edits are packed before an archive operation too.
- **NIT - recorded**: `PrepareCloseCurrentPath` reads the archive's attributes on every leave while
  both panels show it - on a share that stopped answering that read may wait.

## Re-review after the fixes: ACCEPT

The reviewer's own `resubst` (left panel `A\arc.zip` adopting `T:\ARC.ZIP`, `T:` re-pointed, right
opens `T:\arc.zip`) now passes; `resubst-eqtime` (equal size and time forced) passes on both
builds; the same spelling `T:\arc.zip` on both sides of the re-point with different times passes
and FAILS on the build before 109 (A's member packed into B) - an old defect fixed; two panels on
one genuine archive still share (`one-diff`, `one-same`, `one-same-Lfirst`, `one-diff-reF4/reF3`,
`subst-diff`, `subst-diff-reF4`, `unc-diff-reF3`), `prefix2`, `lenpair`, `long300` pass; author's
probe 18/0; the unique key `KN` can never be matched by `K\`'s flush (code reading).
Recorded (NITs):
- **Same spelling, equal size AND equal modification time to 100 ns, re-pointed under one
  letter** (`resubst-same-eqtime`): fails identically on 109 and before - after the re-point both
  names resolve to the new file, so the identity read cannot know the left panel's listing came
  from the old one. Fix direction: store each panel's file identity when it opens the archive and
  compare the stored identities.
- **Out-of-memory fallback**: if building the unique key (or the own key) fails, the stored key
  stays empty and `GetArchiveCacheKey` builds the own key, which may equal the other panel's
  without a check. Needs a tiny allocation to fail at that moment; hardening: a "no shared key"
  state that makes F3/F4 refuse.
- WebDAV re-pointed under one letter (not driven): shared only with equal size and time, otherwise
  unique - never worse than every earlier release.

## Decisions recorded (spec.md)

- The archive's key = the file system's identity rule as a byte string (`SalNameIdentityKeyAlloc`);
  the cache keeps byte comparison (plug-in contract unchanged).
- Legacy (non-WTF-8) names keep the legacy fold, in a tier of their own (0xFF).
- One archive under two spellings: the other panel's key by file identity, only on certainty, only
  after a size/time pre-filter; an equal key is never trusted by itself (review blocker) - it is shared
  only on a certain identity or for one name with no sign of another file, else made unique.
- The flushes take key + `\`.
- Copies are kept for the other panel only while the archive keeps the size and time the other
  panel listed (this panel's own listing only when the other's is the refresh marker).

## Not driven

- A plug-in file system's cache use (FTP, demoplug): no server here; those keys are the plug-ins' own
  and `cache.cpp` is unchanged, so their behaviour cannot change (reasoned).
- Routes that hand `ChangePathToArchive` a non-canonical archive spelling (path history, a plug-in's
  `ChangePanelPath`): there the case unification of the new key applies; covered by saltests, not
  driven (Change Directory and Enter canonicalize the spelling first).
- A legacy plug-in passing a code-page archive name: saltests only.
- FAT/exFAT volumes, shadow copies, WebDAV: no such volume here; rule tests only.
- A real editor (Notepad) and real keyboard: `quickstart.md`.

## Recorded, not changed

- A case-sensitive NTFS folder (per-directory case sensitivity) holding `a.zip` and `A.zip`: one key,
  as for every identity decision of the core since 092 (`ChangePathToArchive` already treats them as
  one archive).
- `CCacheData::GetName` on an out-of-date copy deletes it and lets the caller extract the member over
  it - the mechanism behind the `prefix` loss. With the key + `\` flush it is reached only after a
  flush of the SAME archive by the other panel after it packed edits; this panel then notices the
  changed archive and reopens it, packing and releasing its own copies first (measured: copies drop
  to 0 when the other panel leaves - rows `alias-*`), so no loss was reachable in the probe; a user
  saving into the copy in the short window between the two is reasoned, not shown.
- `CCacheDirData::DetachTmpFile` still has no caller.
- `ChangeDir`'s comment says the enumerated component has the typed one's length "only the size of
  letters is changed"; for an 8.3 component it does not (reasoned from the code: its `TRACE_E`
  "unexpected situation" fires in a Debug build; the composed path is right - row `alias-sfn`).

## CLAUDE.md entry

- 109-disk-cache-archive-key: **an archive's temporary copies belong to
  that archive only.** NEXT-WORK item 5 queue entry 1 (from 108) and 092's
  "disk cache" item. The disk cache keyed an archive by its code-page
  lower-cased name (`LowerCase` on UTF-8) and compared keys with `strcmp`.
  Measured first (`research.md`), wider than recorded:
  - `ĥ.zip` / `Ĺ.zip` (CP1250 folds their bytes together) in two panels:
    one shared copy; leaving the archives packed it into BOTH (each ends
    with the first one's file + both edits); F3 in the second was given the
    first's file, also with a pending edit. ZIP and 7z, every release.
  - The flush took the bare key as a PREFIX: leaving `p.zip` flushed
    `p.zip.zip`'s copies; a copy being edited there was marked out of date
    and the next F4 (`CCacheData::GetName` -> `CleanFromDisk`) extracted
    the member over the unsaved-to-archive edit - lost silently.
  - Both panels on one archive: the copies were kept "for the other panel"
    also when a refresh reopened the archive because another program had
    changed it - F3 showed the old content (`stale-same`). The first 109
    version spread this to the SUBST pair it unifies; its own probe row
    caught it.
  - Case and 8.3 spellings already arrive canonical (`ChangeDir`
    enumerates each component); SUBST and `\\localhost\C$` gave one member
    two copies - the second update replaced the first edit.
  - **Key rule** (`salunicode.{h,cpp}`): `SalNameIdentityKeyAlloc` -
    `strcmp(key(a), key(b)) == 0` <=> `SalNameEqualOrdinalCI(a, b)`; valid
    WTF-8 through `SalNameIdentityFoldUnit` (ntdll `RtlUpcaseUnicodeChar`,
    proven equal to `CompareStringOrdinal`'s classes over all 65,536 units
    in saltests - `LCMapStringEx` upper case is linguistic and was not
    used), legacy text = 0xFF + `CharLowerA` per byte (tiers never meet).
    New byte-compared identity keys MUST use it.
  - **Core, both sides in one change**: one key per open archive
    (`CFilesWindowAncestor::ZIPArchiveCacheKey`, `GetArchiveCacheKey`,
    set by `SetArchiveCacheKey109` in `ChangePathToArchive`, forgotten by
    `SetZIPArchive`) for F3 (`fileswn5`), F4 (`fileswn6`; the archiver's
    name taken after the key's own length), both flushes (`fileswn2`
    `PrepareCloseCurrentPath`, `fileswn9`; key + `\`) and the
    "other panel shows this archive?" test (keys equal AND the archive
    still has the size/time the other panel listed). Same file under another spelling: the
    other panel's key is taken when size/time match and
    `SalArchiveSharesCacheKey` (`salsamefile.h`: equal usable ids, equal
    known snapshot, FAT also equal metadata) says one file; uncertain = own
    key. An EQUAL key is never trusted alone (review blocker: a key taken
    from `T:\arc.zip` outlived the re-pointed SUBST and shared another
    file's copies): `SalArchiveCacheKeyChoice` reads the identity whenever a
    share could happen; an equal key without certainty (other than the same
    name with no sign of another file) gets a unique suffix (0x01 + counter).
    The freshness test compares with the OTHER panel's listing (the
    refresh marker -1 of `RefreshForConfig` / `RefreshPanelPath(force)` made
    it flush a copy the other panel still edited); `OfferArchiveUpdateIfNeeded`
    takes name OR key. Queued (NEXT-WORK item 5, 2a): a flush can mark a copy
    with a pending edit out of date at all (pre-existing). `cache.cpp`
    unchanged (plug-in keys byte-compared by contract); dead
    `CCacheData::NameEqual` removed; `CSalHeapString::Adopt`/`Swap`.
  - Probe `probe/diskcache_probe.ps1` (F3 through an external viewer that
    logs what it was given; SUBST / UNC / re-pointed drive rows): 18 / 0;
    pre-109 9 / 9 (incl. `stale-same`). Regressions unchanged: 108 namecoll 28/2 (the
    known ZIP plug-in rows) and `-CacheKeyRows` now 2/0, 096 17/17, 097
    arcwork subset 120/0, 095 longarc 60/0. saltests 13,835 -> 13,973.
    Independent review: REJECT (the equal-key blocker) - fixed; re-review ACCEPT
    (left: equal size + 100 ns time under one re-pointed letter; the OOM key fallback).
    Interface stays 107, no new string, no registry change. Records:
    `specs/109-disk-cache-archive-key/fix-log.md`.
