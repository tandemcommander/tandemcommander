# Feature 092, stage S4 (core path identity) - site-by-site plan

Read-only analysis of the working tree on `092-name-identity-unicode` (S1 committed, S2 edits
uncommitted in the tree). Line numbers are the CURRENT ones in the working tree. Nothing was
built or run. All paths relative to `src/`.

Helpers used below (`common/salunicode.h`):
`SalPathEqualOrdinalCI(p1, p2)`, `SalNameEqualOrdinalCI(a, aLen, b, bLen)`,
`SalPathHasPrefixOrdinalCI(path, prefix, prefixLen, &pathBytes)`.

## 0. Findings that change the candidate list

1. **Eight candidates are x86-only code** (`#ifndef _WIN64`): `fileswn3.cpp:131, 1771, 1812,
   1864, 1940` and `fileswn1.cpp:2334, 2361, 2379`. The product is built and shipped x64 only
   (`build.cmd`), so a change there can be neither compiled nor tested by the feature's gates.
   Not converted. (If `byte-fold-on-name` becomes strict for `fileswn1.cpp`/`fileswn3.cpp`,
   these lines need an `encoding-check: allow` annotation.)
2. **Three candidates sit inside global functions that are exported to plug-ins** through
   `CSalamanderGeneral` wrappers in `zip.cpp`: `salamdr5.cpp:767` (`SalParsePath`, wrapper
   `zip.cpp:2817`), `salamdr5.cpp:1143-1145` (`SalSplitGeneralPath`, wrapper `zip.cpp:2848`;
   `spl_gen.h:2041` documents "NULL = IsTheSamePath is used"), `salamdr1.cpp:1418`
   (`PathsAreOnTheSameVolume`, wrapper `zip.cpp:4839`). Hard constraint 1 -> not converted.
3. **The four "plug-in directory prefix" sites do not compare UTF-8** (`dialogs5.cpp:784`,
   `plugins2.cpp:1386, 3008, 3443`): the prefix comes from the un-suffixed
   `GetModuleFileName(HInstance, ...)` (= the ANSI API, there is no wrapper) and, at 784, the
   other operand from the ANSI `SafeGetOpenFileName`. For code-page text the byte fold is the
   *right* fold; the new helper would only reach tier 3 (or misclassify, trap T10). Not
   converted - belongs to cluster B-1 / the install-path work.
4. **`fileswn2.cpp:1303` is tied to the disk-cache key** (`StrICpy` two lines below it), which
   is S5 (trap T3). Converting 1303 alone would leave cached files of one archive under a key
   nobody flushes. Moved to S5. The three `cache.cpp` sites move with the cache group too.
5. **Argument order differs from site to site.** In `fileswn7.cpp:2044`, `fileswnb.cpp:1194`,
   `fileswn5.cpp:2153` (and the x86 sites `fileswn3.cpp:1812/1940`) the FIRST argument of
   `StrNICmp` is the prefix and the second is the longer path - the reverse of the helper's
   `(path, prefix, ...)`. Each replacement below is written out.
6. Every `l1 == l2 && StrNICmp(a, b, l1) == 0` must lose its byte-length guard (7 BMP case
   pairs have different UTF-8 lengths): it becomes `SalNameEqualOrdinalCI(a, l1, b, l2)`.

Legacy `IsTheSamePath` (`salamdr1.cpp:1428`, body stays) vs `SalPathEqualOrdinalCI`: I walked
the leading/trailing-backslash combinations by hand (`a\` vs `a`, `a\\` vs `a\`, `a\\` vs `a`,
`a\b` vs `a`, `\` vs ``, UNC) and found no difference for ASCII input; S1's saltests are
said to pin this - I did not re-run them.

Thread note: `CFilesWindowAncestor::SamePath` runs on the **snooper thread**
(`snooper.cpp:174, 315`). The helper is re-entrant (stack buffers 2 x 520 WCHAR, lazy legacy
table filled idempotently) - fine.

---

## 1. Callers of the global `IsTheSamePath` (core)

### 1.1 `dialogs5.cpp:1851` - drive-specific configuration page, data transfer
```
ti.EditLine(IDE_DRVSPEC_ONERRGOTO, newPath, MAX_PATH);
GetIfPathIsInaccessibleGoTo(path, TRUE);
if (IsTheSamePath(path, newPath)) // user wants to go to My Documents
```
Operands: `path` = My Documents (or Desktop / system root) from `GetMyDocumentsOrDesktopPath`,
UTF-8; `newPath` = text typed in the edit line, UTF-8 (`CTransferInfo::EditLine` reads wide and
stores UTF-8, `common/winlib.cpp:1042`). Windows paths. Decides: store "is My Documents" flag
instead of a literal path. Partners: `mainwnd2.cpp:3296` (same decision at config load),
`fileswn2.cpp:1757`. Replacement: `if (SalPathEqualOrdinalCI(path, newPath))`.
**CONVERT TOGETHER WITH 1.14** - risk low.

### 1.2 `drivelst.cpp:110` - `GetUserName`
```
res = SalRegQueryValueEx(driveKey, "RemotePath", 0, &type, (unsigned char*)keyName, &keyNameSize);
if (res == ERROR_SUCCESS && type == REG_SZ && IsTheSamePath(keyName, remoteName))
```
Operands: a UNC remote name stored under `HKCU\Network\<letter>` and the remote name of a
remembered connection. I did not establish the encoding of `remoteName` (caller
`drivelst.cpp:497`, WNet enumeration) nor of `SalRegQueryValueEx` here. A share name, not a
file-system name. **DO NOT CONVERT** - operands' encodings not established; no defect recorded.

### 1.3 `fileswn1.cpp:226` and `:228` - `CFilesWindowAncestor::SetPath`
```
if (SuppressAutoRefresh && (!Is(ptDisk) || !IsTheSamePath(path, Path)))
    SuppressAutoRefresh = FALSE;
if (!IsTheSamePath(path, Path))
    EquivalentPairNoticeShown = FALSE; // new path - the FR-007 notice may be shown again
```
Operands: new and current panel path. `SetPath` is called only with Windows paths
(`fileswn2.cpp:1854, 2259`; `SetPath(GetPath())` when leaving to a plug-in FS). UTF-8.
Decides two "path changed" flags. No partner. Replacement: both calls ->
`SalPathEqualOrdinalCI(path, Path)`. **CONVERT** - risk low.

### 1.4 `fileswn2.cpp:412` - `CFilesWindow::Execute` (subdirectory branch, disk)
```
if (!IsTheSamePath(path, GetPath())) // we're not on the original path -> long jump
{ TopIndexMem.Clear(); } else { refresh = FALSE; ... }
```
Operands: backup of the panel path before `ChangePathToDisk` and the panel path after its
failure. Windows, UTF-8. Partner: `CTopIndexMem` (3.4). Replacement:
`if (!SalPathEqualOrdinalCI(path, GetPath()))`. **CONVERT** - low.

### 1.5 `fileswn2.cpp:1757` - `CFilesWindow::ChangePathToDisk`
```
if ((ifPathIsInaccessibleGoTo[0] == '\\' && ifPathIsInaccessibleGoTo[1] == '\\' ||
     ifPathIsInaccessibleGoTo[0] != 0 && ifPathIsInaccessibleGoTo[1] == ':') &&
    !IsTheSamePath(path, ifPathIsInaccessibleGoTo))
{ canTryUserRescuePath = TRUE; }
```
Operands: requested disk path, the configured rescue path. Windows, UTF-8. Decides whether the
rescue path may be tried. Replacement: `!SalPathEqualOrdinalCI(path, ifPathIsInaccessibleGoTo)`.
**CONVERT** - low.

### 1.6 `fileswn2.cpp:1829` - same function
```
BOOL samePath = (Is(ptDisk) && IsTheSamePath(GetPath(), changedPath));
```
Gated by `Is(ptDisk)`. `samePath` suppresses the directory-history entry and is passed to
`CloseCurrentPath` (4th and 6th arguments). Partner: history de-duplication (3.3) - both
should say "same" for the same pair. Replacement:
`Is(ptDisk) && SalPathEqualOrdinalCI(GetPath(), changedPath)`. **CONVERT** - low.
(`fileswn2.cpp:1800, 1805` are inside a comment block - leave.)

### 1.7 `fileswn2.cpp:2052` - same function, return value
```
BOOL ret = Is(ptDisk) && IsTheSamePath(GetPath(), path);
if (!ret && failReason != NULL && *failReason == CHPPFR_SUCCESS) *failReason = CHPPFR_SHORTERPATH;
```
"Did we land on the requested path". Today a request typed as `c:\článek` landing on
`C:\Článek` reports `CHPPFR_SHORTERPATH`. Replacement:
`Is(ptDisk) && SalPathEqualOrdinalCI(GetPath(), path)`. Callers act on the return value
(e.g. focus name is applied only on TRUE) - an improvement, but visible. **CONVERT** - low/medium.

### 1.8 `fileswn3.cpp:131`, `:1771`, `:1864` - x86 only
`IsTheSamePath(GetPath(), WindowsDirectory)`, `IsTheSamePath(subDir, redirectedDir)`,
`IsTheSamePath(subDir, redirectedDirPrefix)` (second operands are ASCII constants such as
`"system32\\catroot"`). **DO NOT CONVERT** - `#ifndef _WIN64`, not built.

### 1.9 `fileswn6.cpp:698` - `CFilesWindow::BuildScriptMain2`
```
if (IsTheSamePath(sourcePath, targetPath) && // "Copy of..." is done only if paths match
    makeCopyOfName)
{ strcpy(targetName, s + 1);
  if ((isKnown = ContainsString(usedNames, targetName)) != 0 || SalGetFileAttributes(targetPath) != 0xFFFFFFFF)
```
Operands: directory of a source file (cut from its full name) and the target directory.
Windows, UTF-8. Decides whether a "Copy of ..." target name is generated. Partners:
`fileswn6.cpp:689` (`StrICmp(lastSourcePath, sourcePath)` - only a cache of per-volume flags,
harmless either way) and `ContainsString`/`usedNames` (S5 sorted pair - independent operand).
Replacement: `if (SalPathEqualOrdinalCI(sourcePath, targetPath) && makeCopyOfName)`.
I read only the ~30 lines around the site, not the whole 500-line function.
**CONVERT**, in the reviewed group - risk medium (gates how an operation names its target).

### 1.10 `fileswn7.cpp:2091` - `CFilesWindow::IconOverlaysChangedOnPath`
```
Configuration.EnableCustomIconOverlays && Is(ptDisk) && ... && IsTheSamePath(path, GetPath()))
```
Operands: shell change-notification path and the panel path; gated by `Is(ptDisk)`. Comment at
`mainwnd3.cpp:1635` refers to this gate (text only). Replacement:
`SalPathEqualOrdinalCI(path, GetPath())`. **CONVERT** - low. (`:2076` is commented out.)

### 1.11 `fileswnb.cpp:873` - `WM_USER_FOCUSFILE`
```
if (Is(ptDisk) && IsTheSamePath(GetPath(), (char*)lParam) || ChangeDir((char*)lParam))
```
Operands: panel path and the path sent by Find / the disk cache / Go To (core senders:
`finddlg1.cpp:2451`, `finddlg2.cpp:1971`, `mainwnd3.cpp:3073, 3104, 3226`, `mainwnd4.cpp:2125`,
`cache.cpp:1560`, and the plug-in service at `zip.cpp:2065`). The `Is(ptDisk)` gate keeps
plug-in FS paths out; a false "different" only costs a `ChangeDir`. The name focus that follows
was converted in S2. Replacement: `Is(ptDisk) && SalPathEqualOrdinalCI(GetPath(), (char*)lParam)`.
**CONVERT** - low.

### 1.12 `mainwnd2.cpp:677` - `GetUpgradeInfo`
`!IsTheSamePath(autoImportConfigFromKey, SalamanderConfigurationRoots[0])` - two **registry key
names** (ASCII). **DO NOT CONVERT** - not a file path, ASCII constants (bucket A).

### 1.13 `salamdr1.cpp:1418` - `PathsAreOnTheSameVolume`
`if (IsTheSamePath(path1NetPath, path2NetPath)) *resIsOnlyEstimation = FALSE;`
**DO NOT CONVERT** - the function is exported (`zip.cpp:4839`).

### 1.14 `mainwnd2.cpp:3296` - `CMainWindow::LoadConfig`
```
GetIfPathIsInaccessibleGoTo(path, TRUE);
if (IsTheSamePath(path, Configuration.IfPathIsInaccessibleGoTo)) // user wants to go to My Documents
```
Same pair as 1.1, at load of a configuration without the "is My Documents" value. Both UTF-8
(registry facade). Replacement: `SalPathEqualOrdinalCI(path, Configuration.IfPathIsInaccessibleGoTo)`.
**CONVERT TOGETHER WITH 1.1** - low.

### 1.15 `salamdr5.cpp:1143-1145` - `SalSplitGeneralPath`
```
if (StrICmp(dirName, name) == 0 &&
    (isTheSamePathF != NULL && isTheSamePathF(path, curPath) ||
     isTheSamePathF == NULL && IsTheSamePath(path, curPath)))
```
Exported; a plug-in FS passes its own comparison callback or NULL, and with NULL the paths may
be FS user parts. **DO NOT CONVERT** - hard constraint 1.

### 1.16 `shellsup.cpp:1852` - `ShellAction` (cut / copy to clipboard)
```
BOOL samePaths = panel->Is(ptDisk) && anotherPanel->Is(ptDisk) &&
                 IsTheSamePath(panel->GetPath(), anotherPanel->GetPath());
```
Both panel paths, disk only. Decides whether the other panel is repainted separately when its
cut-flags are cleared. Replacement: `SalPathEqualOrdinalCI(panel->GetPath(), anotherPanel->GetPath())`.
**CONVERT** - low.

---

## 2. Whole-string path equality written with `StrICmp` / `StrNICmp`

### 2.1 `fileswn1.cpp:362-373` - `CFilesWindowAncestor::SamePath`
```
int l1 = (int)strlen(Path);          if (l1 > 0 && Path[l1 - 1] == '\\') l1--;
int l2 = (int)strlen(other->Path);   if (l2 > 0 && other->Path[l2 - 1] == '\\') l2--;
return (PanelType == ptDisk || PanelType == ptZIPArchive) &&
       (other->PanelType == ptDisk || other->PanelType == ptZIPArchive) &&
       l1 == l2 && StrNICmp(Path, other->Path, l1) == 0;
```
Operands: `Path` of two panels (disk, or the directory of the archive), UTF-8. Callers: the
snooper thread (`snooper.cpp:174, 315`) - "another panel watches the same directory, signal its
handle too". Replacement of the last line:
`SalNameEqualOrdinalCI(Path, l1, other->Path, l2);` (the `l1 == l2` guard goes).
**CONVERT** - low (thread-safe, see section 0).

### 2.2 `fileswnb.cpp:657` - `WM_USER_REFRESH_DIR` handling
```
lstrcpyn(pathBackup, GetPath(), MAX_PATH); ... RefreshDirectory(...);
if (typeBackup != GetPanelType() || StrICmp(pathBackup, GetPath()) != 0)
```
The panel path before and after a refresh in an inactive window; only tunes the timing of the
next refresh. `pathBackup` is cut at `MAX_PATH` (existing; a cut inside a character makes it
invalid UTF-8 -> tier 3 -> "different", as today). Replacement:
`!SalNameEqualOrdinalCI(pathBackup, -1, GetPath(), -1)`. **CONVERT** - low.

### 2.3 `salamdr3.cpp:1696` and `:1703` - `CPathHistoryItem::IsTheSamePath`
```
if (Type == 0) { GetPath(buf1, 2 * MAX_PATH); item.GetPath(buf2, 2 * MAX_PATH);
                 if (StrICmp(buf1, buf2) == 0) return TRUE; }
else if (Type == 1) // archive
    if (StrICmp(PathOrArchiveOrFSName, item.PathOrArchiveOrFSName) == 0 &&  // archive file: case-insensitive
        strcmp(ArchivePathOrFSUserPart, item.ArchivePathOrFSUserPart) == 0) // path inside: case-sensitive
```
Operands: disk paths / archive file names of two history items, UTF-8. Consumers:
`salamdr3.cpp:1962, 1980, 2014, 2073` (update / remove a duplicate history entry). The history
is persisted, but only the *set of entries* changes, not the shape. Trap T11: `C:\ĥ` and
`C:\Ĺ` become two entries (correct, visible). Replacements:
`if (SalNameEqualOrdinalCI(buf1, -1, buf2, -1))` and
`if (SalNameEqualOrdinalCI(PathOrArchiveOrFSName, -1, item.PathOrArchiveOrFSName, -1) && strcmp(...) == 0)`.
The `strcmp` on the inner path stays. **Lines 1713 and 1718 (plug-in FS *name*, an ASCII
identifier) and the FS user part (`strcmp` + the plug-in's `IsCurrentPath` callback) are NOT
touched** - the FS decides about its own paths. **CONVERT** 1696 + 1703 together - low/medium.

### 2.4 `salamdr3.cpp:3502` and `:3534` - `CTopIndexMem::Push` / `FindAndPop`
```
// Push: s = start of the last component of 'path' (at a backslash or at path)
int l = (int)strlen(Path); if (l > 0 && Path[l - 1] == '\\') l--;
ok = s - path == l && StrNICmp(path, Path, l) == 0;
// FindAndPop:
if (l1 == l2 && StrNICmp(path, Path, l1) == 0)
```
Operands: the remembered path and the path being entered/left. Callers (all in
`fileswn2.cpp` `Execute`: 284, 352, 408, 454, 467, 495, 524) pass disk paths and, for archives,
`archive file + "\" + path inside` ("doublePath"). No plug-in FS path reaches it. The inside
part of an archive path is already compared case-insensitively today, so nothing gets stricter
for ASCII. Tabs copy the object in memory (`paneltabs.cpp:216, 307`); not persisted.
Replacements:
`ok = SalNameEqualOrdinalCI(path, (int)(s - path), Path, l);` (`s` is at a backslash or at the
start, i.e. on a character boundary; with `s == path` both forms give "equal only if l == 0")
and `if (SalNameEqualOrdinalCI(path, l1, Path, l2))`.
**CONVERT both together** (push and pop must agree) - low.

### 2.5 `find.cpp:628` - `CFindIgnore::AddUnique`
```
if (len != itemLen) continue;
if (StrNICmp(path, item->Path, len) == 0) { item->Enabled = TRUE; return TRUE; }
```
(`len`/`itemLen` exclude one trailing backslash.) Operands: an ignore-list entry typed by the
user (full, rooted or relative path fragment) and the new one (`finddlg2.cpp:1987`), UTF-8.
De-duplicates the configured list. Replacement: delete the `len != itemLen` test and use
`if (SalNameEqualOrdinalCI(path, len, item->Path, itemLen))`. **CONVERT** - low.

### 2.6 `shares.cpp:235` - `CShares::PrepareSearch`
```
int itemNameLen = (int)(item->LocalName - item->LocalPath);
if (pathLen == itemNameLen && StrNICmp(item->LocalPath, buff, itemNameLen) == 0)
```
Operands: the parent directory (with backslash) of a shared local folder (`NetShareEnum`, UTF-8
since 069 F-P1-27, ANSI fallback) and the panel path + backslash. Local Windows paths. Decides
which shares are candidates for the "shared folder" overlay in this directory. The sorted
`Wanted` array (`GetWantedIndex`, `StrICmp` on the folder *name*) is a different operand and
stays (S5 / deferred). Replacement:
`if (SalNameEqualOrdinalCI(item->LocalPath, itemNameLen, buff, pathLen))`. **CONVERT** - low.

---

## 3. Archive identity

### 3.1 `fileswn2.cpp:1303` - `PrepareCloseCurrentPath`
```
if (someFilesChanged || !another->Is(ptZIPArchive) || StrICmp(another->GetZIPArchive(), GetZIPArchive()) != 0)
{   StrICpy(buf, GetZIPArchive()); // the disk cache stores the archive name in lowercase
    DiskCache.FlushCache(buf); }
```
"The same archive is still open in the other panel -> keep its cached files." The key that is
flushed is the byte-folded name of THIS panel's spelling. If the comparison became Unicode-aware
while the key stays byte-folded, two spellings of one archive (`Č.zip` / `č.zip`) would be "the
same archive" with two different keys: this panel's files would not be flushed and nobody else
would flush that key (stale copy risk - exactly trap T3). Today comparison and key use the same
fold and agree. **CONVERT TOGETHER WITH the S5 disk-cache key group** (`fileswn2.cpp:1305`,
`fileswn5.cpp:787`, `fileswn6.cpp:3192`, `fileswn9.cpp:1225`, `cache.h` comparators) - not in S4.
Until then the byte fold errs on the safe side (flushes more).

### 3.2 `fileswn2.cpp:2127` and `:2234` - `ChangePathToArchive`
```
if (!Is(ptZIPArchive) || StrICmp(GetZIPArchive(), archive) != 0) // not the archive or a different archive
{ _REOPEN_ARCHIVE: ... list the archive ...
      BOOL isTheSamePath = FALSE;
      if (Is(ptZIPArchive) && StrICmp(GetZIPArchive(), archive) == 0)
      { ... if (GetArchiveDir()->SalDirStrCmp(buf, GetZIPPath()) == 0) isTheSamePath = TRUE; }
      CloseCurrentPath(HWindow, FALSE, detachFS, isTheSamePath, isRefresh, !isTheSamePath);
} else // already opened archive
```
Operands: the archive file open in the panel and the requested one - Windows file names, UTF-8.
2127 chooses "re-list the archive" vs "use the open listing"; 2234 (reached also by
`goto _REOPEN_ARCHIVE` when the file changed) decides the history flag. Today `ĥ.zip` requested
while `Ĺ.zip` is open shows the WRONG archive's listing; two case spellings re-list
unnecessarily. In the "already open" branch the panel keeps its own spelling, so its cache key
stays consistent. `SalDirStrCmp` (CSalamanderDirectory) is deferred and stays.
Replacements: `if (!Is(ptZIPArchive) || !SalNameEqualOrdinalCI(GetZIPArchive(), -1, archive, -1))`
and `if (Is(ptZIPArchive) && SalNameEqualOrdinalCI(GetZIPArchive(), -1, archive, -1))`.
**CONVERT both together** - medium (central navigation function).

### 3.3 `fileswn9.cpp:1240` - `OfferArchiveUpdateIfNeeded`
```
if (otherPanel->Is(ptZIPArchive) && StrICmp(GetZIPArchive(), otherPanel->GetZIPArchive()) == 0)
{ // the same archive is in the other panel, we must update it as well
```
Replacement: `SalNameEqualOrdinalCI(GetZIPArchive(), -1, otherPanel->GetZIPArchive(), -1)`.
Partner that stays on the byte fold by constraint 3: `salshlib.cpp:627`
(`StrICmp(ArchiveFileName, panel->GetZIPArchive())`) - record the disagreement.
**CONVERT TOGETHER WITH 3.2** - low/medium.

---

## 4. Prefix tests ("path A is under path B")

### 4.1 `fileswn7.cpp:2043-2051` - `AcceptChangeOnPathNotification`
```
lstrcpyn(path1, path, ...); lstrcpyn(path2, GetPath(), ...);   // both without trailing backslash
int len1 = (int)strlen(path1);
refresh = !includingSubdirs && StrICmp(path1, path2) == 0 ||       // exact match
          includingSubdirs && StrNICmp(path1, path2, len1) == 0 && // prefix match
              (path2[len1] == 0 || path2[len1] == '\\');
if (Is(ptDisk) && !refresh && CutDirectory(path1))
{   SalPathRemoveBackslash(path1);
    refresh = StrICmp(path1, path2) == 0; }
```
Operands: `path1` = the changed path from a notification (core operations, and plug-ins via
`PostChangeOnPathNotification`; an FS path can never equal a disk path - comment in the code),
`path2` = the panel path (for archives the archive's directory). The branch is taken only for
disk/archive panels that are not auto-refreshed. **Reversed order**: `path1` is the PREFIX,
`path2` the path. Replacement:
```
int n1 = 0;
refresh = !includingSubdirs && SalNameEqualOrdinalCI(path1, -1, path2, -1) ||
          includingSubdirs && SalPathHasPrefixOrdinalCI(path2, path1, len1, &n1) &&
              (path2[n1] == 0 || path2[n1] == '\\');
...
    refresh = SalNameEqualOrdinalCI(path1, -1, path2, -1);
```
Decides a panel refresh; a false "no" = a stale panel on a non-monitored (network) path, a
false "yes" = one extra refresh. Partner: 1.10 and the plug-in FS branch below it (untouched).
**CONVERT (three lines together)** - low.

### 4.2 `fileswnb.cpp:1194-1198` - `WM_USER_ENUMFILENAMES` (viewer next/previous file)
```
int pathLen = (int)strlen(GetPath());
if (StrNICmp(GetPath(), FileNamesEnumData.LastFileName, pathLen) == 0)
{ // "always true"
    const char* name = FileNamesEnumData.LastFileName + pathLen;
    if (*name == '\\' || *name == '/') name++;
```
Inside `if (Files != NULL && Is(ptDisk))`. **Reversed order**: the panel path is the prefix,
`LastFileName` (full name of the file the viewer shows) the path. The names compared right
after it were converted in S2 - this is the remaining half of the same decision. Replacement:
```
int pathLen = (int)strlen(GetPath());
int pathBytes = 0;
if (SalPathHasPrefixOrdinalCI(FileNamesEnumData.LastFileName, GetPath(), pathLen, &pathBytes))
{
    const char* name = FileNamesEnumData.LastFileName + pathBytes;
```
**CONVERT** - low. (The else branch is only a `TRACE_E`.)

### 4.3 `fileswn5.cpp:2149-2155` - `RenameFileInternal`
```
int otherPanelPathLen = (int)strlen(otherPanel->GetPath());
int pathLen = (int)strlen(path);
if (otherPanelPathLen >= pathLen &&
    StrNICmp(path, otherPanel->GetPath(), pathLen) == 0 &&
    (otherPanelPathLen == pathLen || otherPanel->GetPath()[pathLen] == '\\'))
{ otherPanel->HandsOff(TRUE); handsOFF = TRUE; }
```
**Reversed order**: `path` (full name of the item being renamed) is the prefix, the other
panel's path is the path. Decides whether the other panel releases its directory handles
before the rename (a false "no" can make renaming a directory fail). `otherPanelPathLen` has no
other use. Replacement:
```
int pathLen = (int)strlen(path);
int otherBytes = 0;
const char* otherPath = otherPanel->GetPath();
if (SalPathHasPrefixOrdinalCI(otherPath, path, pathLen, &otherBytes) &&
    (otherPath[otherBytes] == 0 || otherPath[otherBytes] == '\\'))
```
(no byte-length guard: the helper refuses a path shorter than the prefix). Same file as the S3
sites (`:2191, 2204, 2256`) - coordinate. **CONVERT** - low/medium.

### 4.4 `find.cpp:532` and `:540` - `CFindIgnore::Contains`
```
case fiitFull:
    if (item->Len > startPathLen && StrNICmp(path, item->Path, item->Len) == 0) return TRUE;
case fiitRooted:
    const char* noRoot = SkipRoot(path);
    if ((noRoot - path) + item->Len > startPathLen && StrNICmp(noRoot, item->Path, item->Len) == 0) return TRUE;
case fiitRelative:   // line 550: m = StrIStr(m, item->Path); ... (m - path) + item->Len > startPathLen
```
`item->Path` ends with a backslash and `item->Len` includes it (`Prepare`, `:494-496`), so no
`path[len]` test follows; but `item->Len` is also compared with `startPathLen` (bytes of the
searched path) - that arithmetic must use the bytes measured on `path`. Replacement:
```
int n;
if (SalPathHasPrefixOrdinalCI(path, item->Path, item->Len, &n) && n > startPathLen) return TRUE;
...
if (SalPathHasPrefixOrdinalCI(noRoot, item->Path, item->Len, &n) && (noRoot - path) + n > startPathLen) return TRUE;
```
The relative kind (`StrIStr`, a byte-fold substring search) has **no helper** and stays; after
the change the full/rooted kinds are Unicode-aware and the relative kind is not. That is three
independent branches, not a chain, and nothing gets worse - but it must be recorded as deferred.
Runs on the Find thread (`find.cpp:1542`); helper is re-entrant. **CONVERT 532 + 540 together** -
low/medium. (If the reviewer prefers one consistent rule per feature: leave all three and record.)

### 4.5 `shares.cpp:270` - `CShares::GetUNCPath`
```
int itemNameLen = (int)strlen(item->LocalPath);
if (StrNICmp(buff, item->LocalPath, itemNameLen) == 0)
{ if (longestIndex == -1 || (int)strlen(Data[longestIndex]->LocalPath) < itemNameLen) longestIndex = i; }
...
if (strlen(item->LocalPath) < strlen(path))
{ const char* s = path + strlen(item->LocalPath); if (*s == '\\') s++; strcat(unc, s); }
```
`buff` = `path` + backslash; `LocalPath` = shared folder. The later `path + strlen(LocalPath)`
is the "index by prefix length" pattern, twenty lines away from the comparison. Replacement:
keep the bytes of the winning item:
```
int n;
if (SalPathHasPrefixOrdinalCI(buff, item->LocalPath, itemNameLen, &n))
{ if (longestIndex == -1 || (int)strlen(Data[longestIndex]->LocalPath) < itemNameLen) { longestIndex = i; longestBytes = n; } }
...
if (longestBytes < (int)strlen(path))
{ const char* s = path + longestBytes; ...
```
Existing weakness, NOT to be fixed here: no component-boundary test (`C:\foo` matches
`C:\foobar\`). **CONVERT** - medium for its value (bookkeeping across the loop); acceptable to
defer with the rest of the shares code.

### 4.6 `cache.cpp:365`, `:662`, `:667` - `CCacheDirData::ContainTmpName` / `DetachTmpFile`
```
if (rootTmpPathLen < PathLength && StrNICmp(Path, rootTmpPath, rootTmpPathLen) == 0)
{ const char* s = Path + rootTmpPathLen; ...
---
if (StrNICmp(tmpName, Path, PathLength) == 0)
    ... if (StrICmp(Names[i]->GetTmpName() + PathLength, tmpName + PathLength) == 0)
```
Operands: the cache's own tmp directory, the tmp root (may be supplied by a plug-in through the
disk-cache service) and a tmp file's full name. Partner: `CCacheData::TmpNameEqual`
(`cache.h:88-89`, `StrICmp`), used a few lines below 365 for the same identity. Would become
`SalPathHasPrefixOrdinalCI(Path, rootTmpPath, rootTmpPathLen, &n)` + `Path + n`, and
`SalPathHasPrefixOrdinalCI(tmpName, Path, PathLength, &n)` + `tmpName + n` (while
`GetTmpName() + PathLength` stays - that name is built from `Path`).
**CONVERT TOGETHER WITH the S5 cache group** (`cache.h:88-89`) - not in S4.

### 4.7 `dialogs5.cpp:784`, `plugins2.cpp:1386`, `:3008`, `:3443` - "is the DLL under <install>\plugins"
```
if (StrNICmp(oneName, buf, (int)strlen(buf)) == 0 && oneName[(int)strlen(buf)] == '\\')
    memmove(pluginName, oneName + strlen(buf) + 1, strlen(oneName) - strlen(buf) + 1 - 1);
```
The prefix is built from `GetModuleFileName(HInstance, ...)` - the ANSI API - so it is
code-page text; at 784 the other operand comes from the ANSI open-file dialog, at 1386 from the
registry. The stripped name is then matched by `CPlugins::FindDLL` (`plugins2.cpp:2656`,
`StrICmp`). **DO NOT CONVERT** - operands are not (reliably) UTF-8; four sites + `FindDLL` form
one chain that belongs to the install-path / ANSI-window work.

### 4.8 `shellib.cpp:1581-1583` and `:1862`
```
if (enumNamePrefix != NULL && StrNICmp(name, enumNamePrefix, enumNamePrefixLen) == 0 &&
        name[enumNamePrefixLen] == '\\' && StrICmp(name + enumNamePrefixLen + 1, fileName) == 0 ||
    enumNamePrefix == NULL && StrICmp(name, fileName) == 0) // we found the share we were looking for
---
if (strlen(name) <= 3 && StrNICmp(name, root, 2) == 0) // name = "c:" or "c:\"
```
1581: `name` is a shell display name of a network share; depending on the `STRRET` kind it is
UTF-8 (WSTR) or ANSI (CSTR / OFFSET) - mixed encodings; share names, not file-system names; not
testable without a share with a non-ASCII name. **DO NOT CONVERT** (I did not trace all callers).
1862: two bytes, a drive letter. **DO NOT CONVERT** - ASCII by construction.

### 4.9 x86-only prefix tests
`fileswn3.cpp:1812`, `:1940` (`StrNICmp(winDir, path, len)` then `path + len` - reversed order)
and `fileswn1.cpp:2334, 2361, 2379` (`StrNICmp(path, dirName, len) == 0 && (path[len] == '\\' ||
path[len] == 0)`, then `path + len`). **DO NOT CONVERT** - `#ifndef _WIN64`.

### 4.10 `salamdr5.cpp:767` - `SalParsePath`
`if (curArchivePath != NULL && StrICmp(path, curArchivePath) == 0)` - **DO NOT CONVERT**,
exported function (`zip.cpp:2817`; called by ftp, undelete, demoplug).

---

## 5. Totals

54 candidate lines examined.

| verdict | lines | which |
|---|---|---|
| CONVERT in S4 | **31** | 1.1, 1.3 (2), 1.4, 1.5, 1.6, 1.7, 1.9, 1.10, 1.11, 1.14, 1.16 (12); 2.1, 2.2, 2.3 (2), 2.4 (2), 2.5, 2.6 (8); 3.2 (2), 3.3 (3); 4.1 (3), 4.2, 4.3, 4.4 (2), 4.5 (8) |
| move to S5 (cache pair) | 4 | `fileswn2.cpp:1303`; `cache.cpp:365, 662, 667` |
| not converted - x86-only code | 8 | `fileswn3.cpp:131, 1771, 1812, 1864, 1940`; `fileswn1.cpp:2334, 2361, 2379` |
| not converted - inside an exported global | 3 | `salamdr5.cpp:767, 1145`; `salamdr1.cpp:1418` |
| not converted - operands are code-page text / mixed | 5 | `dialogs5.cpp:784`; `plugins2.cpp:1386, 3008, 3443`; `shellib.cpp:1581` |
| not converted - not a path / ASCII / encoding unknown | 3 | `mainwnd2.cpp:677`, `shellib.cpp:1862`, `drivelst.cpp:110` |

Seen on the way, outside the task's list and not analysed: `dialogs3.cpp:1962, 2101, 2206`
(`StrICmp(Path, PathAlt)`), `dialogs6.cpp:1134`, `salamdr3.cpp:3119, 3433` (CFileTimeStamps
source path), `fileswn6.cpp:689`, `shellib.cpp:1970`, `plugins2.cpp:2656`.

## 6. Suggested split (lowest risk first)

**Group A - whole-path equality, panel-local, no length arithmetic (15 lines):**
`dialogs5.cpp:1851` + `mainwnd2.cpp:3296`; `fileswn1.cpp:226, 228, 373`;
`fileswn2.cpp:412, 1757, 1829, 2052`; `fileswn7.cpp:2091`; `fileswnb.cpp:657, 873`;
`shellsup.cpp:1852`; `salamdr3.cpp:3502, 3534`.

**Group B - identity with consequences: history, archives, an operation (8 lines):**
`salamdr3.cpp:1696, 1703`; `fileswn2.cpp:2127, 2234` + `fileswn9.cpp:1240`;
`fileswn6.cpp:698`; `find.cpp:628`; `shares.cpp:235`.

**Group C - prefix tests using the returned byte count (8 lines):**
`fileswn7.cpp:2043, 2044, 2051`; `fileswnb.cpp:1194`; `fileswn5.cpp:2153`;
`find.cpp:532, 540`; `shares.cpp:270`.

## 7. Evidence-probe scenarios (verbatim pre/post bodies, the 075 pattern)

Pre-fix bodies need a `LowerCase[]` built for a chosen code page (1250), per research 7.2.

1. `IsTheSamePath` vs `SalPathEqualOrdinalCI`: ASCII parity over the backslash matrix (leading,
   trailing, double trailing, UNC, empty, root `C:\`); `C:\Dokumenty\Článek` vs
   `c:\dokumenty\článek` (was different -> same); `C:\ĥ` vs `C:\Ĺ`, `Č` vs `Ĝ` (was same on
   CP1250 -> different); `straße`/`strasse`, NFC/NFD (different both before and after).
2. `SamePath`, `CTopIndexMem::Push/FindAndPop`, `AddUnique`, `PrepareSearch` - the
   `l1 == l2 && StrNICmp` shape: a pair with a length-changing case pair (`ⱥ` U+2C65 / `Ⱥ`
   U+023A) must be equal although the byte lengths differ; trailing backslash on either side;
   `Push` with `path == Path + "\name"` in mixed case, with `s == path`, with an empty `Path`;
   push then pop in the other spelling returns the stored index.
3. Reversed-order prefix sites (4.1, 4.2, 4.3): prefix equal in another case; prefix followed
   by `\`, by end, by another letter (`C:\foo` vs `C:\foobar` must not match); the
   length-changing pair inside the prefix - the character after the prefix is read at the
   returned count (with `path[len]` the probe must show the wrong byte); prefix cut inside a
   multi-byte character and inside a surrogate pair -> no match; prefix longer than the path;
   empty prefix; a path > 520 units (heap path); invalid UTF-8 in the path -> legacy answer.
4. `AcceptChangeOnPathNotification` as a whole: exact, including-subdirs, and the parent
   directory fallback, each in both spellings; a plug-in FS style path (`ftp://...`) never
   matches a disk path.
5. `CFindIgnore::Contains`: full and rooted items with accented case variants; the
   `startPathLen` rule (an item equal to or above the search root is not ignored) with a
   length-changing pair; the relative kind unchanged (documented).
6. `CPathHistoryItem::IsTheSamePath`: disk and archive types in both spellings; archive with
   the same file and an inner path differing only in case stays different; the FS type
   byte-for-byte unchanged (same verdict before and after for every row).
7. Archive identity (3.2, 3.3): `Č.zip`/`č.zip` -> same; `ĥ.zip`/`Ĺ.zip` -> different; and a
   row showing 1303 still answers by the old rule (so the flush key and the comparison agree
   until S5).
8. `GetUNCPath`: the tail appended after the share is taken at the returned byte count.
9. ASCII-only table for every converted body: identical verdicts before and after (SC-002).

GUI steps that stay owed to a person: Change Directory typed in the other case of an accented
folder (no second history entry, cursor memory survives), Alt+F12 history after it, F3 next/
previous file in such a folder, renaming a directory that the other panel shows under another
spelling, an archive opened under two spellings in the two panels.
