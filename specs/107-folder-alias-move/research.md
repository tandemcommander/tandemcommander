# Research for feature 107: a folder copied or moved onto another path of itself

Branch `107-folder-alias-move` (from `106-zip-overwrite-source`, HEAD 30513653), 2026-10-04.
Machine: Windows 11 10.0.26200, ACP 1250, user not elevated; `%TEMP%` on C: (8.3 names on). Pre-change
build preserved as `build\tandemcommander\Debug_x64_pre107` (copied from the 106 build before the first
build of this feature, without `Intermediate`). Scratch probe (not in the repository): `fsprobe107.ps1`
in the session scratchpad (P/Invoke `MoveFileW`, `CreateFileW`, `GetFileInformationByHandle`). The
committed probe `probe/folderalias_probe.ps1` drives the program on the hidden desktop; the WebDAV
server is 103's `probe/davnorm.py`.

The defects (feature 103's second review, `specs/103-same-file-delete-guard/fix-log.md` NIT 4 and NIT 5;
`specs/NEXT-WORK.md` item 5): (1) a FOLDER moved onto an alias of itself between two roots deletes its
empty subfolders; (2) a hard link reached through an alias gets "overwrite x with x?" and then error 32.

## 0. Headline

1. **Defect 1 is real and wider than recorded.** On `Debug_x64_pre107` every move of a folder "into
   the same place" (shape b: `C:\...\parentlong\F` -> `<alias of parentlong>\`) **deleted the folder's
   empty subfolders** (`F\empty`, `F\sub\deep`) through **eight** aliases: `\\localhost\C$`,
   `\\127.0.0.1\C$`, a mapped drive (`net use` to `\\localhost\C$`), a SUBST letter, the second WebDAV
   server name - and, on the SAME drive, a junction to the parent, the parent's 8.3 spelling, and the
   NFC spelling of an NFD-stored WebDAV folder. The user saw only "Cannot move a file to itself." (103)
   for each file and then "Error Deleting Directory (145) The directory is not empty".
2. **A move INTO ITSELF through an alias restructured the source** (shapes a and c, not recorded
   before): `F` -> `<alias>\F\` moved the whole content one level down (`F\a.txt` -> `F\F\a.txt`, every
   subfolder recreated below and the originals deleted; 7 entries gone, 8 added), `F` -> `<alias>\F\sub\`
   the same into `F\sub\F` (6 gone, 8 added) - through every other-root alias (UNC, IP, mapped drive,
   SUBST, second WebDAV name). No file content was lost in any measured case, but the tree the user
   had was gone, after "(145) The directory is not empty". On the same drive (junction, 8.3, case, NFD)
   and by name, Windows refuses the rename (error 5, 87, or 58 on WebDAV) and nothing changes.
3. **Copies lose nothing.** A copy into itself (a, c) makes a snapshot copy (`F\F\...`, `F\sub\F\...`)
   by name and through every alias alike (the script is built before anything is written, so it never
   recurses); a copy onto itself (b) is refused file by file by 103 ("Cannot copy a file to itself."
   once per file through an alias, once in total by name).
4. **Defect 2 confirmed on six aliases**: a hard-linked file copied - or moved between two roots - onto
   the very same directory entry through `\\localhost\C$`, `\\127.0.0.1\C$`, SUBST, a junction, the 8.3
   folder spelling or a mapped drive: "Confirm File Overwrite" with two identical lines, then "Error
   Deleting File (32)". Nothing lost (NTFS: the open source blocks it). A move on one drive (junction,
   8.3) is a no-op rename, no question. Onto ANOTHER link (`b.txt`) the old handling asks and leaves
   `b.txt` an independent copy.
5. **Two more structure losses** found by the added rows: a junction BELOW the target pointing back
   into the source (`dst\F\sub` -> `src\F\sub`) made a merge-move delete `src\F\sub\deep`; a junction
   moved "into the same place" through `\\localhost\C$` was **deleted** (its content "copied onto
   itself" first).
6. **The identity is the same for every alias of a folder** (section 2), so the fix is the 103 rule at
   folder level, at script-build time, plus a worker check for merges (section 4).

## 1. The core's existing checks (by name) and every route

| Where | What | By name |
|---|---|---|
| `fileswn6.cpp BuildScriptDir`, `atMove` | `strcmp(sourcePath, targetPath) == 0` -> "Cannot move a directory to itself." (`IDS_CANNOTMOVEDIRTOITSELF`), build aborted | exact string only (shape b by name) |
| `BuildScriptDir`, `atMove`, same root | `SalNameEqualOrdinalCI` (092) -> one `ocMoveDir` (a case-only rename); target missing -> `ocMoveDir`; target existing -> **merge**: `ocCreateDir` + per-item `ocMoveFile` + `ocDeleteDir` per folder | - |
| `BuildScriptDir`, `atCopy` | **none** for a folder - a copy into itself is a snapshot | - |
| `BuildScriptFile` | copy: `SalNameEqualOrdinalCI(source, target)` -> "Cannot copy a file to itself."; move: `strcmp` -> "Cannot move a file to itself." - build aborted | exact / case-insensitive string |
| `worker.cpp DoCreateDir` | target folder exists -> "Confirm Directory Overwrite" (if on) -> merge | - |
| `worker.cpp DoDeleteDir` | `RemoveDirectory`: the empty ones go, the others report 145 | - |
| `worker.cpp DoCopyFile` / `DoMoveFile` | 103: a file onto itself refused (copy, and a move between roots), except a source with more than one hard link | identity |

There is **no** "copy/move a folder into its own subfolder" check and no string for it
(`IDS_CANNOTCOPYFILETOITSELF`, `IDS_CANNOTMOVEFILETOITSELF`, `IDS_CANNOTMOVEDIRTOITSELF` are the only
"to itself" texts; no "copy a directory" variant).

Routes that build a folder copy/move script - all through `BuildScriptDir`:
- F5 / F6 (`CFilesWindow::FilesAction` -> `BuildScriptMain`);
- paste (Ctrl+V after Ctrl+C / Ctrl+X: `fileswn9.cpp` simulates a drop) and drag & drop
  (`CImpDropTarget` -> `DoCopyMove` -> `WM_USER_DROPCOPYMOVE` -> `DropCopyMove` -> `BuildScriptMain2`);
- the plug-in service "move files from a temporary folder" (`CFilesWindow::MoveFiles`: unpack + move).
- Quick Rename (F2) cannot name another folder: `RenameFileInternal` refuses `\`, `/`, `:` in the new
  name - its only alias rows are the folder's own 8.3 name and another case (no-op / case rename);
- the command line has no copy/move of its own (`copy`/`move` typed there run in `cmd.exe`).

## 2. Measurements: what Windows answers (scratch probe, NTFS C:)

Identity of one folder `...\x\FolderLong` (`CreateFileW(FILE_READ_ATTRIBUTES, share all,
FILE_FLAG_BACKUP_SEMANTICS)` + `GetFileInformationByHandle`) through `\\localhost\C$\...`,
`\\127.0.0.1\C$\...`, a junction to `x`, the 8.3 name `FOLDER~1`, another case: **one volume serial and
one file index** in every case; the junction opened with `FILE_FLAG_OPEN_REPARSE_POINT` has its own
index (the link), without it the target's. WebDAV (103): serial 0, index 0 - no ids.

`MoveFileW` of a folder:

| Situation | Answer |
|---|---|
| `F` -> `F\sub\F` (by name, through a junction, through UNC) | error 5 (access denied), nothing changes |
| `F` -> `F\F` (GUI: F6 to `F\`) | error 87 (by name, junction, 8.3, case) |
| `F` -> its own 8.3 name, -> through a junction to its parent | success, a no-op |
| `F` -> through `\\localhost\C$` (another root) | error 5 - so the program copies + deletes |
| WebDAV, NFD folder -> its NFC spelling's subfolder | error 58 |
| `CreateDirectoryW` of an existing folder through UNC | 183 - the merge path |

## 3. Measurement on `Debug_x64_pre107` (`probe/folderalias_result_pre107.txt`)

Every row answered as a hurried user would: Yes / OK, else Skip. "missing" = entries of the source
tree gone afterwards, "added" = new entries; contents are unique per file, "lost" = a content no file
holds any more. Final run (89 cases, RUN + END rows): **PASS 157, FAIL 21, NOT DRIVEN 32** - every
FAIL a change of the source tree (lost 0 everywhere), every END row clean (exit 0, no stray window, no
report); NOT DRIVEN = the paste rows (the clipboard cannot be opened on the hidden desktop). Shapes: a = into itself (`<alias>\F\`),
b = the same place (`<alias>\`), c = into its subfolder (`<alias>\F\sub\`).

| Alias | F6 a | F6 b | F6 c | F5 a / c | F5 b |
|---|---|---|---|---|---|
| plain (by name) | error 87, unchanged | "Cannot move a directory to itself." | error 5, unchanged | snapshot copy | "Cannot copy a file to itself." |
| `\\localhost\C$` | **content moved into `F\F`** (7 gone / 8 new), "(145)" | **`F\empty`, `F\sub\deep` deleted**; 2x "Cannot move a file to itself." + "(145)" | **moved into `F\sub\F`** (6 gone / 8 new) | snapshot | refused per file |
| `\\127.0.0.1\C$` | **the same** | **the same** | **the same** | snapshot | refused per file |
| SUBST letter | **the same** | **the same** | **the same** | snapshot | refused per file |
| mapped drive (`net use`) | **the same** | **the same** | **the same** | snapshot | refused per file |
| junction to the parent | error 87 | **empty folders deleted** ("(145)" only) | error 5 | snapshot | refused per file |
| 8.3 of the parent | error 87 | **empty folders deleted** | error 5 | snapshot | refused per file |
| another case | error 87 | no-op rename (092) | error 5 | snapshot | "Cannot copy a file to itself." |
| WebDAV, second server name | **moved into `F\F`** (server: `DELETE` of every original) | **empty folders deleted** | **moved into `F\sub\F`** | snapshot | refused per file |
| WebDAV, NFD stored / NFC typed | error 58 | **empty folders deleted** | error 58 | snapshot | refused per file |

Why the same drive loses too (b): `HasTheSameRootPath` says "one disk", the target `T\F` exists, the
names differ -> the merge path: every `ocMoveFile` is answered "success" by NTFS (a rename onto itself
through a junction or an 8.3 spelling is a no-op - 103 section 2), and then `ocDeleteDir` removes every
folder that is empty. On WebDAV (NFD) the server answers the per-file MOVE onto the same entry with 204.

Hard links (`a.txt` + `b.txt`, link count 2):

| Case | Pre-107 |
|---|---|
| F5 of `a.txt` to the same entry through UNC, IP, SUBST, junction, 8.3 folder, mapped drive | "Confirm File Overwrite" (two identical lines), then "Error Deleting File (32)"; kept |
| F6 the same through UNC, IP, SUBST, mapped drive (two roots) | the same; the source kept (the failed copy is skipped) |
| F6 through a junction / the 8.3 folder (one drive) | nothing asked, a no-op rename |
| F5 of `a.txt` onto `b.txt` (another link; by name and through UNC) | "Confirm File Overwrite" -> `b.txt` an independent copy, `a.txt` intact |

Two more measured on the build before (rows added after the first round, `folderalias_result_pre107.txt`):

| Case | Pre-107 |
|---|---|
| `deep-junc-mov` / `deep-junc-unc-mov`: F6 of `src\F` into `dst\` where `dst\F` is ANOTHER folder but `dst\F\sub` is a junction back to `src\F\sub` (same drive / through `\\localhost\C$`) | the merge reached `sub` through the junction: **`src\F\sub\deep` (empty) deleted**, "(145)" twice |
| `jlink-unc-mov`: F6 of a junction `parentlong\J` (-> `G`) to `\\localhost\C$\...\parentlong\` (the same place) | "Confirm Link Target Copy" -> Yes: `G`'s content "copied onto itself" (refused per file), then **the junction `J` deleted** |
| `dav-merge-mov` / `dav-twin-merge`: F6 of `src\F` into `dst\` on WebDAV (two server names) where `dst\F` is another folder (times different / forced equal) | merged and moved, both |

Controls (ordinary copies and moves of a folder between two different folders, ASCII and Cyrillic, also
to `\\localhost\C$` of another folder and into an existing folder of the same name): copied / moved
on both builds (the first round's control rows failed only because the probe's own count was wrong -
8 instead of 7 entries below `F`; corrected, then both builds were run again in full).

## 4. The rule (decided in spec.md)

At script build (`BuildScriptDir`, the top-level folder of a copy or move, only when the target path
differs by name from the source - the same path by name keeps every old branch):

1. `T\name` exists (`targetPathState`) and `SalDirIsSame(source, T\name)` -> refuse. A link as the
   source is compared as the link itself (`FILE_FLAG_OPEN_REPARSE_POINT`); a move fails closed when
   one side cannot be read at all.
2. A move (of a real folder, not a link): `T` or a folder above it is the source
   (`SalDirChainHolds`) -> refuse. The chain is read once per operation (`CDirTargetChain107`, reset
   when `BuildScriptMain` / `BuildScriptMain2` / `MoveFiles` start) along the path as written AND along
   `GetFinalPathNameByHandleW`'s path (a junction in the middle of the target path, whose by-path
   parents are not the physical ones).

`SalDirIsSame` (after the independent review): one side in a snapshot and the other not, or two
snapshots -> no; equal ids -> yes (on FAT/FAT32/exFAT only with equal times as well); different ids
-> no; one side with a usable id and the other without (local/SMB against WebDAV) -> no, two file
systems; no ids on both (WebDAV) -> equal kind and times (whole seconds) **and the same path below
the server name up to case and NFC**, both sides resolved first (`SalPathsBelowServerLooselyEqualU8`:
`GetFinalPathNameByHandleW` - measured: a mapped letter `Y:\x\F` -> `\\?\UNC\localhost@p\dav\x\F`; then
`SalCanonicalBelowServerU8Alloc` drops the server and a `DavWWWRoot` component: `\\localhost@p\dav\a\F`
= `\\127.0.0.1@p\dav\a\F` = `Y:\a\F` = `\\localhost@p\DavWWWRoot\dav\a\F`, NFD = NFC;
`dav\a\F` != `dav\b\F`; unresolvable -> the folder names). The targeted re-check REJECTED a version
that compared the typed text: a mapped drive and the `DavWWWRoot` form then counted as other folders
and the move failed open. The first version compared only the
folder's own name - which every merge shares - so on WebDAV a backup update `dav\a\F` -> `dav\b\`
whose `b\F` had the same folder times was refused (review SF2; folder times are equal far too often:
kept times, one archive unpacked twice, and they do not change when a file inside changes). The
snapshot tag (`SalSnapshotTagFromPath`: a `HarddiskVolumeShadowCopyN` component of the handle's final
NT path, or an `@GMT-YYYY.MM.DD-HH.MM.SS` component of the path) and the weak-id flag
(`GetVolumeInformationByHandleW`'s file system name) are read only by the folder checks
(`volumeTraits`); 103's and 106's file rules are unchanged - restoring an UNCHANGED file from a
snapshot is refused there as "Cannot copy a file to itself." (equal id and metadata: nothing to
restore, harmless); a changed file has other metadata and is overwritten as before.

At run time, where the worker meets an existing folder (`DoCreateDir`), before "Confirm Directory
Overwrite": the same comparison (source folder vs. the existing one) - a second line for links below
the top level (a junction inside the target pointing back into the source); Skip leaves the subtree
and its deletions out. Cost: two attribute opens per merged folder.

Hard links: 103's copy rule kept `ids equal && links > 1 -> old handling`. Now that case asks
`SalSameDirEntryU8`: the identities of the two holding folders (through links) and the two names as
the folders store them (`FindFirstFileW`'s `cFileName`, whatever spelling the path used) - one folder
and one stored name = the same entry -> refuse; another folder or another stored name = another link
-> the old handling; unreadable -> refuse (fail-closed). Only this rare case pays for the two extra
opens and two look-ups.

**Considered, not used**: comparing final paths only (`\\localhost\C$` resolves to `\\?\UNC\...`, not to
`C:\` - two paths for one folder); refusing a copy into itself (a by-name behaviour nobody reported,
nothing is lost); a new "Cannot copy a directory to itself." / "...into one of its subfolders" string
(needs the translation pipeline for 8 languages; the existing texts are what the by-name route shows -
recorded); checking every level at build time (one more open per folder of the tree; the worker's check
covers the merges where it matters).

Existing strings reused: `IDS_CANNOTMOVEDIRTOITSELF`, `IDS_CANNOTCOPYFILETOITSELF`,
`IDS_CANNOTMOVEFILETOITSELF`, `IDS_ERRORTITLE`, `IDS_ERRORCOPY` / `IDS_ERRORMOVE` (UTF-8 through
`LoadStrU8` where the dialog shows UTF-8). No new string, no translation work.
