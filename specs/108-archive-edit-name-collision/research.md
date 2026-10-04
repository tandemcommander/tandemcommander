# Research: feature 108 - edited archive members whose names collide

Measured on 2026-10-04 on this machine (Windows 11, ACP 1250, OEM 852), build before this feature
`build\tandemcommander\Debug_x64_pre108` (= `107-folder-alias-move`, HEAD 976b5531).

## 0. The route

F4 (or Enter on an associated file) inside an archive: `CFilesWindow::ExecuteFromArchive`
(`fileswn6.cpp`)

1. refuses when another item of the panel's folder has the same name by the file system's rule
   (092: `SalNameEqualOrdinalCI`; message `IDS_UNABLETOEDITDUPFILES`);
2. builds the disk-cache name: the archive's full name lower-cased by the code-page table
   (`LowerCase`), then the panel's path inside the archive and the member's name **byte for byte**;
3. `DiskCache.GetName(name, f->Name, ...)` returns the existing temporary copy or a new one,
   `<TEMP or the plug-in's root>\SALxxxx.tmp\<member name>`. A new copy goes into the first `SAL`
   folder that holds no name equal to it by the file system's rule (092, `ContainTmpName`);
4. extracts the member (`PackUnpackOneFile`), starts the editor;
5. `UnpackedAssocFiles.AddFile(archive, panel path, SAL folder, name, ...)`: TRUE -> the copy gets
   the panel's lock (`AssignName(..., ExecuteAssocEvent, ..., crtCache)`); FALSE ("already
   present") -> `DiskCache.ReleaseName(name, FALSE)` - when no lock holds the copy, the cache
   **deletes it from disk** (`CCacheData::~CCacheData` -> `CleanFromDisk`).

Leaving the archive: `CheckAndPackAndClear` drops unchanged items (096: only "not there" may drop),
shows Archive Update, and packs the rest in groups of the same folder inside the archive (`strcmp`)
and the same folder on disk (`StrICmp`) - one `PackCompress` per group, names from
`FileTimeStampsEnum2`.

## 1. The premise, measured: right, and the loss is larger

`AddFile`'s "already present" test was `StrICmp(FileName) == 0 && StrICmp(SourcePath) == 0` - the
code-page byte fold on UTF-8. On CP1250 `ĥ.txt` (C4 A5) and `Ĺ.txt` (C4 B9) fold together (0xA5
`Ą` -> 0xB9 `ą`). The cache keys of the two members differ (member name byte for byte), the copies
differ (`SAL921.tmp\ĥ.txt` and `SAL921.tmp\Ĺ.txt` - two files, the file system keeps them apart),
but `AddFile` called the second "already present". Then `ReleaseName` deleted the second copy right
after the editor started: the probe's editor (`cmd /c echo edited108>>"$(FullName)"`) wrote into
a NEW file of 11 bytes (marker only, the member's content gone); nobody watched it; the edit was
never offered for the update. A real editor races the same deletion (it may open the file before
or after it).

`probe/collision_set.py` (`collision_set_cp1250.txt`): on CP1250 the byte fold merges **19,015**
pairs of BMP characters that the file system keeps apart - 275 two-byte (among them the Czech
`Í`/`Ý`, `ú`/`ê`, `ž`/`ż`, `ť`/`Ź`, `Č`/`Ĝ`), 18,740 three-byte (7,564 CJK ideograph pairs,
e.g. U+4E5D/U+4E4D), 40 Cyrillic (`м`/`о`, `У`/`г`, ...). Names collide when they differ only in
such positions.

`probe/namecoll_probe.ps1` on `Debug_x64_pre108` (`probe/namecoll_result_pre108.txt`), F4 on both
members, leave, Update All, every question answered Yes, archive read back by `probe/arcfix.py`
(Python `zipfile` / `7z.exe`, each member's original content tagged):

| rows | ZIP | 7z |
|---|---|---|
| pairs that fold together: `ĥ`/`Ĺ`, `Ítem`/`Ýtem`, `ž`/`ż`, U+4E5D/U+4E4D, `м`/`о`, `ĥ`/`Ĺ` in `složka/` | FAIL x6: **the second member is gone from the archive**, the first carries its edit | FAIL x6: the second edit is lost, the member unchanged |
| one member of such a pair edited (`hL1`, `hL2`) | FAIL x2: **the other member is gone** | PASS |
| NFC / NFD pair (`é` / `e` + U+0301) | PASS | PASS |
| pairs equal by the file system's rule in one folder (`Č`/`č`, `A`/`a`, U+023A/U+2C65) | PASS (F4 refused twice, archive unchanged) | PASS |
| one member edited twice | PASS | PASS |
| one member through `Change Directory <arc>\DIR` and through the listed `Dir` | FAIL: two copies, two packs, one edit lost | FAIL (the same) |
| 096 control, `článek.txt` | PASS | PASS |

So: 12 of 12 pair rows and 2 of 2 typed-spelling rows fail; 7-Zip loses an edit, ZIP loses a
member.

## 2. Why ZIP loses a whole member - the plug-in's own matching (not this feature)

`zip/add.cpp` (the update of an existing archive) matches every file being added against every
central-directory entry with `CompareString(LOCALE_USER_DEFAULT, NORM_IGNORECASE, ...)` - the ANSI
`CompareStringA` on the UTF-8 names, i.e. a linguistic, case-insensitive comparison of the bytes
read as CP1250 characters. Packing `ĥ.txt` matches both `ĥ.txt` and `Ĺ.txt`: two "Confirm File
Overwrite" questions (measured, both answered Yes), both entries go to `DelFiles`, one file is
added. The same code serves F5 / drag & drop into a ZIP archive (`del.cpp:62` - delete - and
`extract.cpp:329` - extract selection - use the same comparison). The 7zip plug-in compares UTF-16
names with its own case folding (`7zclient.cpp MyStringCompareNoCase`): no false match measured.
Not changed by this feature (a plug-in's identity rule, a route of its own); queued as the first
entry of NEXT-WORK item 5. With this feature both edits of a pair are packed in ONE call when the
two copies share one `SAL` folder: both entries are deleted and both edited files added - each member
ends up with its own edit (rows `hL_zip` ... PASS), but the questions still pair the wrong files.
An edit of one member of such a pair still loses the other one, and so does a pair whose copies
landed in two `SAL` folders (packed in two calls - the independent review's `split_zip` row: edit
`d/Ĺ.txt`, then `ĥ.txt`, then `Ĺ.txt`; the last copy needs a new folder, and the second call deletes
the already-packed `ĥ.txt`; both builds). For 7z both edits are always packed back.

## 3. The inverse: one member under two spellings

The panel keeps the path inside the archive as typed (`ChangePathToArchive`: `SetZIPPath(path)`);
the listing (`CSalamanderDirectory`) finds folders by the archive's rule - case-sensitive for a
Unix ZIP (`SALDIRFLAG_CASESENSITIVE`, set by the ZIP plug-in), the byte fold otherwise. So
`Change Directory` to `arc.zip\DIR` shows the stored `Dir` and the panel's path is `DIR`. The
disk-cache name and `AddFile`'s folder used the typed spelling: F4 through `DIR` and F4 through the
listed `Dir` gave the one member two keys, two copies (`SAL575.tmp\x.txt`, `SALA14.tmp\x.txt`), two
items, two packs - the second ("overwrite file 32 bytes with 32 bytes?") replaced the first edit.
Disk paths do not have this (092's focus probe F1p: entering a disk folder corrects the path's
spelling to the disk's).

Within one folder, two members equal by the file system's rule cannot both be edited (step 1), and
their copies could not coexist in one `SAL` folder; in two different folders they get two `SAL`
folders. So apart from the typed spelling, "the same member" and "the same copy" coincide.

## 4. Look-ups of the class, and the disk cache (recorded)

- `AddFile` `strcmp(zipFile, ZIPFile)`: the panel's archive name, unchanged while the panel stays in
  the archive (`ChangePathToArchive` keeps it when the new name is the same file by 092's rule);
  byte-exact is right.
- `CheckAndPackAndClear`: `SalFindFirstFile` (096); grouping - see the decision in spec.md.
- `Remove` / `CopyFilesTo` / `AddFilesToListBox`: by index; no comparison.
- **Temporary copies**: two members never share a file (`ContainTmpName` compares by the file
  system's rule since 092); measured: `ĥ.txt` and `Ĺ.txt` sit as two files in one `SAL` folder,
  the NFC/NFD pair too.
- **Disk-cache keys** (separate item, not touched): member part byte for byte - two members never
  share a key. The ARCHIVE part is the code-page lower-cased name, compared with `strcmp` and
  flushed by that prefix (`fileswn2.cpp` leaving the archive, `fileswn9.cpp` after an update).
  Consequence, measured (`namecoll_probe.ps1 -CacheKeyRows`, `probe/cachekey_result.txt` and
  `cachekey_result_pre108.txt`, the same on both builds): two archives whose NAMES fold together
  (`ĥ.zip`, `Ĺ.zip` in one folder) share the keys of their members - F4 on `x.txt` of `ĥ.zip` in
  the left panel, then F4 on `x.txt` of `Ĺ.zip` in the right panel opened the FIRST archive's copy
  (one `SAL` file with both edits), and leaving `Ĺ.zip` packed that copy into it: `Ĺ.zip\x.txt`
  now holds `ĥ.zip`'s content, without any question beyond the usual update. ZIP and 7z. Also the "is the other
  panel on the same archive?" test before the flush (`fileswn2.cpp`, `StrICmp`) folds bytes.
- `AddFile` returns FALSE also on low memory; the caller then releases the copy the editor is using
  (pre-existing; rare; recorded).
- `CSalamanderDirectory` merges two FOLDERS whose names fold together (`ĥ/`, `Ĺ/`) into one listing
  folder (NEXT-WORK item 5, recorded by 092) - F4 then names a member that does not exist.
- The F3 viewer builds its own cache name from the typed path (`fileswn5.cpp`); after an edit through
  the stored spelling it opens a fresh copy of the archive's member (as the build before did for a
  view through another spelling).
