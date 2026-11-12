---
title: Desktop in the drive menu opens a virtual fld: view, not the Desktop folder
type: bug
status: in-progress
severity: 4
area: other-plugins
source: github#31
who: agent
created: 2026-11-12
updated: 2026-11-12
verified: 2026-11-12 472d20a8
effort: -
feature: 425
related: []
depends-on: []
reason: -
---

# Desktop in the drive menu opens a virtual fld: view, not the Desktop folder

## Problem

The drive menu (Alt+F1 / Alt+F2) and the drive bar have an entry called "Desktop". A user expects
it to open their Desktop folder (`C:\Users\<user>\Desktop`). Instead it opens the Folders
plug-in's virtual file system at its root, `fld:`. That is the shell namespace's Desktop: the
desktop's items mixed with This PC, Libraries, Network, Control Panel and the like. Nothing says
where the panel is: the path line shows only `fld:`. The reporter could not work out what the place
is. The entry is labelled like a folder but leads to a shell view, so users take it for a fault.
There is a worse part. Inside `fld:`, entering a folder that is real on disk (Documents, a drive,
a folder on the desktop) keeps the panel in the virtual view. The path line still says only `fld:`,
and the usual file operations of a disk panel are not there. The user has to type the disk path to
get out.

## Evidence

- GitHub issue #31: https://github.com/tandemcommander/tandemcommander/issues/31 (2026-11-12, in
  Czech); the version is not stated. Original text in `issue.md`.
- Screenshot: the drive menu in Czech with the entry `' Desktop` (hot key `'`). Above it are
  "C Místní jednotka", Dokumenty, Dropbox, OneDrive, Windows registr, FTP klient, Obnovení souborů
  a adresářů, Přenosná zařízení and SFTP Client, and the path box shows `fld:`.
- By reading at 9921e415: the entry is the Folders plug-in's
  `SetChangeDriveMenuItem(LoadStr(IDS_DRIVEMENUTEXT), 0)` in `CPluginInterface::Connect`
  (`src/plugins/folders/folders.cpp:153`). Its text is `"'\tDesktop"`
  (`src/plugins/folders/lang/lang.rc2:21`). The plug-in's file system `fld` starts at
  `CSIDL_DESKTOP` / `SHGetDesktopFolder` (`src/plugins/folders/fs2.cpp:19-38`). Its description is
  "Browse folders such as Desktop, Control Panel, Recycle Bin, etc.". The plug-in is `folders=on`
  in `plugins.cfg`.
- By reading at 9921e415: `CPluginFSInterface::GetCurrentPath` returns an empty user part
  (`src/plugins/folders/fs2.cpp:83-87`), so the path is `fld:` at every depth.
  `GetFullFSPath` returns `FALSE` (`fs2.cpp:101-104`).
  `CPluginInterfaceForFS::ExecuteOnFS` (`src/plugins/folders/fs1.cpp:116`) enters every
  sub-folder through `AddItemToIL` + `ChangePanelPathToPluginFS(panel, pluginFSName, "?")`, even
  one that is a file-system folder. So the panel never leaves `fld:` for a real disk path.
  `GetSupportedServices` (`fs2.cpp:305-311`) offers only the context menu, Properties, icons and
  Open Active Folder. There is no copy, move, delete or rename from the panel's own commands.
- The core already has the matching entry for Documents: `AddToDrives(drv, IDS_MYDOCUMENTS, ';',
  drvtMyDocuments, …)` under `Configuration.ChangeDriveShowMyDoc` (`src/drivelst.cpp:2926-2931`).
  It is opened by `ChangePathToDisk` after `GetMyDocumentsOrDesktopPath`
  (`src/fileswn3.cpp:2703-2709`).

## Expected

All three parts, as the maintainer decided on 2026-11-12:

1. **A real Desktop entry in the core.** The drive menu and the drive bars get a "Desktop" entry
   right after "Documents". It opens the user's Desktop folder (`FOLDERID_Desktop`, a redirected or
   OneDrive desktop included) as an ordinary disk path, with every operation of a disk panel. It is
   built like the Documents entry (its own drive type, a switch beside `ChangeDriveShowMyDoc` in
   the same configuration page, shown by default), with its own icon from the active icon set. A
   missing or unreadable Desktop folder gives an error message, never an empty or a wrong path.
2. **The Folders plug-in's entry is named for what it opens:** "Shell Folders" (the Czech
   translation, for example, "Složky Windows"), not "Desktop". It no longer shares a name with
   the entry of point 1, and its hot key does not collide with that entry's.
3. **Inside `fld:`, a real folder opens as a disk path.** Entering an item that is a file-system
   folder (`SFGAO_FILESYSTEM`, and `SHGetPathFromIDListW` gives a path) switches the panel to that
   disk path, the same as typing it. Only purely virtual places (This PC, Control Panel, Recycle
   Bin, Network, …) stay in `fld:`. An item whose path cannot be got stays in `fld:`, as today.

Every new or changed string is translated in all enabled languages. A probe on the hidden desktop
checks each of the three points: the Desktop entry's resulting path equals `FOLDERID_Desktop`; the
plug-in's entry text; and Enter on Documents inside `fld:` leaves the panel on the Documents disk
path, while Control Panel stays in `fld:`.

## Approach

- Point 1: a new `CDriveTypeEnum` value next to `drvtMyDocuments`, handled at every
  `drvtMyDocuments` site of `drivelst.cpp` (about lines 3637, 3685, 3836, 4094) and in
  `fileswn3.cpp`. Get the path wide from `SHGetKnownFolderPath(FOLDERID_Desktop)` and convert it
  with `SalWToU8` (never a code-page API; refuse a path that does not fit, 097). It needs a
  configuration value (new, read with a default; backward compatible), a string, a Fluent 2 icon
  plus its dark variant (`tools/brand/fluent-icons/`, `check_iconset.py`, 416), and a free hot key
  (`'` is now the plug-in's: give the core entry `'` and the plug-in another key, or the reverse).
- Point 2: `IDS_DRIVEMENUTEXT` in `src/plugins/folders/lang/lang.rc2`; perhaps also the plug-in's
  name or description where the user sees it.
- Point 3: in `ExecuteOnFS`, before `AddItemToIL`, ask the shell for the item's attributes and
  file-system path; if there is one, call the core's change of the panel path to a disk path
  instead of `ChangePanelPathToPluginFS`. Mind zip folders and other shell items that report
  `SFGAO_FILESYSTEM` for a file (`SFGAO_FOLDER` and the path must be a directory).
- Strings: the two-stage `.slt` refresh in the same run (CLAUDE.md, 084); pin the de/fr/nl/es
  wording if DeepL drifts.
- **Left out on purpose** (maintainer decision 2026-11-12): a readable path inside `fld:` (for
  example `fld:\This PC\…`). It would need `ChangePath` to parse such a path back to a PIDL for
  history and hot paths, and shell display names are not unique. After point 3 a user rarely goes
  deep in `fld:`, so the remaining `fld:` path is acceptable.

## Notes

Severity 4: does a function not work but a workaround exists? Yes - inside `fld:` a real folder
cannot get the usual file operations, and typing the disk path works around it. The misleading
label alone would be 3. One reporter, default plug-in set. GitHub labels: bug, ai backlog.

Related: 248 (Folders column names, GitHub #13). No earlier feature names #31.

## Log

- 2026-11-12 — created (source github#31)
- 2026-11-12 — fields set from the issue text and labels
- 2026-11-12 — maintainer decision 2026-11-12: do all three - a core Desktop entry, the Folders entry renamed, real folders inside fld: open as disk paths; a readable fld: path left out
- 2026-11-12 — Problem, Evidence, Expected, Approach and Notes rewritten for the decision
- 2026-11-12 — moved to Next position 1
- 2026-11-12 — verified at 472d20a8: still present at 472d20a8: probe on the HEAD build - no core Desktop item in Alt+F1 or the drive bar, plug-in item reads Desktop with hot key quote; by reading ExecuteOnFS keeps every folder in fld:
- 2026-11-12 — run started, feature 425
