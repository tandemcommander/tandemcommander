# Research for feature 103: an existing target that is the source itself

Branch `103-same-file-delete-guard` (from `102-filecomp-unicode-names`, HEAD 0f79f578),
2026-10-03. Machine: Windows 11 10.0.26200, ACP 1250, user not elevated; C: has 8.3 names,
D: does not. Pre-change build preserved as `build\tandemcommander\Debug_x64_pre103`.
Scratch probes (not in the repository): `fsprobe*.ps1` in the session scratchpad (P/Invoke
`MoveFileW`, `CreateFileW`, `GetFileInformationByHandle(Ex)`, `DeleteFileW`). The committed
probe `probe/samefile_probe.ps1` drives the program; `probe/davnorm.py` is the test server.

The defect (recorded by 092 S3, `specs/092-name-identity-unicode/fix-log.md` "Recorded, not
changed" item 1; `specs/NEXT-WORK.md` item 5, "the first thing to do here"): when a rename or
move meets "already exists", the program decides by the two NAMES whether the existing target
is another file, and if the names differ it deletes the target and retries. If the target is
the source under another spelling, the user's file is deleted.

## 0. Headline

1. **Reproduced locally, on the build before this feature, with real data loss on four
   routes** - without a macOS server. A small standard-library WebDAV server
   (`probe/davnorm.py`) whose name lookup folds like a macOS server (NFC/NFD and case are one
   entry) makes the Windows WebDAV redirector answer a rename onto another spelling of the
   same file with ERROR_ALREADY_EXISTS (183) - exactly the server answer the defect needs:
   - **Quick Rename** `cafe`+U+0301`.txt` (stored NFD) -> `Caf`+U+00E9`.txt` (typed): the
     program showed *Confirm File Overwrite* with two identical lines (same size, same time),
     the answer Yes sent `DELETE` for the "target", the server deleted the file, the retry got
     404, the user saw "(31) A device attached to the system is not functioning" - **file gone**;
   - **F6 to another name in the same folder**: the same, error "Error Moving File" - **gone**;
   - **the same with "Confirm file overwrite" off**: no question at all, one error - **gone**;
   - **F6 between the two names of the server** (`\\localhost@port` and `\\127.0.0.1@port`, one
     file under two server names - a different root, so the move is copy + delete): the overwrite
     question, then the copy rewrote the file onto itself and the move **deleted the source,
     i.e. the only copy - gone**. Nothing in Windows stops this on WebDAV: the redirector keeps a
     separate local cache per name, so the source's open handle does not block the target's
     `CREATE_ALWAYS` (measured: the server's file is truncated to 0 bytes by that open).
2. **NTFS itself never answers "already exists" for the same file**: a rename onto its own
   hard link, its own 8.3 name or through a junction alias is answered with success by
   `MoveFileW` (measured, section 2). The program's rename branch therefore meets "the target
   is the source" only on other file systems / servers. **Copies are different**: a copy (or a
   move between two roots) onto an alias of the source (SUBST, `\\localhost\C$`, a junction,
   a second server name) reaches the overwrite path on every file system. On NTFS/SMB the
   source's open read handle (no `FILE_SHARE_DELETE`, and the target's `CREATE_ALWAYS` asks for
   share mode 0) makes the destructive step fail with a sharing violation - the data survived
   every local alias case, but only by that accident: the user was first asked to overwrite the
   file with itself and then shown "Error Deleting File (32)".
3. **The identity is available**: `GetFileInformationByHandle` (volume serial + 64-bit index)
   and `GetFileInformationByHandleEx(FileIdInfo)` (64-bit serial + 128-bit id) after an open
   with `FILE_READ_ATTRIBUTES` only. Over SMB (`\\localhost\D$`) both return exactly the
   local values. **WebDAV returns serial 0, index 0, link count 1 and no FileIdInfo** - so an
   identity rule needs a fallback, and the fallback must never conclude "different, delete it"
   from weak evidence.
4. **Rule chosen** (section 5): never delete or open-for-overwrite a target that is - or cannot
   be shown not to be - the source. A rename/move goes through a temporary name in the
   source's folder (source -> `salXXX` -> target), which checks itself: if the target name
   disappears with the source out of the way it WAS the source and the rename completes; if it
   is still there it is another file (or another hard link) and the old handling follows
   unchanged. A copy (or a move done as copy + delete) onto the source itself is refused with
   the existing text "Cannot copy (move) a file to itself." Hard links of the source keep the
   old behaviour.
5. **Sites**: two core rename sites (`DoMoveFile`, `RenameFileInternal`), the core copy site
   (`DoCopyFile`, which also carries every move between two roots), and two plug-in rename sites
   found by the sweep (Renamer `CRenamerDialog::MoveFile`, PictView's rename of the viewed
   file). Everything else that deletes an existing target has no user-named source or
   restores what it renames (section 1).

## 1. Every place that deletes or overwrites an existing target

"Identity before" = what decided that the existing target is not the source. "Same file
possible" = can the target be the source under another name/path. "Loss on pre-103" = measured
with `probe/samefile_probe.ps1` (section 4) where a local reproduction exists.

| # | Site | What it does on "exists" | Identity before | Same file possible | Loss on pre-103 | 103 |
|---|---|---|---|---|---|---|
| 1 | `worker.cpp DoMoveFile`, same root (F6/drag/paste move, *Change Case*, directory moves inside one root) | DOS-name tidy-up (rename the 8.3 collider away and back), then for files: overwrite question (or none: confirmations off, *Overwrite All*, *Overwrite older*), clear read-only, **`DeleteFile(target)`**, retry `MoveFile` | names: `SalNameEqualOrdinalCI(full source path, full target path)` (092) - "different names = another file" | yes: another spelling on a folding server; an alias path is answered by NTFS itself | **yes**: dav-mov (asked, then gone), dav-msil (not asked, gone) | identity first; same / possibly same -> temporary name |
| 2 | `worker.cpp DoMoveFile`, different roots (SUBST letter vs its folder, UNC vs local, two server names, another volume) | `DoCopyFile`, then **`DeleteFile(source)`** if the copy succeeded | `strcmp` of the paths at script build (`fileswn6.cpp BuildScriptFile`) | yes: any alias root | **yes**: dav-xmov (asked, copy onto itself, source deleted = gone). SUBST/UNC/junction: survived (share mode, see #3) | covered by #3: the copy refuses, so the source is not deleted |
| 3 | `worker.cpp DoCopyFile`, `CREATE_ERROR` exists (F5, and #2) | overwrite question, then **`CREATE_ALWAYS`** share 0 (truncates), or **`DeleteFile(target)`** + create when the target cannot be opened for writing / `mustDeleteFileBeforeOverwrite` | full paths at script build: `SalNameEqualOrdinalCI` -> "Cannot copy a file to itself." only for the same path string | yes: any alias | not lost, but only because the source's read handle blocks the target's share-0 open and its deletion (`ERROR_SHARING_VIOLATION`, NTFS/SMB); on WebDAV that handle blocks nothing - `CREATE_ALWAYS` truncated the server file and the copy loop rewrote it from the cached source (dav-xcpy: survived, user asked "overwrite x.txt with x.txt") | identity (source from the open handle); same -> refused with "Cannot copy (move) a file to itself." |
| 4 | `fileswn5.cpp CFilesWindow::RenameFileInternal` (Quick Rename, F2) | DOS-name tidy-up, then *Confirm File Overwrite* (always asked), **`DeleteFile(target)`** + `MoveFile` | names (092), as #1 | yes: folding server | **yes**: dav-qren | as #1 |
| 5 | `worker.cpp SalCreateFileEx` (copy target / new file colliding with an 8.3 name) | renames the colliding entry to `salXXX`, creates, renames it back | names (DOS name vs long name) | the collider can be the source only through an alias; the source is then open without `FILE_SHARE_DELETE` -> the rename fails -> nothing happens | no | unchanged (and #3 now refuses before) |
| 6 | `worker.cpp SalCreateDirectoryEx` (directory creation colliding with an 8.3 name) | renames the collider away and back | names | not a source/target pair; the collider is restored | no | unchanged |
| 7 | `worker.cpp DoCreateDir` "directory overwrite" | merges into the existing directory - deletes nothing | - | - | no | unchanged |
| 8 | `fileswn5.cpp:1573` new file (Shift+F4) | `SalCreateFileEx` `CREATE_NEW` - no source | - | - | n/a | unchanged |
| 9 | `fileswn6.cpp` *Change Case* (`AlterFileName`, B-4) | builds `ocMoveFile`/`ocMoveDir` in the same folder -> #1 | the new name differs only in case (by `AlterFileName`) | on a folding server: the case change of an NFD name is case-only for Windows too -> old code showed an error, no deletion | no | the temporary-name route performs the change when the server refuses it |
| 10 | `viewer3.cpp` *Save selection as* over an existing file | writes a temp file first, then deletes the target and renames the temp (comment: "because of self-overwrite") | - | the data comes from the viewer's buffer, already written | no | unchanged |
| 11 | `pack1.cpp`/`pack2.cpp`, archive unpack (`SafeFileCreate` overwrite, plug-ins' extract) | overwrite with data from an archive or a temp folder | - | the source is not a disk file named by the user | n/a | unchanged |
| 12 | Renamer plug-in `rendlg3.cpp CRenamerDialog::MoveFile` (batch rename; also its Undo) | `SalMoveFile`; on exists **`DeleteFileU8(target)`** + retry (asks unless "overwrite") | `SG->StrICmp` - the code-page byte fold (`Č`/`č` count as different) | yes: folding server | not driven (no GUI driver for the plug-in) | as #1 |
| 13 | Renamer `CopyFile` (between two roots) + delete source | `OPEN_ALWAYS` share 0 + `SetEndOfFile` | none | yes | protected by the open source handle (share mode), as #3 | unchanged (recorded) |
| 14 | PictView `render1.cpp CRendererWindow::RenameFileInternal` (rename the viewed file) | *Confirm File Overwrite*, **`DeleteFileW(target)`** + `SalMoveFile` | `SalamanderGeneral->StrICmp` (byte fold) | yes: folding server | not drivable: the viewer keeps the shown image open, its Rename fails with error 32 on every file system (measured on both builds) | as #1 |
| 15 | ZIP plug-in: self-extractor / multi-volume first volume / next volume (`add.cpp PackSelfExtract`, `PackMultiVol`, `CreateNextFile`) | `CREATE_ALWAYS` of the new archive's file after "overwrite?" | none against the selection | only when a selected source IS the new archive name - the user confirmed overwriting that file; another defect class | n/a | recorded, not changed |
| 16 | FTP / SFTP plug-ins | never rename or move local files; download overwrite writes server data; upload-*Move* deletes the local source after the upload | - | n/a | n/a | unchanged |

Plug-in sweep (all 20 enabled plug-ins, `plugins.cfg`): only #12-#15 touch existing local
targets with a user-named local source; 7zip/zip/tar/uncab/uniso extraction, ftp/sftp
downloads, checksum/regedt/peviewer saves and every move-to-archive cleanup were checked and
are not this class (move-to-archive cleanups are protected by the archive's open handle).

## 2. Measurements: what Windows answers

`MoveFileW` (no `MOVEFILE_REPLACE_EXISTING`), then what is on disk:

| Situation | Answer | Result |
|---|---|---|
| NTFS, `longfilename.txt` -> its own 8.3 name `LONGFI~1.TXT` (C:) | success | nothing changes (name stays long) |
| NTFS, `dir\a.txt` -> `junc\a.txt` (junction to `dir`) | success | no-op |
| NTFS, `dir\a.txt` -> `junc\A.txt` / `junc\b.txt` | success | renamed |
| NTFS, `a.txt` -> `b.txt`, `b.txt` a hard link of `a.txt` | **success** | only `b.txt` remains (one link fewer) |
| SMB `\\localhost\D$\x\a.txt` -> `\\localhost\D$\x\A.txt` | success | case changed |
| SMB onto another existing file | 183 | - |
| local `D:\x\a.txt` -> `\\localhost\D$\x\a.txt` (same file) | **80** ERROR_FILE_EXISTS (cross-volume copy semantics) | nothing |
| SUBST `T:` = `D:\x`: `D:\x\A.txt` -> `T:\A.txt` | success | no-op (one volume) |
| WebDAV (davnorm.py), NFC -> NFD spelling of the same file | **183** | - |
| WebDAV, another file -> an existing spelling | 183 | - |

Identity (`CreateFileW(FILE_READ_ATTRIBUTES, share all, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS)`):

| Path | Volume serial | File index | Links | FileIdInfo |
|---|---|---|---|---|
| `D:\...\a.txt` | `BC2A09A9` | `00290000000B93DF` | 1 | serial `FABC2A52BC2A09A9`, id `...00290000000B93DF` |
| `\\localhost\D$\...\a.txt` (same file) | `BC2A09A9` | same | 1 | same |
| `T:\a.txt` (SUBST) | same | same | 1 | same |
| `dir\a.txt` / `junc\a.txt` | equal | equal | 1 | equal |
| hard links `a.txt` / `b.txt` | equal | equal | **2** | equal |
| WebDAV `\\localhost@18103\dav\x.txt` | **0** | **0** | 1 | **error 1** |

Share modes (NTFS): with `a.txt` open `GENERIC_READ`, share read+write:
`CREATE_ALWAYS` share 0 on its hard link `b.txt` -> 32 (sharing violation); opening `b.txt`
for writing with share read+write -> success; **`DeleteFileW(b.txt)` -> success** (a link that
is not the last one is removed even though the file is open without `FILE_SHARE_DELETE`). That
is why the old copy onto a hard link of itself ends with an independent copy, not a loss.

WebDAV, one file under two server names: source open `GENERIC_READ` through `\\localhost@port`
(the redirector downloads it), then `CREATE_ALWAYS` share 0 through `\\127.0.0.1@port` ->
**success**, the server's file is **0 bytes** (LOCK, PUT empty) - no protection at all.

## 3. How to recognise "the target IS the source"

- **The id**: compare (volume serial, file index) from `GetFileInformationByHandle`, and the
  128-bit `FileIdInfo` when both sides have it (ReFS: the 64-bit index is not guaranteed unique;
  the SDK declares `FILE_ID_INFO` only for `_WIN32_WINNT >= 0x0602` - mirrored locally, the
  feature 059 precedent). An id of all zeros or all ones is "no id" (WebDAV: 0). Two different
  non-zero volume serials prove two files even without ids.
- **The open**: `FILE_READ_ATTRIBUTES` only - such an open ignores share modes (works on a file
  someone holds exclusively) and does not start a WebDAV download (measured: PROPFIND only);
  `FILE_FLAG_BACKUP_SEMANTICS` for directories; `FILE_FLAG_OPEN_REPARSE_POINT` for a rename
  (MoveFile renames a symbolic link itself), not for a copy (the data is read and written
  through links). If the open fails, `GetFileAttributesEx` still gives the metadata.
- **No id** (WebDAV, some servers): size + last-write second + creation second (whole seconds:
  a server may round; a missing creation time is not compared) + kind. Equal metadata means
  "possibly the same", never "different"; different metadata means "not the same file" (one
  file read twice a moment apart has one size and one write time).
- **Hard links** (equal ids, link count > 1): the target may be another link (deleting that name
  keeps the data under the source's name - the old behaviour is safe) or, on a folding server,
  another spelling of the same link. The ids cannot tell these apart; the temporary-name route
  can (below), so for a rename the link count does not change the route. For a copy the old
  handling is kept for link count > 1 (section 2: NTFS removes the other link and writes an
  independent copy; the source's name and data stay).
- **The temporary-name route checks itself**: source -> `salXXX` in its own folder (an
  8.3-compliant name, no short name generated, retried while taken), then `salXXX` -> target
  without replace. If the second step succeeds the target name was the source's; if it says
  "already exists", the target is a different entry - another file or link - and the source is
  renamed back for the old handling (overwrite question etc.), which is then safe. Any other
  failure renames back and reports the error; if even the way back fails the error names the
  temporary path (the file is never left there silently). Measured on the WebDAV server
  (dav-twin: two different files with equal size and times - the route told them apart and the
  old overwrite followed).
- **Considered, not used**: comparing contents (cost, overlapped handles); a rename of the
  TARGET to test the source's existence (the WebDAV redirector caches attributes and "not
  found" for up to 60 s - a stale answer would make it unsafe); keying the rename rule on the
  link count (it would delete the source's name in the "folding server + hard-linked file" case,
  which the self-check handles).

## 4. Local reproduction: `probe/samefile_probe.ps1` on the build before 103

23 cases x the route (qren = Quick Rename, mov = F6, cpy = F5), confirmations on except
dav-msil. Result `probe/samefile_result_pre103.txt`: **4 cases lost the file**, 19 kept it.

| Case | Alias | Route | Asked (pre-103) | Data |
|---|---|---|---|---|
| dav-qren | NFD stored, NFC typed (folding WebDAV) | qren | overwrite (identical lines) -> "(31) device not functioning" | **lost** |
| dav-mov | same | mov | overwrite -> "Error Moving File (31)" | **lost** |
| dav-msil | same, *Confirm file overwrite* off | mov | only the error | **lost** |
| dav-xmov | one file, two server names | mov | overwrite | **lost** (copy onto itself, then the source deleted) |
| dav-xcpy | same | cpy | overwrite x.txt with x.txt | kept (rewritten onto itself) |
| dav-norm, dav-twin | different files (twin: equal size + times) | mov | overwrite | overwritten as asked |
| dav-twcp | different files, equal size + times | cpy | overwrite | overwritten as asked |
| junc-mov | junction alias of the folder | mov | nothing (NTFS no-op) | kept |
| junc-cpy / subst-* / unc-* | junction / SUBST / `\\localhost\C$` | cpy, mov | overwrite, then "Error Deleting File (32)" | kept (share mode) |
| hl-qren, hl-mov | hard link | qren, mov | nothing (NTFS renames link onto link) | kept |
| hl-cpy | hard link | cpy | overwrite | kept (independent copy) |
| cs-qren | case-sensitive folder, `a.txt` and `A.txt` two files | qren | "(183) already exists" | kept |
| 8dot3-qren | own 8.3 name | qren | nothing (no-op) | kept |
| case-qren, norm-* | controls | | as expected | |

**What could not be reproduced locally**: a real macOS (smbx) or Samba server. Whether such a
server answers the SMB rename of an NFD name to its NFC spelling with
`STATUS_OBJECT_NAME_COLLISION` (the defect's premise) or performs it, is not measured here; the
WebDAV server reproduces the answer, not the product. Admin-only setups (a user share created
with `net share`, a FAT/exFAT VHD) were not needed: `\\localhost\C$` worked without
elevation; a case-sensitive folder can be created without elevation under `%TEMP%` (C:), not
in a folder directly under `D:\` (access denied).

## 5. The rule

`SalDecideExistingTarget(copy, err, source identity, target identity)`
(`src/common/salsamefile.h`, pure, saltests):

| Ids | Metadata | Rename / move | Copy (and move between roots) |
|---|---|---|---|
| not "already exists" | - | old handling | old handling |
| known, different (or two volumes) | - | old handling | old handling |
| known, equal | equal | temporary name | **refuse** "Cannot copy (move) a file to itself." |
| known, equal, link count > 1 | equal | temporary name (self-check -> old handling for another link) | old handling |
| known, equal | different (a volume clone, a constant id) | temporary name (self-check) | old handling |
| unknown (WebDAV) | equal | temporary name | **refuse** |
| unknown | different | old handling | old handling |
| unreadable (one side) | - | temporary name | old handling |

Known limit (accepted): on a file system without ids, a **copy** onto a *different* file of
the same size whose last-write and creation times fall in the same seconds is refused as "to
itself" (probe dav-twcp). Nothing is lost; the user can delete the target first. A rename or
move in that situation is not affected (the self-check tells the files apart, dav-twin).

Existing strings reused: `IDS_CANNOTCOPYFILETOITSELF`, `IDS_CANNOTMOVEFILETOITSELF` (error
text, UTF-8 via `LoadStrU8` - the error dialog shows that field as UTF-8),
`IDS_ERRORCOPY`/`IDS_ERRORMOVE` (caption). No new string, no translation work.
