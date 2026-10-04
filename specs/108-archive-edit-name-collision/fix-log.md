# Fix log: feature 108 - every edited archive member is packed back as itself

Branch `108-archive-edit-name-collision` (from `107-folder-alias-move`, HEAD 976b5531). Pre-change
build preserved as `build\tandemcommander\Debug_x64_pre108` (incremental build of HEAD first - no
change - then copied). All GUI runs on the hidden desktop (`tools\run_on_hidden_desktop.ps1`), each
wrapped: no `tandemcommander.exe` running, `HKCU\Software\Tandem Commander` exported before,
compared after - SHA-256 prefix `1AB614304771DBE0` before and after every run (the probes also
back up / restore / verify the key themselves). Scratch under `%TEMP%\tc108\`.

## T002/T003 - measured first

Route and analysis: `research.md`. The collision set of this code page:
`probe/collision_set.py` -> `probe/collision_set_cp1250.txt` (19,015 BMP pairs that the old byte
fold merged and the file system keeps apart; 275 two-byte, 18,740 three-byte).

Probe `probe/namecoll_probe.ps1` (F4 with `cmd /c echo edited108>>"$(FullName)"` as the editor,
leave the archive, Update All, every question Yes) + `probe/arcfix.py` (makes the archives - ZIP by
Python `zipfile`, 7z by `7z.exe` + `7z rn`, because NTFS cannot stage a case-only pair - and reads
them back; each member's original content carries its number, so "which member got which content"
is read from the archive itself).

`Debug_x64_pre108` (`probe/namecoll_result_pre108.txt`): **14 PASS / 16 FAIL**.
- the six pair kinds that fold together (`ĥ`/`Ĺ`, `Ítem`/`Ýtem`, `ž`/`ż`, U+4E5D/U+4E4D, `м`/`о`,
  `ĥ`/`Ĺ` in `složka/`): ZIP x6 - the second member is **gone** from the archive; 7z x6 - the
  second edit lost. The second copy: `SAL921.tmp\Ĺ.txt` of 11 bytes (marker only) - the disk cache
  deleted the extracted copy when `AddFile` called it "already present", the editor created a new
  file nobody watched.
- one member of a pair edited (`hL1`, `hL2`): ZIP - the other member gone (the ZIP plug-in's own
  matching, `research.md` 2); 7z PASS.
- `typed` (Change Directory `<arc>\DIR`, F4; Backspace, Enter on `Dir`, F4): two copies
  (`SAL575.tmp\x.txt`, `SALA14.tmp\x.txt`), two packs, one edit lost - ZIP and 7z.
- PASS on that build: NFC/NFD pair, the three pairs equal by the file system's rule (F4 refused
  twice with "Name of this file is used for more than one file in archive", archive unchanged), one
  member edited twice, the 096 control `článek.txt`.

The premise was right; the consequence is worse than "the edit may be dropped": with ZIP a whole
member disappears.

A first run had two probe defects (a PowerShell hashtable is case-insensitive - `A.txt`/`a.txt`
counted as a duplicate; PowerShell variable names are case-insensitive - `$Cc`/`$cc` were one
variable, so the "case pair" was `č`/`č`) and a title check that did not fit a typed path (the
title shows only the last folder); fixed, the baseline re-run in full (the file above). The
`-CacheKeyRows` switch (row `twoarc`) and `arcfix.py`'s optional `first` tag were added after that
re-run; the default rows are unchanged by them.

## T005 - S1: the rule (`src/common/salarcedit.h`, header-only, pure on 092's helpers)

- `SalEditedCopyIsSame(sourcePath1, fileName1, sourcePath2, fileName2)`: the same temporary copy -
  `SalPathEqualOrdinalCI` on the folders, `SalNameEqualOrdinalCI` on the names.
- `SalEditedCopiesPackTogether(zipRoot1, sourcePath1, zipRoot2, sourcePath2)`: one packer call -
  the folder inside the archive byte for byte (as before: the packer writes what it is given), the
  folder on disk by the rule.
- `SalArcTakeStoredSpelling(stored, storedLen, typed, typedLen)`: a typed folder component is
  replaced by the listing's stored name when they are one name by the rule and of equal length.

## T006 - S2: `salamdr3.cpp`

`CFileTimeStamps::AddFile` "already present" by `SalEditedCopyIsSame` (was `StrICmp` x2);
`CheckAndPackAndClear` grouping by `SalEditedCopiesPackTogether` (was `strcmp` + `StrICmp`). The
identity is the temporary copy: the disk cache gives two members two files (092's
`ContainTmpName`) and one member one file, so "same copy" = "same member" - except for a typed
folder spelling (T007).

## T007 - S2: `fileswn6.cpp` / `fileswn5.cpp`

`GetZIPPathAsStored108(archiveDir, zipPath, stored)` (declared in `fileswnd.h`): the panel's path
inside the archive with each component the listing (`CSalamanderDirectory::GetUpperDir`) stores in
another case replaced by the stored spelling (`SalArcTakeStoredSpelling`); a component found only
through the byte fold (two folders the listing merges) or not found stays as typed.
`ExecuteFromArchive` uses it for the disk-cache name, the name given to the archiver
(`nameInArchive`) and `AddFile`'s folder - so the pack-back goes into the stored folder, never into a
new `DIR` spelling. `ViewFile` (F3) builds its cache name with it too, so F3 and F4 keep sharing one
copy as before (without it F3 through a typed spelling would have opened a fresh copy beside the one
being edited). The panel's own path (title, history) is unchanged.

## T008 - S3: saltests `TestArchiveEdit108`

Pair tables (eight different, four equal) against the rule; on CP1250 the old fold's six collisions
asserted; folder spellings (case, trailing backslash, accented plug-in cache roots); grouping; the
stored-spelling rule; every pair also created on NTFS in `%TEMP%` - "two files" must equal "not the
same copy" (U+023A/U+2C65 confirmed one file on NTFS). saltests **13,756 -> 13,835 / 0**.
`salarcedit.h` listed in `saltests.vcxproj` beside the other header-only rules.

## T009 - the probe on this build

`probe/namecoll_result.txt` (the final build, with the F3 change and `SalArcTakeStoredSpelling`):
**28 PASS / 2 FAIL / 0 NOT DRIVEN**, F4 retries 0 (an earlier run on the first fix - `AddFile`,
grouping, stored spelling in F4 only - gave the same 28 / 2).

| rows | before | after |
|---|---|---|
| 12 pair rows (6 kinds x ZIP/7z) | 12 FAIL (ZIP member gone / 7z edit lost) | 12 PASS - two copies in one `SAL` folder, both tracked, one packer call, each member its own content + one edit (for ZIP only because the copies share a folder - see below) |
| `hL1_7z`, `hL2_7z` | PASS | PASS |
| `hL1_zip`, `hL2_zip` | FAIL | **FAIL** - the ZIP plug-in's matching (not this feature; queued) |
| `typed_zip`, `typed_7z` | FAIL (two copies, one edit lost) | PASS - one copy, `Dir/x.txt` with both edits, no `DIR` entry |
| NFC/NFD, three refused pairs, same member twice, `článek.txt` | PASS | PASS |

For 7z both edits of a pair are packed back. For ZIP both are packed back **only when the two
copies share one `SAL` folder** (the probe's pair rows): then they reach the plug-in in ONE call, it
deletes both entries (two overwrite questions, each pairing a member with the other's file -
answered Yes) and adds both files. Otherwise the ZIP plug-in's own name matching (queued, NEXT-WORK
item 5 entry 2) can still lose one: the independent review drove `split_zip` - edit `d/Ĺ.txt`, then
root `ĥ.txt`, then root `Ĺ.txt`; the third copy lands in a new `SAL` folder (the first one already
holds an `Ĺ.txt`), the two root edits go to the plug-in in two calls (grouping by folder on disk),
and its `CompareStringA` matching deletes the already-packed `ĥ.txt` - the member disappears (the
same on `Debug_x64_pre108`; `split_7z` passes on 108). Answering *Skip* to a question that pairs
the wrong files can also lose a member. The plug-in defect, queued (feature 110).

Finding measured by the same probe (`-CacheKeyRows`, `probe/cachekey_result.txt` and
`cachekey_result_pre108.txt`, identical on both builds - not fixed, the disk-cache keys are a
separate item): `ĥ.zip` and `Ĺ.zip` in one folder, F4 on `x.txt` of the first in the left panel,
F4 on `x.txt` of the second in the right panel: the second F4 opened the FIRST archive's copy
(`SAL5F0.tmp\x.txt`, marker x2 after both edits), and leaving the second archive packed it into
`Ĺ.zip` - `Ĺ.zip\x.txt` now holds `ĥ.zip`'s content. Silent, ZIP and 7z.

## T010 - regression (this build)

| probe | result | build before / recorded |
|---|---|---|
| 096 `archedit_probe` (`regress_archedit096_108.txt`) | 17 of 17 UPDATED | 17 of 17 (`096/probe/archedit_result_fixed.txt`), row for row identical |
| 097 `arcwork_probe`, ZIP/7z subset (`regress_arcwork097_108.txt`: zipU200, zipL300A, zipA5000, zipE5000, zipC200, 7zU200, 7zA5000, 7zC200) | PASS 120, FAIL 0 | PASS 120 (106, 107) |
| 106 `packself_probe` (`regress_packself106_108.txt`) | PASS 70, FAIL 0, NOT DRIVEN 4 | the same (107) |
| 092 `focus_probe` old = `Debug_x64_pre108`, new = this build (`regress_focus092_108.txt`) | new 10/10 PASS; old identical to new | its 3 "UNEXPECTED for the old build" rows are 092's fixed defects, already in the pre-108 build (as in 103) |

## T011 - gates

- Debug build (incremental) 0 errors; the only warning is the pre-existing `zip.cpp(5913)` C4244
  (recompiled because `fileswnd.h` changed).
- saltests 13,835 / 0.
- `python tools\check_encoding.py --strict`: TOTAL 0.
- Full Release build (`build.cmd full release`): BUILD SUCCEEDED, 0 errors (the same `zip.cpp`
  warning), 20 plug-ins registered, 189 language modules, runtime closure OK.
- Encoding of touched sources checked with Python: UTF-8 BOM + CRLF kept (`salamdr3.cpp`,
  `fileswn5.cpp`, `fileswn6.cpp`, `fileswnd.h`; new `salarcedit.h` BOM + CRLF); `saltests.cpp` stays
  without BOM, CRLF; probe scripts ASCII + CRLF.

## Decisions recorded (spec.md)

- The identity of an edited member = its temporary copy, by the file system's rule.
- Members equal by that rule in one folder stay refused for editing (092's message) - no edit can be
  lost; their copies could not coexist in one folder and the packers match case-insensitively.
- A typed folder spelling is mapped to the listing's stored spelling in the edit and view routes
  only; the panel keeps the typed path.
- The ZIP plug-in's update matching and the disk-cache archive key are not changed here (queued).

## Not driven

- A real editor (Notepad) racing the cache's deletion on the build before: the probe's editor writes
  at once; the outcome for a real editor depends on timing (reasoned in `research.md` 1). The
  manual steps are in `quickstart.md`.
- F3 after F4 through two spellings of the folder (the `ViewFile` change): one shared copy is
  reasoned from the code (the same `GetZIPPathAsStored108` name in both), not driven - the probe
  cannot read what the viewer shows.
- A Unix ZIP (case-sensitive listing) with a typed spelling: the listing finds no folder in another
  case there, so the spelling cannot differ (rule tested only).
- A plug-in with its own cache root (`GetCacheInfo`): the rule covers it (saltests); no such
  plug-in is enabled in the default build for ZIP / 7z.
- Code pages other than 1250: other pairs collide there (the rule does not depend on the code page;
  `collision_set.py` prints the set of any machine).

## Recorded, not changed

- **The disk cache keys an archive by its code-page lower-cased name** - two archives whose names
  fold together share their members' cache entries: F4 in the second opens the first's copy (F3
  uses the same key - reasoned),
  and an edit is packed into the wrong archive (measured above, both builds). Also the "other panel
  on the same archive?" test before the flush (`fileswn2.cpp`, `StrICmp`). Queued (NEXT-WORK item 5).
- **The ZIP plug-in matches added files against existing entries with `CompareStringA` +
  `NORM_IGNORECASE` on UTF-8 names** (`zip/add.cpp`; also `del.cpp:62`, `extract.cpp:329`): adding
  `ĥ.txt` replaces `Ĺ.txt` too, after an overwrite question - an edit of one member of such a pair,
  or an F5 of such a file into the archive, deletes the other member. Queued.
- `AddFile` returning FALSE on low memory makes the caller release the copy the editor is using
  (pre-existing, rare).
- `CSalamanderDirectory` merges folders whose names fold together (NEXT-WORK item 5, from 092).

## Independent review (ACCEPT, no code change) - records corrected

The reviewer reproduced the 30 rows (28 / 2) and drove extra rows, all PASS on this build: a Unix
ZIP with `Dir` and `DIR` folders (both edited, not mapped - the listing is case-sensitive there),
typed `DIR\sub` against stored `Dir\Sub` (ZIP and 7z), three edits including a pair, a 316-byte
archive path with the pair, merged folders of a DOS ZIP refused.

- **SF1/SF2 (records over-claimed for ZIP)**: the CHANGELOG entry, the explanation of the ZIP pair
  rows (T009) and the proposed CLAUDE.md text said both edits are packed back without condition.
  Corrected: for 7z both are packed back; for ZIP only when the two copies share one `SAL` folder -
  the reviewer's `split_zip` row (above, T009) loses a member on this build and on the build before;
  NEXT-WORK item 5 entry 2 says so too.
- **NIT 3 (recorded)**: `GetZIPPathAsStored108` with a plug-in that extracts case-sensitively under
  a case-insensitive listing: tar (`plugins/tar/untar.cpp:330` compares with `strcmp`, its listing is
  not marked case-sensitive). A Linux tarball with `Dir/a.txt` and `DIR/b.txt` shows one merged
  `Dir`; before 108, typing `arc.tar\DIR` + F3 on `b.txt` asked the plug-in for `DIR\b.txt` (worked),
  now for `Dir\b.txt` (not found). Opening from the listing (Enter on `Dir`) failed already before.
  108 fixes the commoner case (a typed `DIR` when only `Dir` exists); the merged-folder case belongs
  to the `CSalamanderDirectory` item.
- **NIT 4 (recorded)**: the stored-spelling rule for accented case pairs (`Č`/`č`) never triggers in
  practice: the byte-fold listing never matches such a typed path (`C4 8C` and `C4 8D` fold apart), so
  the folder is not found at all - the folder look-up in the listing is part of the
  `CSalamanderDirectory` item. The rule is exercised by saltests only for that kind; the ASCII case
  (`DIR`/`Dir`) is the one driven.

## CLAUDE.md entry

Proposed for "Recent Changes" (plain text):

- 108-archive-edit-name-collision: **edited archive members whose names
  collide are tracked and packed back apart** (for ZIP see the plug-in
  caveat below). NEXT-WORK item 5 (left by 092), measured first
  (`research.md`): `CFileTimeStamps::AddFile` (`salamdr3.cpp`) called two
  members "already present" when their UTF-8 names fold together in the code
  page (CP1250: `ĥ`/`Ĺ`, `Í`/`Ý`, `ž`/`ż`, U+4E5D/U+4E4D, `м`/`о` - 19,015
  BMP pairs, `probe/collision_set.py`); the caller then released the second
  member's temporary copy, so the disk cache deleted it under the editor and
  the edit was never offered for the update. 7z lost the edit; ZIP lost the
  whole second MEMBER, because the ZIP plug-in's update matching
  (`CompareStringA` + `NORM_IGNORECASE` on UTF-8, `zip/add.cpp`) replaced it
  after an overwrite question. The inverse was real too: Change Directory to
  `arc.zip\DIR` (stored `Dir`) gave one member two copies through the two
  spellings and the second pack replaced the first edit.
  - **Rule** (`src/common/salarcedit.h`, header-only on 092's helpers): an
    edited member = its temporary copy, folder + name by the file system's
    rule (`SalEditedCopyIsSame`); one packer call = the same folder in the
    archive byte for byte + the same folder on disk by the rule
    (`SalEditedCopiesPackTogether`); the disk cache already gives two members
    two files and one member one file (092's `ContainTmpName`). Result: for
    7z both edits of a pair are packed back; for ZIP only when the two
    copies share one temporary folder - otherwise the ZIP plug-in's own name
    matching can still lose one (review row `split_zip`, also before 108).
  - **Stored spelling**: `GetZIPPathAsStored108` (`fileswn6.cpp`, declared in
    `fileswnd.h`) maps each typed folder of the panel's archive path to the
    listing's stored name when they are one name by the rule
    (`SalArcTakeStoredSpelling`); used by `ExecuteFromArchive` (cache name,
    archiver name, `AddFile` folder - packing never creates a `DIR` spelling)
    and by `ViewFile` (F3 keeps sharing F4's copy). The panel keeps the typed
    path. A folder matched only by the byte fold (merged by the listing)
    stays as typed. Trap (review NIT 3): tar extracts case-sensitively under
    a case-insensitive listing - a typed `arc.tar\DIR` over merged `Dir`/`DIR`
    folders now asks for `Dir\b.txt` (worked before only by luck).
  - Kept: two members equal by the rule in one folder stay refused for F4
    (092's message) - nothing can be lost there.
  - **Not fixed, queued (NEXT-WORK item 5; next 109, then 110)**: 109 - the
    disk cache keys an ARCHIVE by its code-page lower-cased name -
    `ĥ.zip` and `Ĺ.zip` share their
    members' copies; F4 in the second (other panel) opened the first's copy
    and the update packed it into the second archive, silently (measured,
    `-CacheKeyRows`, both builds); 110 - the ZIP plug-in's name matching
    (add, delete, extract) - editing one member of such a pair, packing the
    two in separate calls, or F5 of such a file into the archive, deletes the
    other member after an overwrite question.
  - Review ACCEPT (no code change); its SF1/SF2 corrected the ZIP claims in
    the records.
  - Probe `probe/namecoll_probe.ps1` + `arcfix.py` (archives read back by
    Python `zipfile` / `7z.exe`): 28 / 2 (the two ZIP single-edit rows, the
    plug-in), pre-108 14 / 16. Regressions unchanged: 096 17/17, 097 arcwork
    subset 120/0, 106 packself 70/0/4, 092 focus 10/10. saltests 13,756 ->
    13,835. Interface stays 107, no new string, no registry change. Records:
    `specs/108-archive-edit-name-collision/fix-log.md`.
