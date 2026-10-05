# Research: feature 115 - measured by code reading

No GUI run was possible today (the maintainer used the installed program, which shares
`HKCU\Software\Tandem Commander` with every probe). Every statement below is from the code of HEAD
b06ff2b9 (= `Debug_x64_pre115`); the pending probe (`quickstart.md`) measures it in the program.

## 0. The machine (read-only checks)

- Windows 11 Pro; `C:\Windows\system32\cipher.exe` present. The user has **no EFS certificate**
  (`Cert:\CurrentUser\My`, EKU 1.3.6.1.4.1.311.10.3.4: 0) - `cipher /e` would create one, so it
  was **not run**; a real EFS backup (`.bak` with the ROBS signature) cannot be made: that route is
  NOT DRIVEN.
- `GetVolumeInformationW`: C:\ and D:\ NTFS, flags 0x03E72EFF - FILE_SUPPORTS_ENCRYPTION is set,
  so Restore Encrypted Files accepts a target there. Plain files (no `.bak`) take its copy route
  (`RestoreFile` copies and calls `SetFileAttributesW(attr | FILE_ATTRIBUTE_ENCRYPTED)`, which does
  not encrypt - the bit is not settable by that call; the target is created by `SafeFileCreate`,
  which masks the attribute away). The walk - the defect - is therefore drivable without EFS.

## 1. Restore Encrypted Files from Backup (`restore.cpp`)

Command `CMD_RESTORE_ENCRYPTED` (Plugins > Undelete), both panels on disk; the Restore dialog's
target is at most 259 bytes (104 refuses a longer one).

- **The source panel's path**: `GetPanelPath(PANEL_SOURCE, sourcePath, MAX_PATH)` unchecked. The
  core returns FALSE with `buffer[0] = 0` when the path does not fit (`zip.cpp`), so a panel in a
  folder of 260+ bytes gave `""`: every selected name was then used as a **relative** path
  (`SalPathAppend("", name)` = `name`) - resolved against the process's current directory; the
  source open fails (an error), a selected folder is created empty in the target.
- **`GetDirSize`** (the size estimate, runs first): appends into the caller's
  `sourcePath[MAX_PATH]` with `SalPathAppend(path, dirname, MAX_PATH)` - result ignored. When the
  name does not fit, `path` stays the PARENT; `strcat(path, "\\*")` writes up to 2 bytes past the
  260-byte buffer (a stack overrun); the parent is listed, it holds the same folder name, and the
  function calls itself with the same arguments - **endless recursion, a stack overflow**. Reached
  as soon as a folder of the selection lies at 259+ bytes.
- **`RestoreDir` / `RestoreFile`**: `char srcpath[2 * MAX_PATH], dstpath[2 * MAX_PATH]`, both
  appends ignored. A name that does not fit leaves the parent's path: `RestoreDir` lists the parent
  again (endless) and `RestoreFile` restores into the parent's target folder / opens the folder as
  a file. In the build before this is **not reachable on its own**: `GetDirSize` overflows at
  259 bytes first, before the restore starts (the 520-byte limit is never reached).
- **Directory links**: followed without a check - a junction to an ancestor recursed until the
  259-byte limit, then as above (a crash).
- **The target inside the selection** (e.g. restoring `deep` into `deep\out`): the walk enters the
  target, creates copies inside it, enters them - endless until the limit (a crash).
- `static WIN32_FIND_DATAW fd` shared by the recursion: correct only because it is re-filled by
  `FindNextFileW` after each recursive call.
- `RestoreFile`: `real = TRUE` after the `.bak` test and set to FALSE only when the 12 signature
  bytes WERE read and differ - a `.bak` shorter than 12 bytes (or unreadable) counted as a real
  backup and went to `OpenEncryptedFileRawW` / `WriteEncryptedFileRaw` ("Could not undelete
  encrypted file"). `PVOID context` uninitialised and `CloseEncryptedFileRaw(context)` called
  also when `OpenEncryptedFileRawW` failed (the same in `fs2.cpp CopyFile`). When the target could
  not be created (Cancel in the overwrite dialog) the source stayed open (handle leak).
- Progress labels: `CCopyProgressDlg::SetSourceFileName` / `SetDestFileName` keep 1040 bytes with
  `lstrcpyn` - a longer path lost its END (the name) and could end inside a character.

## 2. `RemoveDuplicateFiles` (`fat.h`)

- `DATA_POINTERS` under `#pragma pack(4)` (x64): StartVCN 0-7, LastVCN 8-15, DPFlags 16-19, Runs
  (pointer) 20-27, RunsSize 28-31, CompUnit 32-35, DPNext 36-43 = **44 bytes**.
- `memcmp(r1->Streams->Ptrs, r2->Streams->Ptrs, (size_t)r1->Streams->DSSize)`: DSSize = the FILE
  size. Up to 20 bytes it compares StartVCN (0), LastVCN ((size - 1) / cluster size = 0) and
  DPFlags (0) - **equal for every two such files**: a different small file of the same name was
  removed from {All Deleted Files} (still listed in its folder). Above 20 bytes it reaches the
  `Runs` pointer - two allocations, never equal: **a true duplicate was never removed**; above 44
  bytes it reads past the allocation.
- Where duplicates come from: `LoadDeletedDirectories` reads a deleted directory's cluster again
  when another deleted directory entry points to it (the `MARK_DEL_DIR` test is commented out on
  purpose: "maybe we will present some item multiple time"), e.g. a directory moved and then
  deleted - every file of it appears twice in {All Deleted Files} (the same records' data runs).
- The sort is by name only: with three items "a" (X), "a" (Y), "a" (X) the old neighbour test
  could not find the third X.
- Only the FAT snapshot has this; exFAT and NTFS build {All Deleted Files} without it.

## 3. Name identity

`_stricmp` (C locale: A-Z folded, bytes >= 0x80 raw) at: `fs2.cpp namecmp` (ChangePath's
component lookup), `compare_items` + `CFileList::RenameDuplicateFiles` (the numbering of every
restore list - NTFS, FAT, exFAT, {All Deleted Files}), and through `String<char>::StrICmp` in
`fat.h compare_names` / `RenameDuplicateDirectories` (the FAT listing numbers deleted files of one
name in one folder) / `RemoveDuplicateFiles`. `<C-caron>.txt` (C4 8C) and `<c-caron>.txt` (C4 8D)
were two names: not numbered; restoring both, the second met the first in the target (one file
for Windows) - an overwrite prompt; Yes overwrote the first restored file.

Not converted (no identity of files): `CTopIndexMem` `StrNICmp` (the remembered scroll position of
a path), the `.bak` extension test, `ntfs.h` comparisons with ASCII literals (`$EFS`, `$MFT`, `.`,
`$Bitmap`), `volenum.h` (volume / file-system names).

## 4. Sweep of the restore and encrypted code

Fixed:

- **F3 on a deleted file with a long name** (`fs2.cpp CopyFile`, view branch): `lstrcpyn(path,
  targetPath, MAX_PATH)` - `targetPath` is the disk-cache copy's full name (TEMP + `SALxxxx.tmp\` +
  the file's name, up to 765 bytes): cut at 259 bytes, maybe inside a character. The copy was
  written under the cut name (or failed), the viewer opened the full name - never written. Every
  file system; a name of about 70 CJK characters is enough.
- **Failed restore of an encrypted file in backup form** (`CopyFile`): the target is
  `<name>.bak`; the cleanup set `*pathend = 0` and deleted `<name>` - a file this restore never
  created (the user's own, if one was there). Needs EFS-encrypted deleted files on NTFS.
- **`UndeleteGetResolvedRootPath`**: `strcpy(resolvedPath[MAX_PATH], path)` - `path` is the main
  restore's target (a buffer of 2 x MAX_PATH) or the disk-cache name of an encrypted file being
  viewed (up to ~1 KB): a stack overrun. Encrypted files only.
- **`AppendPath`**: `lstrcpyn(buffer, path, MAX_PATH)` cut a longer target; only the full buffer
  then made the append fail. Now refused explicitly ("Target path is too long").
- `CopyFile`: `SourcePath` (the progress text) was not restored on two early returns.

Recorded, not changed:

- `ViewFile`'s disk-cache key `uniqueFileName[2 * MAX_PATH]`: the name append fails for a long
  name (the key then lacks the name) - still unique per item by its `%IX` pointer prefix within a
  snapshot; a stale cached copy after a rescan that reuses the address is conceivable (not
  measured).
- Numbering can produce a name that another listed item already has (`a.txt` x 2 and `a (1).txt`):
  the restore then meets an existing file - an overwrite prompt (every release; ASCII too).
- A file restored onto itself by Restore Encrypted Files (target = source folder): the source is
  open with `FILE_SHARE_READ`, the target create fails - an error, nothing lost (the "todo" of
  `RestoreEncryptedFiles`; restoring backups in place is legitimate, so it is not refused).
- 114's Debug-only items (trace paths, `TestUndeleteOnExistingFile`) and `OS_GetDriveFormFactor`.
