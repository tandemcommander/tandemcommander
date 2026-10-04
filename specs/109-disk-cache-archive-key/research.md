# Research: feature 109 - the disk cache's archive key

Measured on 2026-10-04 on this machine (Windows 11, ACP 1250), build before this feature
`build\tandemcommander\Debug_x64_pre109` (= `108-archive-edit-name-collision`, HEAD 8f673f3c; an
incremental build of HEAD changed nothing, then the tree was copied without `Intermediate`).

## 0. Every place that builds, compares or flushes a disk-cache key

The cache (`cache.{h,cpp}`, `CDiskCache` -> `CCacheDirData` per `SAL<hex>.tmp` folder ->
`CCacheData` per copy) knows nothing about archives. A key ("name") is an opaque string:

| Where | What it does with the key |
|---|---|
| `CCacheDirData::GetNameIndex` | binary search in a list sorted by `strcmp` - every look-up (`GetName`, `NamePrepared`, `AssignName`, `ReleaseName`, `FlushOneFile`, `Release`) |
| `CCacheDirData::FlushCache(name)` | from the search position, every key with `strncmp(key, name, strlen(name)) == 0` - a PREFIX flush: unreferenced copies deleted, referenced ones marked out of date |
| `CCacheData::NameEqual` | `StrICmp` on keys - **no caller** (dead) |
| `CCacheData::TmpNameEqual`, `ContainTmpName` | the temporary FILE names, by the file system's rule since 092 - not keys |
| `CCacheDirData::DetachTmpFile` | by temporary file name; **no caller** (092) |

The keys of an ARCHIVE's members are built by the core only:

| Site | Key |
|---|---|
| `fileswn5.cpp` `ViewFile` (F3, Enter on a viewed file) | `LowerCase(archive)` + `\` + folder inside (108: stored spelling) + `\` + name [+ `:0x<ptr>` for byte-identical duplicate names] |
| `fileswn6.cpp` `ExecuteFromArchive` (F4, Enter on an associated file) | `LowerCase(archive)` + `\` + folder + `\` + name (shared with F3 since 108) |
| `fileswn2.cpp` `PrepareCloseCurrentPath` (leaving / reopening the archive) | `FlushCache(LowerCase(archive))` unless no file changed and the other panel shows "the same archive" - decided by `StrICmp(other archive, this archive)` |
| `fileswn9.cpp` `OfferArchiveUpdateIfNeededAux` (before an archive operation, after packing edits back) | `FlushCache(LowerCase(archive))` |

`LowerCase` is the code-page table of `str.cpp` (`CharLowerA` per byte) applied to UTF-8 bytes; the
key is then compared byte for byte. Both builders also take the name passed to the archiver as
`key + strlen(archive) + 1` - an offset that assumes the key's archive part has the archive name's
length (true only for a per-byte map).

Other users of the cache, each with its own key namespace (not archives, unchanged):
`mainwnd4.cpp` (user-menu batch file, unique key), `zip.cpp` `ViewFileInPluginViewer` (`"ViewFile
%X"`), and the plug-in services `GetFileFromCache`, `MoveFileToCache`, `RemoveOneFileFromCache`,
`RemoveFilesFromCache`, `CSalamanderForViewFileOnFS::AllocFileNameInCache` - keys built by the
plug-ins (FTP: `ftp://user@host/...`, demoplug: `dfs:...`). Their contract (`spl_gen.h`): "the name
is compared case-sensitively; a plug-in that needs case-insensitivity must convert all names, e.g.
to lower case". Plug-ins may pass code-page text; `cache.cpp` treats it as bytes. The 7-Zip plug-in
uses only `ViewFileInPluginViewer` (unique key).

**Persistence**: none. Keys and records live in memory; the folders are `SAL<hex>.tmp` (a number),
and a start-up after a crash only offers to delete leftover `SAL*.tmp` folders
(`ClearTEMPIfNeeded`). So the key's form can change freely - every builder and flusher just has to
use the same one.

## 1. The premise, measured: right, and worse

`probe/diskcache_probe.ps1` (hidden desktop; ZIP by Python `zipfile`, 7z by `7z.exe` -
`108/probe/arcfix.py`; F4 = `cmd /c echo edited109>>"$(FullName)"`; F3 = an external viewer
`cmd /c type "$(FullName)">>view.log`, so the probe reads what each F3 was GIVEN), on
`Debug_x64_pre109` (`probe/diskcache_result_pre109.txt`): `ĥ.zip` (x.txt tag 1) and `Ĺ.zip` (tag 2)
in one folder, C4 A5 / C4 B9 - CP1250 folds 0xA5 to 0xB9:

| Row | Result before 109 |
|---|---|
| `twoarcF4_zip`, `twoarcF4_7z`: F4 in `ĥ` (left), F4 in `Ĺ` (right), leave right, leave left | ONE copy (`SAL...\x.txt`, tag 1, both markers). Leaving `Ĺ` packed it into `Ĺ` (its x.txt replaced by `ĥ`'s); leaving `ĥ` packed it into `ĥ` too: **both archives end with tag 1 + both edits** |
| `twoarcF3_zip`, `twoarcF3_7z`: F3 in each | the second F3 was given **`ĥ`'s x.txt** (tag 1) |
| `twoarcF4F3_zip`: F4 in `ĥ`, F3 in `Ĺ` | F3 was given `ĥ`'s x.txt **with the pending edit** |

Why both archives: the right panel's flush (files changed) marked the shared copy out of date but
it stays on disk while the left panel references it; the left panel's own update then found it
changed against its own time stamp and packed it.

## 2. A third defect of the same key: the prefix flush

The flush takes the bare archive key as a prefix, so leaving `p.zip` flushes every key that
STARTS with `c:\...\p.zip` - also `p.zip.zip\x.txt`, `p.zip.bak\...`, `p.zipx\...`. A referenced copy
is marked out of date; the next `GetName` on an out-of-date copy deletes it (`CCacheData::GetName`:
`Prepared = FALSE` -> `CleanFromDisk`) and the caller extracts the member again into the same name.
Row `prefix` (F4 on `p.zip.zip\x.txt` in the left panel, `p.zip` entered and left in the right
panel, F4 on the same member in the left panel again, leave, update): **1 edit packed, the first
edit gone** - deleted together with the copy and the member extracted over it, without any message
(every release; any two archives where one name is the other's name plus a suffix).

## 3. The inverse: one archive through two spellings

| Row | Before 109 |
|---|---|
| `alias-ascii` (`arc.zip` / `ARC.ZIP`) | PASS - the lower-cased keys are equal |
| `alias-accent` (`Čarc.zip` / `čARC.zip`, ZIP and 7z), `reuse-accent` | PASS - although the old keys differ (CP1250 folds C4 8C and C4 8D to C4 9C / C4 9D): Change Directory gives the archive its on-disk spelling. `CFilesWindow::ChangeDir` (`fileswn3.cpp`) replaces every component of a typed path by the name `FindFirstFile` returns; the panel then shows "Archive ...\Čarc.zip is about to close" |
| `alias-sfn` (8.3 `ALIAS-~3\LONGAR~1.ZIP`) | PASS - the same enumeration expands 8.3 components |
| `alias-subst` (`T:\arc.zip`, SUBST to the folder) | **FAIL**: two copies; the right panel's update packed its copy, the left one's then replaced it after "overwrite?": 1 edit of 2 |
| `alias-unc` (`\\localhost\C$\...\arc.zip`) | **FAIL**: the same |

Enter on an archive in a disk panel uses the listing's name - also the on-disk spelling. Routes that
hand `ChangePathToArchive` a name directly (path history, a plug-in's `ChangePanelPath`) keep the
given spelling; there the case unification of the new key matters.

## 3a. One key kept "for the other panel" outlives a changed archive

`PrepareCloseCurrentPath` keeps the copies when the other panel shows the same archive and no edited
file was packed. The refresh that reopens an archive after another program changed it
(`ChangePathToArchive`, `forceUpdate`: date or size differ -> `_REOPEN_ARCHIVE`) goes through the
same decision, with the panel's listed date still the old one. Rows `stale-same` / `stale-subst`
(both panels on `t.zip`, F3 in the left one, `t.zip` rewritten from outside with x.txt tag 9, F3 in
the right and the left panel), `probe/diskcache_result_pre109_stale.txt`: `stale-same` **FAIL** - both
F3 given the old tag 1 (every release); `stale-subst` PASS (two keys, each flushed). On the first
version of 109 (key shared through the SUBST path, `probe/diskcache_result_stale_firstfix.txt`) both
FAIL - the alias unification would have spread the stale copies. Hence the freshness test in the
final change.

## 4. The rule

092's contract: two names are one name when `SalNameEqualOrdinalCI` says so (valid WTF-8:
`CompareStringOrdinal(..., TRUE)`, the operating system's upper-case table per UTF-16 unit; text
that is not WTF-8: the legacy byte fold; the two never equal). A KEY for that relation:

- per unit, the operating system's upper-case table: ntdll's `RtlUpcaseUnicodeChar` (looked up by
  `GetProcAddress`; documented in the WDK). It is not assumed to equal `CompareStringOrdinal`'s
  classes - saltests PROVES it over all 65,536 units: every unit compares equal to its fold, and in
  the units sorted by `CompareStringOrdinal`, neighbours that compare equal have one fold; together:
  `fold(u) == fold(v)` <=> equal. It also keeps surrogates as they are and maps nothing to a
  surrogate, so re-encoding the folded units as WTF-8 is one-to-one. `LCMapStringEx(...,
  LCMAP_UPPERCASE)` was not used: it is linguistic (it may map `ı` to `I`, which the file system keeps
  apart - 092 measured that no non-ASCII character equals an ASCII letter for the OS).
- legacy text: `0xFF` (a byte valid WTF-8 never contains) + `CharLowerA` per byte. Without the
  marker, CP1250's fold turns the invalid `C1 80 80` into the valid `E1 80 80` (U+1000).
- the result: `strcmp(key(a), key(b)) == 0` <=> `SalNameEqualOrdinalCI(a, b)` (saltests: tables,
  40,000 random pairs of strings from units with case pairs / look-alikes / both UTF-8 lengths /
  surrogates, 20,000 random byte strings, and every pair of BMP characters the old key merged -
  22,497 over every non-surrogate unit, of them 108's 19,015 among assigned characters).

For one file under two spellings no name rule helps (SUBST, UNC). 103/107's file identity does:
`SalGetFileIdentity` (volume serial + 64/128-bit file id, with the snapshot tag and the FAT "weak
ids" flag), `SalFileIdMatch`. The decision `SalArchiveSharesCacheKey` takes only a certain "same":
equal usable ids, equal and known snapshot, and for FAT/exFAT also equal size and times.

Review addition: an equal KEY is no proof of one file either. A key taken from the other panel
keeps the spelling it came from (`T:\ARC.ZIP`); when that spelling later names another file (a SUBST
or network drive re-pointed, a hard link replaced) and a panel opens it, its own key equals the
stored one. `SalArchiveCacheKeyChoice` therefore reads the identity whenever a share could happen,
and gives an equal key without a certain identity a unique suffix (`0x01` + a counter) - except for
the same NAME with no sign of another file, the sharing of every release (file systems without ids).
