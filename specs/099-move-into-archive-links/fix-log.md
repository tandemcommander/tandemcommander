# Fix log: feature 099 - moving into an archive and links

Branch `099-move-into-archive-links`, from `098-long-path-overruns`.
Decisions by the author (maintainer away): `spec.md` *Clarifications*.

## T002 - inventory: routes that move from a disk panel into an archive or a plug-in FS

Every core caller of `PackCompress`, `PackToArchive`, `PackUniversalCompress` and
`CopyOrMoveFromDiskToFS` was read. "Walk" = who lists the source folders; "follows
links" = descends into a junction / directory symbolic link; "deletes" = who removes
the sources after a successful pack/upload.

| Route | Code | Walk | Follows links | Deletes | Link check before 099 |
|---|---|---|---|---|---|
| Pack dialog (Alt+F5) with "Delete files from disk after packing" | `fileswn7.cpp` `CFilesWindow::Pack` -> `packers.cpp` `ExecutePacker` | core `PanelEnumDiskSelection` (plug-in packers) / the external archiver's move command | yes (core walk lists `J\*`) | the plug-in (ZIP, 7zip) / the external archiver | **yes** - silent scan since Open Salamander, fail-closed since 098 |
| F5/F6 dialog with a target inside an archive: the archive open in the other panel, or a typed `<archive>\path` | `fileswn8.cpp` `FilesAction`, branch `PATH_TYPE_ARCHIVE` -> `PackCompress(..., type == atMove, ...)` | core `PanelEnumDiskSelection` | yes | the ZIP / 7zip plug-in (`PackToArchive(move)`), or the external archiver's move command | **none** |
| Drag & drop with Move onto an archive panel, or onto an archive FILE in a disk panel (`idtttArchiveOnWinPath`); Ctrl+X + Ctrl+V into an archive panel (`ClipboardPasteToArcOrFS`, Move = the cut effect) | `shellib.cpp` / `fileswn9.cpp` -> `DoDragDropOper` -> `fileswna.cpp` `DragDropToArcOrFS` -> `PackCompress(..., !data->Copy, ...)` | core `PanelEnumDiskSelection` | yes | as above | **none** |
| F6 into a plug-in file system: the FS in the other panel (mode 1), a typed `fs:path`, a detached FS (mode 2) | `fileswn8.cpp` -> `CopyOrMoveFromDiskToFS(copy = FALSE, ...)` | the plug-in (enumerator with `enumFiles` 0: the selected items only, then its own walk) | per plug-in, below | the plug-in; the core deletes nothing afterwards (it only unselects) | n/a (core) |
| Drag & drop / cut + paste with Move into a plug-in FS | `fileswna.cpp` `DragDropToArcOrFS`, FS branch (mode 3) | as above | per plug-in | the plug-in | n/a |
| `CallPluginOperationFromDisk` (a plug-in's own operation on the panel selection) | `zip.cpp` | core | yes | the plug-in | n/a - used only by `demoplug` and `mmviewer`, both **off** in `plugins.cfg` |

Not routes into an archive: Shift+F6 (`CM_RENAMEFILE`, in-place rename), Unpack and
delete (the opposite direction), packing back an edited file (`salamdr3.cpp`, move FALSE).

Shipped FS plug-ins (`plugins.cfg`: ftp, sftp on), upload-Move:
- **SFTP** (`sftp/operats.cpp` `SFTPUploadToFS`): walks itself
  (`UploadDirRecursive`) and never descends into a reparse point; `DeleteLocalTree`
  removes a reparse point with `RemoveDirectoryW` (the link only) - its "CF-6" guard.
  Safe. A moved link is removed and nothing is uploaded for it.
- **FTP** (`ftp/operats5.cpp` `DoListDirectory`, the disk thread's `fdwtListDir`): lists a
  local folder with `FindFirstFile`, treats a junction / directory symlink as an ordinary
  folder (only *file* links are special-cased, for the size), queues an
  `fqitUploadMoveExploreDir` for it, uploads every file found behind it and deletes each
  one on disk (`fdwtDeleteFile`) through the link path - **the files behind the link are
  deleted**, then `fqitUploadMoveDeleteDir` removes the link. A serious defect in a
  shipped plug-in, local to the plug-in: fixed (T003). Read only - no FTP server here
  (`pyftpdlib` is not installed), not driven.

## T003 - the change

**Warning text** (`IDS_DELFILESAFTERPACKINGNOLINKS`, `src/lang/texts.rc2`): "You are trying
to move selected files and directories to archive. This is not possible because selection
contains link to directory (junction point, volume mount point, or symbolic link). Please
continue without deleting files from disk after packing to archive. Link: %s". It says the
move *is not possible* and asks the user to continue *without deleting* - it does not
promise a copy. So the F6 and drag & drop routes **cancel before anything is packed**
(nothing packed, nothing deleted, the selection stays); the user can copy with F5. The
Pack dialog keeps its behaviour (the dialog opens again with "delete" off) - there the
user can "continue without deleting" in the same dialog.

- `src/fileswn7.cpp`, `src/fileswnd.h`: new `ScanMoveSelectionForDirLinks(parent, data,
  sourcePath, title)` - the silent, fail-closed scan of `CFilesWindow::Pack` (098) moved
  into one helper: 0 = no link and everything checked; 1 = a link, or not everything
  checked (098 rule: an unreadable or too deep folder, low memory) - the warning was shown
  with `title`; 2 = the user stopped the scan (ESC). `data` is not changed (the scan
  builds no tree). `Pack` calls it (title "Pack", behaviour unchanged; its now unused
  `text[1000]` was removed).
- `src/fileswn8.cpp` `FilesAction`, branch into an archive: for a move, the helper runs
  after the target checks and before the zero-size-archive handling and `PackCompress`;
  1 or 2 -> cleanup and return (title "Move Error").
- `src/fileswna.cpp` `DragDropToArcOrFS`: for a move into an archive (drag & drop with
  Move, cut + paste, an archive panel or an archive file), the helper runs before
  anything; 1 or 2 -> nothing is done.
- FTP plug-in (no interface change; plug-in-internal struct): `CFTPDiskWork::ListLinkAsEmpty`
  (`operats.h`), reset in `InitDiskWork` (`operats3.cpp`), copied in `CopyFrom`
  (`operats5.cpp`), set for `fqitUploadMoveExploreDir` in `operatsa.cpp`; `DoListDirectory`
  returns an empty listing for a folder that is a reparse point when it is set. So an
  upload-Move never descends into a link: the files behind it are neither uploaded nor
  deleted; the link itself is then removed like an emptied folder (`RemoveDirectory`
  removes only the link) and an empty folder is created on the server (SFTP creates
  nothing for a link - both are safe). A folder whose attributes cannot be read is listed
  empty too (review NIT 1: fail closed).
  Upload-Copy is unchanged (still follows links; it deletes nothing).
- No new strings; no plug-in interface change.

Not changed, recorded: a file symbolic link in a moved selection is packed as its target's
content and the link file is deleted (`DeleteFile` removes the link, not the target) - no
loss. The scan does not judge where a link points (spec).

## T004 - probe

`probe/linkmove_probe.ps1` (dot-sources `098-long-path-overruns/probe/fix_probe_lib.ps1`).
Hidden desktop; right panel opened on the existing archive (`-r <archive>`, holding
`seed.txt`), F6 (728) of the item with the default target (the archive panel), windows
answered OK / Yes; then `X\x.txt`, the source left on disk and the archive's names are read.
Junctions with `mklink /J`, the directory symlink with `mklink /D` (allowed on this machine),
the unreadable folder by `icacls /deny <user>:(RD)`; links and the deny removed first at
the end. Registry SHA-256 identical after each run; fixtures removed; nothing left running.
Results: `probe/linkmove_result_099.txt`, `probe/linkmove_result_pre099.txt`.

| Case (ZIP and 7z each) | This build | Before 099 (`Debug_x64_pre099`) |
|---|---|---|
| jdir: S\B holds J -> X | warning ("Move Error"), cancelled: archive = `seed.txt`, B kept, **X\x.txt kept** | no warning; `B\J\x.txt` packed, B moved, **X\x.txt deleted** |
| jnest: S\B\sub\J -> X | the same | the same loss (`B\sub\J\x.txt`) |
| jself: the junction S\J itself | the same (J kept) | `J\x.txt` packed, **X\x.txt deleted** |
| symd: S\B\L directory symlink -> X | the same | `B\L\x.txt` packed, **X\x.txt deleted** |
| unread: S\B\U unlistable | warning, cancelled, nothing packed | partial move: `B\b.txt` packed and deleted, U left (no loss behind a link) |
| plain: S\B, sub\c.txt | packed and deleted, no warning | identical |

Rows: this build 24 PASS / 0 FAIL; before 099 14 PASS / 10 FAIL (the 8 link cases lose
`X\x.txt`, the 2 unread cases move partly).

Not driven:
- Drag & drop and cut + paste: no drag on the hidden desktop, and `OpenClipboard` is
  denied to this session (098); `DragDropToArcOrFS` is reached only with an in-process
  pointer - verified by reading (it is the same `PackCompress` call, now behind the helper).
- FTP: no FTP server (read only). SFTP: read only (its guard is unchanged).
- External packer (RAR move command): WinRAR is not installed; the F6 / drag & drop scan
  runs before `PackCompress`, whichever packer it chooses.

## Gates (T002-T004, Debug)

- Debug x64 build exit 0, no warnings from the changed files (the FTP plug-in's
  `fs2.cpp` / `parser2.cpp` C4267 and `zip.cpp(5913)` C4244 are older lines that
  recompiled); `saltests` 13,119 / 0; `tools/check_encoding.py --strict` TOTAL 0; the
  touched files keep BOM + CRLF.
- Regression on this build (results in `probe/regress_*_099*.txt`; registry identical,
  fixtures removed, nothing left running after each):

  | Probe | Result |
  |---|---|
  | 095 `longarc_probe.ps1` | 60 PASS / 0 FAIL (Debug handle notes 4, as its baseline) |
  | 096 `archedit_probe.ps1` | first run: 16 of 17 UPDATED - `cyr` showed no edit at all ("temporary copy: none": the posted F4 was ignored, the flake 097 records); re-run: 17 of 17 UPDATED |
  | 097 `arcpath_probe.ps1 -Stage S2` | 55 PASS / 0 FAIL |
  | 097 `arcwork_probe.ps1` | 390 PASS / 0 FAIL / 21 n/a |
  | 098 `fix_probe.ps1` | 107 PASS / 0 FAIL / 3 not driven / 1 INFO - the INFO row `d5f6zip` (F6 of a folder with a junction into a ZIP) now shows the warning and keeps `X\x.txt` (it was deleted on 098) |

## Independent review - ACCEPT (2026-10-03)

No blocker, no should-fix. The reviewer redid the inventory (no route
missed: Pack dialog, F6 to an archive panel or a typed `archive\path`, drag
and drop onto an archive panel or file, Ctrl+X / Ctrl+V, drags from the Find
window or another instance, FTP; SFTP already safe; the other enabled
file-system plug-ins have no upload from disk) and **drove the FTP part**
against a local pyftpdlib server on both builds: before 099 the file behind
the junction / directory symlink was deleted in all three link cases; now it
is kept, the server gets the folder with an empty link folder, a plain move
and an upload-copy are unchanged. File symbolic links and hard links: the
packers delete the link / the one name, never the target. `linkmove_probe`
24 / 0 and 098's `fix_probe` 107 / 0 / 3 / 1 reproduced.

Done after it: NIT 1 - an FTP folder whose attributes cannot be read is
listed empty (fail closed); NIT 2 - the fix-log sentence about SFTP
corrected. Recorded: the FTP check reacts to any reparse-point folder (a
cloud placeholder would be listed empty; removing it then fails, nothing
lost; OneDrive folders are seen as plain folders by this process); the
warning text says "continue without deleting" while F6 cancels (no new
strings).

Gates after the nits: Debug and full Release builds, saltests 13,119 / 0,
strict guard 0, `linkmove_probe` re-run on the final build.

