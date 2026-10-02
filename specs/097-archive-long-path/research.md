# Research 097: archive paths longer than 259 bytes

Read-only code research (no build, no run). `[code]` = read at the cited line;
`[inferred]` = concluded, not read or not run. Line numbers are of the working
tree on branch `096-archive-edit-accented` (2026-10-02).

## 0. Summary

- The limiter is one line: `lstrcpyn(backup1, archive, MAX_PATH)`
  (`src/fileswn2.cpp:2080-2081`). No caller checks the length first; the three
  main callers hand over paths from `SAL_MAX_PATH_UTF8` or heap buffers.
- Removing the limiter exposes **22 unbounded copies in the core** (12 on the
  plug-in route, 10 on the external-archiver route) and **1 in a shipped
  plug-in** (`uniso`), plus two 259-byte drag-and-drop/paste fields that would
  then work on a cut name (one of them deletes a file).
- Recommendation: first feature = **refuse with a message** (option A, existing
  strings, no translation work); raising the limit (option B) is a second
  feature of about 25 sites.

## 1. `CFilesWindow::ChangePathToArchive` (`src/fileswn2.cpp:2069-2485`)

### 1.1 Local buffers [code]

| Line | Buffer | Filled by | Bound | Note |
|---|---|---|---|---|
| 2080-2081 | `backup1[MAX_PATH]` | `lstrcpyn(backup1, archive, MAX_PATH)` | 259 bytes, silent, may cut inside a UTF-8 sequence | **the defect**; `archive = backup1` at 2116 |
| 2082-2084 | `backup2[MAX_PATH]` | `lstrcpyn(backup2, archivePath, MAX_PATH)` | same | inner path, see section 5 |
| 2085-2089 | `backup3[MAX_PATH]` | `lstrcpyn(backup3, suggestedFocusName, MAX_PATH)` | same | focus name only; a cut name just does not get focus |
| 2129 | `text[MAX_PATH + 500]` | `sprintf(IDS_FILEERRORFORMAT, archive, err)` at 2190 and 2358 | none | safe only through `backup1` |
| 2130 | `path[MAX_PATH]` | `strcpy(path, archive)` at 2147; `strcpy(path, archivePath)` at 2389 | none | safe only through `backup1` / `backup2` |
| 2246 | `buf[MAX_PATH]` | `strcpy(buf, archivePath)` | none | safe only through `backup2` |
| 2345 | `buf[MAX_PATH + 200]` | `sprintf(IDS_ARCHIVEREFRESHEDIT, GetZIPArchive())` | none | safe only through `backup1` |
| 2406-2407 | `currentPath[MAX_PATH]` | `strcpy(currentPath, GetZIPPath())` | none | safe only while ZIPPath <= 259 |

`SetZIPArchive` is `strcpy` into `ZIPArchive[SAL_MAX_PATH_UTF8]`
(`fileswn1.cpp:357-361`, `fileswnd.h:496`); `SetZIPPath` is `memcpy` into
`ZIPPath[SAL_MAX_PATH_UTF8]` (`fileswn1.cpp:345-355`, `fileswnd.h:497`).

### 1.2 `SalGetFullName` [code]

Declaration `consts.h:362-364`: `SalGetFullName(char* name, int* errTextID =
NULL, const char* curDir = NULL, char* nextFocus = NULL, BOOL* callNethood =
NULL, int nameBufSize = MAX_PATH, BOOL allowRelPathWithSpaces = FALSE)`.
Definition `salamdr3.cpp:430`. It works **in place**; `nameBufSize` is checked
only when the name must grow, i.e. for relative forms (`c:path`, `\path`,
`path`: `IDS_TOOLONGPATH` at `salamdr3.cpp:506-507, 549-550, 558-559,
583-584`). An absolute `c:\...` or UNC name is never measured (only the server
and share parts, against `MAX_PATH - 1`). The call at `fileswn2.cpp:2108`
passes the default size 260 with `curDir` = the panel's disk path. Errors are
shown as `LoadStr(errTextID)` titled `IDS_ERRORCHANGINGDIR`
(`fileswn2.cpp:2110-2114`).

### 1.3 The checks that follow [code]

1. Same archive already open? `SalNameEqualOrdinalCI(GetZIPArchive(), archive)`
   (2136). Otherwise:
2. `strcpy(path, archive); CutDirectory(path)` (2147-2148), then
   `SalCheckAndRestorePathWithCut(path...)` (2175). Not accessible or cut ->
   `IDS_FILEERRORFORMAT` "File: "%s"\nError: %s" with the (cut) archive name,
   title `IDS_ERRORTITLE` (2190-2191); nothing during a refresh.
3. `PackerFormatConfig.PackIsArchive(archive)` (2196): extension only
   (`pack3.cpp:393-444`). FALSE -> `TRACE_I` only, `CHPPFR_INVALIDARCHIVE`
   (2289-2294): **the silent "nothing happens"**.
4. `SalCreateFile(archive, ... OPEN_EXISTING ...)` (2200), size, time. Error ->
   `DialogError(archive, GetErrorText(err2), IDS_ERROROPENINGFILE)` (2215):
   "Error Opening File" naming the cut path.
5. `PackList(this, archive, ...)` (2232) -> plug-in `ListArchive` or external
   archiver. Failure -> `TRACE_I`, `CHPPFR_INVALIDARCHIVE` (2279-2287; the
   plug-in or packer shows its own message).
6. Success: `SetPath(path)`, `SetZIPArchive(archive)`, date, size (2269-2275).

The wrong-archive case: steps 2-5 all succeed on the cut name when a file with
that name exists.

### 1.4 Callers (10 call sites) [code]

| # | Site | What it passes | Source buffer | Limited upstream? |
|---|---|---|---|---|
| 1 | `fileswn2.cpp:280` Enter on an archive in a disk panel (or a link to one) | `fullName`, `""` | heap `bufs.FullName` (`fileswn2.cpp:98`), built with `SalPathAppend(fullName, fileName, SAL_MAX_PATH_UTF8)` (269), refusal `IDS_TOOLONGNAME` (271) | no |
| 2 | `fileswn2.cpp:500` `..` inside an archive | `GetZIPArchive()`, cut ZIPPath, `prevDir` | panel members | already <= 259 (set from `backup1`) |
| 3 | `fileswn2.cpp:523` Enter on a directory inside | `GetZIPArchive()`, `fullName` = ZIPPath + name, `SalPathAppend(..., SAL_MAX_PATH_UTF8)` (514) | heap | inner path not limited (section 5) |
| 4 | `fileswn0.cpp:2690` refresh | `GetZIPArchive()`, `GetZIPPath()`, `forceUpdate` TRUE, `isRefresh` TRUE | panel members | already <= 259 |
| 5 | `fileswn1.cpp:2264` `GotoRoot` | `GetZIPArchive()`, `""` | panel member | already <= 259 |
| 6 | `fileswn8.cpp:1530` path of the other panel | other panel's `GetZIPArchive()`, `GetZIPPath()` | panel members | already <= 259 |
| 7 | `fileswn3.cpp:2428` `ChangeDir` (Change Directory dialog, command line `cd`, hot paths, tabs, `-L/-R/-A`, plug-in `ChangePanelPath`) | `copy` (the path rebuilt component by component from the enumeration), `end` = inner part | `copy[SAL_MAX_PATH_UTF8]` (`fileswn3.cpp:2246`) | archive part: no. Inner part: **refused** when `>= MAX_PATH` with `IDS_TOOLONGPATH` (2415-2421) |
| 8 | `salamdr3.cpp:1555` `CPathHistoryItem::Execute` (Alt+F12 history, back/forward) | `PathOrArchiveOrFSName`, `ArchivePathOrFSUserPart`, `isHistory` TRUE | heap `DupStr` (`salamdr3.cpp:1368-1369`) | no |
| 9 | `zip.cpp:2131` plug-in service `CSalamanderGeneral::ChangePanelPathToArchive` | the plug-in's pointers | plug-in | no |
| 10 | (`fileswn0.cpp:2814` is a comment) | | | |

Other upstream limits met before `ChangePathToArchive`:

- Command line `-L/-R/-A`: `CCommandLineParams::LeftPath/RightPath/ActivePath`
  are `char[2 * MAX_PATH]` in a structure shared between instances
  (`tasklist.h:69-71`), filled with bound `2 * MAX_PATH`
  (`salamdr1.cpp:3656-3686`); activation of a running instance copies them
  with `lstrcpyn(..., MAX_PATH)` (`mainwnd3.cpp:2077-2084`). So 519 bytes at a
  new start, 259 bytes when forwarded. Silent.
- Hot path assignment: `GetGeneralPath` into `path[2 * MAX_PATH]`
  (`fileswn1.cpp:2312, 2323`): cut at 519 bytes, result unchecked.
- Panel tabs: `Location[2*SAL_MAX_PATH_UTF8]`, bounded: no limit
  (`saltabs.h:31`, `paneltabs.cpp:179, 327, 478`).
- `SalParsePath` (`salamdr5.cpp:663`) takes `pathBufSize`; it serves copy/move
  targets, not the panel change.
- After `backup1`, nothing upstream matters: `ZIPArchive` can never exceed 259
  bytes today, so no downstream code has been exercised with more.

## 2. Downstream consumers of the archive name

### 2.1 Opening the file [code]

Everything in `src/common/salfileio.cpp` goes through `SalPathToWExtAlloc`
(`salpath.cpp:256-345`): WTF-8 -> UTF-16 on the heap, `\\?\` / `\\?\UNC\`
prefix, limit 32,767 units. So `SalCreateFile` at `fileswn2.cpp:2200, 2327`
works for 260..777 bytes under 260 characters **and** for true long paths.
Exceptions: `SalGetShortPathName` must fit the caller's `MAX_PATH` buffer
(fails cleanly); `SalCreateProcess` hands an external archiver a command line
without `\\?\`, so a name of 260+ characters depends on the archiver
[inferred, not tested].

### 2.2 Core inventory

Classes: SAFE (works with 777 bytes or more) / TRUNCATES / **OVERFLOWS** /
REFUSES.

**a) Display and messages**

| Site | Buffer | Copy / bound | Class |
|---|---|---|---|
| `fileswn1.cpp:1748-1761` directory line | `CSalPathBuf` heap | `Set`/`Append` | SAFE |
| `fileswn1.cpp:1796-1817` | `buf[SAL_MAX_PATH_UTF8+MAX_PATH+4]` | `memcpy` | SAFE |
| `stswnd.cpp:127-151` | heap | | SAFE |
| `mainwnd1.cpp:1791, 1854, 1902` window title | `path[2*MAX_PATH]` | `GetGeneralPath(..., 520)` | TRUNCATES (title cut at 519 bytes) |
| `fileswn2.cpp:1270, 1334, 1363`; `fileswn9.cpp:1212` "archive is about to close" | `CSalHeapString` (095) | `Printf` | SAFE |
| `fileswn2.cpp:2190, 2358` | `text[MAX_PATH+500]` | `sprintf(IDS_FILEERRORFORMAT)` | **OVERFLOWS** |
| `fileswn2.cpp:2346` | `buf[MAX_PATH+200]` | `sprintf(IDS_ARCHIVEREFRESHEDIT)` | **OVERFLOWS** |
| `fileswn2.cpp:2215` | pointer to `DialogError` | | SAFE [inferred] |
| `fileswn7.cpp:752-761` | `name[SAL_MAX_PATH_UTF8]` | `strcpy`/`strcat` | SAFE |
| `fileswn7.cpp:763-764` F8 non-empty directory question | `text[2*MAX_PATH+100]` | `sprintf(IDS_NONEMPTYDIRDELCONFIRM, name)` | **OVERFLOWS** (tight already today: about 771 bytes against 620) |
| `bugreprt.cpp:1501` | `static buf[1024]` | `sprintf("Archive = %s")` | **OVERFLOWS** from 1,014 bytes; safe at 777 |
| `mainwnd5.cpp:1209, 1211` | | `GetGeneralPath(..., 520)` | TRUNCATES (progress text) |
| every `CALL_STACK_MESSAGE` | | `_vsnprintf_s(_TRUNCATE)` (`callstk.cpp:418`) | SAFE |

**b) Disk-cache keys** - all `CSalHeapString` since 095
(`fileswn2.cpp:1306-1308`, `fileswn9.cpp:1225-1227`, `fileswn5.cpp:791-857`,
`fileswn6.cpp:3199-3209`): SAFE.

**c) Pack layer**

| Site | Buffer | Copy / bound | Class |
|---|---|---|---|
| plug-in route `pack1.cpp:256, 351, 822`; `pack2.cpp:94, 592`; `plugins1.cpp:3675-3785` | pointer passed through | | SAFE |
| `pack3.cpp:393` `PackIsArchive` | none | | SAFE |
| `pack3.cpp:895` `$(ArchiveFullName)` | pointer | | SAFE |
| `pack3.cpp:880-881` `$(ArchivePath)` | `SPackExpData::Buffer[MAX_PATH]` | `strncpy` bounded by the source length | **OVERFLOWS** (archive's directory >= 260 bytes; built-in 7-Zip list, RAR delete: `pack1.cpp:268`, `pack2.cpp:769`) |
| `pack3.cpp:915` `$(ArchiveFileName)` | `Buffer[MAX_PATH]` | `strcpy` | **OVERFLOWS** (name component >= 260 bytes) |
| `pack3.cpp:951-952, 999` `PackExpArcDosName` | `path[MAX_PATH+50]`, `DOSTmpFile[260]` | `strcpy` | **OVERFLOWS** (custom commands with a DOS variable) |
| `pack2.cpp:466-467, 513` | `dstNameBuf[2*MAX_PATH]` | `strcpy` | **OVERFLOWS** from 520 bytes (same custom path) |
| `pack1.cpp:565, 864`; `pack2.cpp:401, 763` | `buffer[1000]` | `strcpy(buffer, cmdLine[1040])` | **OVERFLOWS** by up to 40 bytes when `SupportLongNames` is FALSE |
| `pack1.cpp:273, 550, 852`; `pack2.cpp:373, 751` | `cmdLine[PACK_CMDLINE_MAXLEN = 1040]` | length check in `DoExpandVarString` | REFUSES (`IDS_EXP_SMALLBUFFER` -> `IDS_PACKERR_CMDLNERR`) |
| `pack1.cpp:267, 584`; `pack2.cpp:768` | `currentDir[MAX_PATH]` | bounded expansion | REFUSES (after the 880 overflow) |
| `pack2.cpp:430, 783`; `pack3.cpp:921` | `[MAX_PATH]` | `SalGetShortPathName` | SAFE (fails cleanly) |
| `salamdr1.cpp:3149-3155`; `pack1.cpp:282` | `buff[1000]` | `FormatMessage`, `lstrcpyn` | TRUNCATES (message) |
| `pack3.cpp:1617` `PackRunArchiver` | heap wide | | SAFE |

**d) `CFileTimeStamps`, Archive Update dialog**

| Site | Buffer | Copy | Class |
|---|---|---|---|
| `salamdr3.cpp:3092-3093` `AddFile` (from `fileswn6.cpp:3344`) | `ZIPFile[MAX_PATH]` (`fileswnd.h:298`) | `strcpy` | **OVERFLOWS** into the following members |
| `dialogs5.cpp:1479-1481` Copy Selected To | `path[MAX_PATH]` | `strcpy(GetZIPFile())` | **OVERFLOWS** once `ZIPFile` grows |
| `dialogs5.cpp:1433` | pointer | | SAFE |
| `salamdr3.cpp:3481` `CheckAndPackAndClear` | pointer to `PackCompress` | | SAFE |

**e) History, tabs, hot paths**

| Site | Buffer | Class |
|---|---|---|
| `CPathHistoryItem` (`salamdr3.cpp:1368-1369`), `AddPath`, `DirHistoryAddPathUnique` | heap | SAFE |
| `salamdr3.cpp:2126-2194` registry save/load (`archive:inner`) | `path[SAL_MAX_PATH_UTF8]` | SAFE |
| panel tabs (`saltabs.h:31`, `paneltabs.cpp:179, 327, 478`, `mainwnd2.cpp:1241, 2371`) | `Location[2*SAL_MAX_PATH_UTF8]`, bounded | SAFE |
| `salamdr3.cpp:1783-1839` history menus | `buffer[2*MAX_PATH]` | TRUNCATES (menu text; item still works) |
| `fileswn1.cpp:2312, 2323` assign hot path | `path[2*MAX_PATH]` | TRUNCATES (stored hot path cut, unusable) |

**f) Drag and drop, clipboard**

| Site | Buffer | Copy | Class |
|---|---|---|---|
| `salshlib.cpp:476` `CSalShExtPastedData::SetData` (from `shellsup.cpp:1471`) | `ArchiveFileName[MAX_PATH]` (`salshlib.h:176`) | `lstrcpyn` | TRUNCATES: paste to Explorer fails, or **lists and unpacks another file** when one with the cut name exists (`salshlib.cpp:656-722`) |
| `shellsup.cpp:200` (from `fileswn9.cpp:513`) | `CTmpDragDropOperData::ArchiveOrFSName[MAX_PATH]` (`fileswnd.h:68`) | `lstrcpyn` | TRUNCATES: `fileswna.cpp:556-619` works on the cut name; a zero-length file with that name is **deleted** (`fileswna.cpp:572-574`), any other is packed into (579) |
| `shellsup.cpp:1394, 1403` drag from archive | `realDraggedPath[2*MAX_PATH]` | `lstrcpyn(buf + 1, ..., 2*MAX_PATH)` | **OVERFLOWS** by one byte from 519 bytes |
| `shellsup.cpp:1395, 1404`; `salshlib.h:73` | `[2*MAX_PATH]` | bounded | TRUNCATES |
| `salshlib.cpp:852`; `fileswna.cpp:630` | `[MAX_PATH]` | `lstrcpyn` | TRUNCATES (change notification for the wrong directory) |
| `salshlib.cpp:710`; `fileswna.cpp:642` | `text[1000]`; `text[2*MAX_PATH+100]` | `sprintf` | SAFE only while the two fields above stay 259 bytes |
| shell-extension shared memory (`shexreg.h:196-223`, `shellext/copyhook.c`) | | | SAFE: no archive name crosses it |

**g) Paths handed out**

| Site | Buffer | Copy | Class |
|---|---|---|---|
| `zip.cpp:987-999` `CSalamanderGeneral::GetPanelPath` (plug-in service) | `buf[2*MAX_PATH]` | `memcpy` + `strcat` | **OVERFLOWS** from 520 bytes of archive + inner path |
| `zip.cpp:1038-1041` | caller's buffer | length check | REFUSES (no message) |
| `fileswn9.cpp:2002, 2020, 2059` copy full name / path to clipboard | `buff[2*MAX_PATH]` | `GetGeneralPath` | TRUNCATES |
| `salamdr3.cpp:3957`; `fileswn8.cpp:1456`; `mainwnd3.cpp:4148-4149` | `[2*MAX_PATH]` | `GetGeneralPath` | TRUNCATES (the last: two locations equal in 519 bytes compare equal) |
| `fileswn9.cpp:61-70` | `curPath[SAL_MAX_PATH_UTF8]` | bounded | SAFE |
| F3 / Enter / F4 (`fileswn5.cpp:897`, `fileswn6.cpp:3270`) | pointer; the viewer gets the temporary name | | SAFE |

`GetGeneralPath` (`fileswn1.cpp:142-181`) clips and returns FALSE; no caller
checks it.

**h) Refresh**: `fileswn0.cpp:2690` -> `fileswn2.cpp:2327-2338`: pointer to
`SalCreateFile`: SAFE. The snooper and `CheckPath` work on `GetPath()` (the
archive's directory) [inferred, not read].

**i) Operations**: unpack / delete in archive (`fileswn7.cpp:668, 788`):
pointer: SAFE. F5 into an archive (`fileswn8.cpp:302-722`):
`path[SAL_MAX_PATH_UTF8]`: SAFE; `fileswn8.cpp:731`: TRUNCATES (error box);
`fileswn8.cpp:738`: wrong bound, silently no trailing backslash from 719 bytes.

**Count** (the inventory agent's final tally over its full site list, of which
the tables above are a condensed form): 75 SAFE, 37 TRUNCATES, **22 OVERFLOWS**,
13 REFUSES; 2 more overflows appear only when the drag fields are widened.
Of the 10 external-route sites, `pack3.cpp:880` and `915` are reached by the
built-in 7-Zip list / RAR delete; the other 8 need a custom archiver command
or a flag that no built-in table sets.

**Overflow sites, plug-in route (normal use of ZIP, 7-Zip, TAR)**:
`fileswn2.cpp:2147, 2190, 2358, 2346`; `salamdr3.cpp:3093`;
`dialogs5.cpp:1481`; `fileswn7.cpp:764`; `zip.cpp:994, 998-999`;
`shellsup.cpp:1394, 1403`; `bugreprt.cpp:1501` (12).
**External-archiver route**: `pack3.cpp:880, 915, 952, 999`;
`pack2.cpp:467, 513`; `pack1.cpp:565, 864`; `pack2.cpp:401, 763` (10).
If the two drag fields are widened: also `salshlib.cpp:710`,
`fileswna.cpp:642`.

Not read: `SalCheckAndRestorePathWithCut`'s buffer contract; hot-path
expansion (`GetExpandedHotPath(..., 520)`); the Alt+F5 / Alt+F9 dialogs
(`packers.cpp`). Note [inferred]: Alt+F9 on a file in a disk panel reaches the
pack layer **without** `ChangePathToArchive`, so the `pack3.cpp:880/915`
overflows may be reachable today for an archive in a folder of 260+ bytes with
an external archiver; to be checked in the feature.

Unrelated overflow reported on the way (not re-read): `fileswn3.cpp:2446-2447`
`strcpy` into `shortenedPath[MAX_PATH]` for a non-archive file path of 260+
bytes typed into Change Directory.

### 2.3 Archiver plug-ins

Implementers of `CPluginInterfaceForArchiverAbstract`: enabled `zip`, `7zip`,
`tar`, `uncab`, `uniso`; disabled `unrar`, `unmime`, `unole`, `unchm`,
`demoplug`. `undelete`, `checksum` and the rest do not implement it.
`GetCacheInfo`, `DeleteTmpCopy`, `PrematureDeleteTmpCopy` are empty stubs in
all five (`zipdll.h:68-70`, `7zip.h:77-79`, `tardll.h:44-46`,
`uncab.h:148-150`, `uniso.h:70-72`).

**What the headers promise**: `spl_arc.h` says nothing about the length of
`fileName` (its only `MAX_PATH` is `tempPath` of `GetCacheInfo`, line 143).
`spl_base.h:72-76` defines `SAL_MAX_PATH_UTF8` ("as long as Windows allows ...
since interface version 104. Defined for plugins by name since version 107");
`spl_base.h:81-86` `CSalMaxPathBuffer`. `spl_gen.h` corrects **output**
buffers only (938; 2005, 2028, 2037; 2707-2710, 2734-2737).

| Plug-in | How it opens the archive | Sites | Exposure for a name up to 777 bytes |
|---|---|---|---|
| zip | `CreateFileU8` (`common.cpp:171-184`) -> `SplU8ToWExtAlloc` -> `CreateFileW` | `ZipName`, `TempName` heap `U8_MAX_PATH` (`common.cpp:462-464`); `title[1024]` `sprintf` of the name **component** only (`add.cpp:73-74, 232-233, 480-481`; `extract.cpp:70-71, 225`; `add_del.cpp:203-204`): safe by margin (component <= 765 bytes); SFX name `archName[MAX_PATH]` refuses with `IDS_TOOLONGZIPNAME` (`add.cpp:278-281`); Browse in change-disk dialogs `fileNameA[MAX_PATH]` empty on failure (`dialogs.cpp:1449-1450, 1678-1699`) | **none** |
| 7zip | `CRetryableInFileStream::Open` (`FStreams.cpp:199-202`), `CreateFileU8` (`7zip.cpp:340-354`) -> `SplU8ToWExtAlloc` | error texts `_TRUNCATE` (`7zip.cpp:195-231, 255-268`); options dialog `Archive[MAX_PATH]` `lstrcpyn` (`dialogs.h:94, 118`); heap `U8_MAX_PATH` in Delete / Update (`7zclient.cpp:1151-1166, 1655-1666`) | **truncation of display texts only** |
| tar | `CreateFileU8` (`tardll.cpp:95-108`) | pointer kept (`fileio.cpp:133`); exact `malloc` (`untar.cpp:540-548`) | **none** |
| uncab | FDI callback -> `CabPathToWExtAlloc` (`uncab.cpp:234-247`) | length gate `lstrlen >= CB_MAX_CAB_PATH` -> `IDS_TOOLONGNAME` before every `strcpy` (`uncab.cpp:384-386, 468-470, 598-600, 704-706`); `CB_MAX_CAB_PATH` = 256 [inferred from the SDK's `fdi.h`] | **none: REFUSES from 256 bytes** with "Can't finish operation because of too long path name." (already today for 256-259) |
| uniso | `CreateFileU8` (`uniso.cpp:94-107`) | **`isoimage.cpp:833-835`: `sprintf(errStr[MAX_PATH], IDS_CANT_OPEN_FILE, fileName)`**, on the open-failure path of all four operations | **OVERFLOW at 1 site**; already reachable today at 240-259 bytes |
| unrar (off) | | `lstrcpy(ArcFileName[MAX_PATH], arcName)` `unrar.cpp:1403` (+1411, 1423-1424) | OVERFLOWS |
| unole (off) | `SplU8ToWExtAlloc` | `vsprintf` into `buf[1024]` (`unole2.cpp:542-546`) | overflow above ~1,000 bytes |
| unmime (off) | `SplU8ToWExtAlloc` | not fully traced | - |
| unchm (off) | external chmlib with `char*` (`chmfile.cpp:113`) | | fails for long / non-ASCII [inferred] |

`SplU8ToWExtAlloc` (`splunicode.h:269-293`) converts on the heap and prefixes
`\\?\`, so zip, 7zip, tar and uniso open both a 260..777-byte path under 260
characters and a true long path.

## 3. Other parts of the product; the plug-in contract

- Disk panels, file operations, viewer, Change Directory: long-path capable
  since 004 (`SAL_MAX_PATH_UTF8` buffers, `\\?\` on every wide call), i.e. both
  ranges work; the archive entry is the exception.
- The byte/character distinction is not made anywhere: limits are either
  `MAX_PATH` bytes (old code) or `SAL_MAX_PATH_UTF8`.
- Contract 088 (`specs/088-plugin-interface-107/contracts/plugin-api-v107.md`):
  B1 (67-76) `SAL_MAX_PATH_UTF8` is "the size in bytes ... of a buffer that
  holds any full path or full file name the program can hand to a plug-in";
  B2 (78-91) six corrected output buffers; B3 (93-101) a plug-in built for
  < 107 gets from `GetNext/PreviousFileNameForViewer` only names that fit
  `MAX_PATH`, longer ones are stepped over.
- `src/common/salplugver.h` (32 lines): `SAL_PLUGINVER_LONG_VIEWER_NAMES 107`,
  `SalViewerNameFitsPlugin(builtForVersion, nameLen)` = `builtForVersion >= 107
  || nameLen < MAX_PATH`. Viewer names only.
- **There is no rule for the archiver `fileName`, and no per-plug-in "takes
  long paths" notion** other than `BuiltForVersion`. `CPluginData::
  BuiltForVersion` is already at hand where the listing plug-in is known
  (`fileswn2.cpp:2278-2279`), so the 088 rule can be reused for archivers.

## 4. Design options

**A. Refuse instead of cutting (minimal).** In `ChangePathToArchive`, before
the copies: `strlen(archive) >= MAX_PATH` (or `strlen(archivePath) >=
MAX_PATH`) -> message, `*failReason = CHPPFR_INVALIDPATH`, `return FALSE`; no
message when `isRefresh`. One site, about ten lines. Existing translated
strings (`src/lang/texts.rc2`):

- 376 `IDS_TOOLONGPATH` "The path specified is too long." - already what
  `SalGetFullName` reports through the same message box
  (`fileswn2.cpp:2110`, title 543 `IDS_ERRORCHANGINGDIR` "Error Changing
  Directory") and what `ChangeDir` shows for a long inner path
  (`fileswn3.cpp:2419`). **Recommended text.**
- 294 `IDS_TOOLONGNAME` "Cannot finish operation because of too long name."
  (used by caller 1 at `fileswn2.cpp:271`).
- 481 `IDS_NAMEISTOOLONG` "Name "%s" with full path is too long.\n\nPath: %s".

No new string, no translation work. A relative `archive` (plug-in service) is
measured after `SalGetFullName`, which needs the real buffer size passed.
With `isHistory` the panel can still go to the nearest disk path
(`tryPathWithArchiveOnError`) [design choice].

**B. Raise the limit.** The file layer and four of five shipped archiver
plug-ins take any length, so "259 characters" is not a natural limit; the
choice is which consumers are fixed. Changes:

- `ChangePathToArchive`: `backup1`, `path`, `text`, `buf` to heap /
  `SAL_MAX_PATH_UTF8` (4 sites + the `SalGetFullName` size);
- core plug-in route: `CFileTimeStamps::ZIPFile` + `dialogs5.cpp:1481`,
  `fileswn7.cpp:764`, `zip.cpp:987-999`, `shellsup.cpp:1394, 1403`,
  `bugreprt.cpp:1501` (8 sites);
- the two drag/paste fields (`salshlib.h:176`, `fileswnd.h:68`) and the two
  messages that depend on them: widen, or refuse the operation - they must not
  stay cut (wrong file listed / deleted);
- `uniso` `isoimage.cpp:833-835`; `uncab` keeps refusing with its own message;
- external archivers: either fix the 10 pack sites or refuse a name >= 260
  bytes in the external branch of the pack functions (they are capped by the
  1,040-byte command line anyway);
- plug-ins built for < 107 (third party): reuse the 088 rule - such a plug-in
  gets only archive names that fit `MAX_PATH`, otherwise the option-A message;
  document it as a B4 clause;
- cosmetics left: titles, menu texts, clipboard and hot-path assignment cut at
  519 bytes (`GetGeneralPath` callers, 9 sites).

About 25 sites in the core, 1 in a plug-in, a contract clause, and a probe
over all four plug-in routes.

**C. Full long-path support for archives** = B plus the `GetGeneralPath`
callers (`2 * MAX_PATH` everywhere), the `CCommandLineParams` shared structure
(fixed layout shared with older instances), hot paths, the inner-path limits of
section 5 (`AddFile`/`AddDir`, `MAX_PATH` inner buffers), external archivers
with `\\?\`. Feature-sized several times over; out of scope.

**Recommendation.** First feature: **A**, for both the archive path and the
inner path, plus the `uniso` one-line bound (reachable today). It removes all
three bad outcomes (silence, a message naming a cut path, another archive
opened) with no new exposure. Remaining after A: archives in folders over 259
bytes still do not open, now with a clear message; that is option B as the
next feature, on the inventory above.

## 5. The inner path

- `backup2[MAX_PATH]`: the same silent cut (`fileswn2.cpp:2082-2084`).
- `ChangeDir` (caller 7) refuses an inner part `>= MAX_PATH` with
  `IDS_TOOLONGPATH` before calling (`fileswn3.cpp:2415-2421`). History
  (caller 8) and Enter on a directory (caller 3: ZIPPath + name, up to
  251 + 1 + 251 bytes) do not.
- Can such a directory be listed? `CSalamanderDirectory::AddFile`
  (`zip.cpp:5999`) and `AddDir` (`zip.cpp:6097`) refuse `strlen(path) >
  MAX_PATH - 5` or `NameLen > MAX_PATH - 5` (trace only, FALSE). So a
  directory can exist at path <= 251 with a name <= 251 (its own inner path up
  to 503 bytes), but nothing can be added **inside** it once its path exceeds
  251 bytes: it is at best empty, and the plug-in's listing gets FALSE for its
  content (what each plug-in does then was not followed).
- Entering it: the path is cut to 259 bytes; the loop at `fileswn2.cpp:2411-
  2436` shortens the cut path until a listed directory is found, so the panel
  stays where it was or lands in a parent, `CHPPFR_SHORTERPATH`, **no
  message** on Enter. If a directory whose name equals the cut text exists,
  that **other directory** is entered [inferred from the code; small
  probability].
- With option A the check `strlen(archivePath) >= MAX_PATH` gives the message
  instead; `path`, `buf`, `currentPath` stay safe because ZIPPath stays <= 259.

## 6. Test plan without a person

Pattern: `specs/095-archive-path-buffers/probe/longarc_probe.ps1` through
`tools/run_on_hidden_desktop.ps1` (registry export/restore with SHA-256,
`\\?\` fixture tree under `%TEMP%`, python `zipfile` archive, window messages,
own pid only). Its cases all use a short archive path, so new cases are
needed; the folder components are U+0159 (2 bytes) or ASCII.

| Case | Archive full name | Old build (expected from 095's notes) | Build with A |
|---|---|---|---|
| A250 | 250 bytes ASCII | opens (control) | opens |
| A259 | 259 bytes ASCII | opens (boundary) | opens |
| A260 | 260 bytes ASCII, also 260 characters | Enter does nothing, no window | message `IDS_TOOLONGPATH` |
| U130 | 130 characters accented = about 260 bytes | Enter does nothing | message |
| U200 | 200 characters = about 400 bytes | nothing, or `IDS_FILEERRORFORMAT` with a cut path when the folder itself passes 259 bytes | message |
| U259 | 259 characters = about 500 bytes | same | message |
| L300 | 300 characters (true long path) | same | message |
| TWIN | U130 archive `x.zip.zip` whose 259-byte cut is `...x.zip`; a second, different archive is created under exactly that cut name (possible only when the cut falls on a character boundary: build the name so that it does) | **the twin is opened** (title names the twin, the list shows the twin's entry) | message, twin not opened |
| MID | cut falls inside a 2-byte sequence, name `x.tar.gz` -> `x.tar` variant from 095 | "Error Opening File" for a wrong name | message |
| HIST | open A250, leave; rename the folder chain so the history entry exceeds 259 bytes is not possible; instead start with `-L "<U200 archive>"` and with Change Directory (CM id of Shift+F7, text set by `WM_SETTEXT`) | cut / nothing | message once, panel on a disk path |
| INNER | short archive, directory `d251\n251` (inner path 503 bytes) | Enter: nothing or parent | message |
| ISO | `uniso`: a 250-byte name of a `.iso` that is locked (opened exclusively by the probe) | Debug: /RTC stack-corruption window | plain "Cannot open file" |

Observed per case: main window title after Enter, the left list
(`Get-LeftList`), every new top-level window with its texts (`Serve`), a
`FATAL` row for run-time-check / crash windows, process alive + `WM_NULL` +
exit code 0, no new crash report. For the cases that open (A250, A259): VIEW
(CM_VIEW 742), EDIT (CM_EDIT 743 with the `cmd /c echo` editor) and LEAVE with
Update All, read back with python - unchanged from the 095 probe. Run the same
script against the build before the feature (`-Label pre097`) to record the
old behaviour, TWIN in particular.
