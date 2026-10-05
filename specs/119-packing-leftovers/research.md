# Research for feature 119: the leftovers of the packing fixes (found by 106)

Branch `119-packing-leftovers` (from `118-plugin-update-close`, HEAD ea528c45), 2026-10-06.
Pre-change build preserved as `build\tandemcommander\Debug_x64_pre119` (= the 118 build, binaries
byte-identical to `Debug_x64_118`). **No GUI run was possible**: other agents ran GUI probes on the
hidden desktop and the maintainer used the installed program, so starting `tandemcommander.exe`
was not allowed. Everything below is code reading of HEAD plus the 106 measurements
(`specs/106-zip-overwrite-source/research.md`, `probe/packself_result*.txt`); the GUI evidence is
the pending probe `probe/packleft_probe.ps1` (`quickstart.md`), which measures every item on the
build before as well.

The items as recorded by 106 (`fix-log.md` "Recorded, not changed", NEXT-WORK):

1. a failed multi-volume pack leaves the volumes it already wrote;
2. multi-volume into `name.zip` that exists (Add) leaves the last volume as `name.z0N`, silently;
3. the 7-Zip plug-in packs a selected archive into itself, and Move then shows "Delete Error (32)";
4. the ZIP plug-in's *Add* of a selected archive reports a sharing violation instead of a clear text;
5. the core's refusal "Cannot copy a file to itself." names no file and does not say that
   deselecting helps (106 review N1).

## R1. Item 1 - what a failed multi-volume pack deletes (`zip/add.cpp`)

`PackMultiVol` -> `CreateNextFile` (volume 1) -> `PackFiles`; every next volume comes from
`NextDisk` (`Flush` + `CloseCFile` of the current one, `DiskNum++`, on removable media the
"insert disk" dialog, `CreateNextFile`). `CreateNextFile` sets `TempName` to the volume's name
(`MakeFileName(DiskNum + 1, ...)`) and, since 106, `TempNameOurs = true` only when its own
`CreateFileU8` succeeded (`CREATE_NEW`, or `CREATE_ALWAYS` after the user's *Yes* / *All*).
The only clean-up is at the end of `PackMultiVol`:

```
if ((ErrorID || UserBreak || NothingToDo) && TempNameOurs)
    DeleteFileU8(TempName);
```

`TempName` is the CURRENT volume only. Every failure after volume 1 therefore leaves volumes
1..n-1 (complete, closed files) in the target folder - a set without its last volume and without
`name.zip`, which no tool opens:

| Failure at volume n | Reached through | Left before 119 |
|---|---|---|
| a source cannot be opened / read, *Cancel* | `PackFiles` -> `ProcessError` | volumes 1..n-1 |
| *Cancel* in the progress window | `UserBreak` | volumes 1..n-1 |
| "Overwrite file a.z0n?" *Cancel* (an unrelated file of that name) | `CreateNextFile` -> `IDS_NODISPLAY` | volumes 1..n-1 (106 E-decline-vol2: `a.z01` stays) |
| 106's refusal at volume n (the name is a source) | `RefusePackedSource` | volumes 1..n-1 (106 D-later rows: "volumes 1-3 of the refused archive stay") |
| the disk is full / free-space dialog *Cancel* | `CreateNextFile` | volumes 1..n-1 |
| the last volume's rename fails (R2) | not detected | the whole set, the last one as `.z0N` |

106 recorded why it did not delete them: "deleting them by name is unsafe on removable media (one
name on every disk)". That is right for removable media - with *sequential names* off every disk
holds `name.zip`, and with them on `a.z01` on the disk now in the drive is not necessarily the
`a.z01` this operation wrote. On a fixed (or network) disk the names are distinct (`.z01`,
`.z02`, ...) and all in one folder, and the operation knows which of them it created. The safe
form: record every volume when it is created, with the file system's identity read from the
creating handle (`SalFileIdentityFromHandle`, salsamefile.h - volume serial + file id), and at a
failure delete a recorded name only while it still holds that file (another id = another file
took the name: never). Ids not usable (a server without file ids): the first version deleted by
name; the code review (SF1) showed another process may replace a volume during a long pack, so
now such a volume is deleted only while it is a file with the recorded creation time and the size
this operation wrote (recorded at close), else kept.

A pre-existing file overwritten after the user's *Yes* is "this operation's" since 106
(`TempNameOurs`): `CREATE_ALWAYS` truncated it at that moment, it holds only this operation's
volume data. Deleting it with the rest of the abandoned set is what 106 already did for the
current volume; keeping it would leave exactly the stray volume this item removes (decision in
`spec.md`).

**A Move must never lose the archive.** `CleanUpSource` runs after the archive is complete
(`FinishPack`, the rename, the self-extractor's central directory) and deletes the sources; its
only failure (`InsertDir` low memory) comes after files were already deleted. The 106 clean-up
condition `ErrorID` included that failure and would then delete the current volume - the one
that holds the data of the deleted sources when the last volume was not renamed (WinZip names
off). The new clean-up stops at "the archive is complete" (`outputComplete`): from there on
nothing is deleted.

Removable media: only the volume still being written, under the same identity rule - not
reachable here (no removable drive; 106 X-removable). Code review SF2 (found by the reviewer):
`NextDisk` closes volume n, then shows "insert the next disk" while `TempNameOurs` is still true -
*Cancel* deleted `TempName` on the new disk (with sequential names off, the user's `name.zip`). Now
`NextDisk` clears `TempNameOurs` when it closes the volume. `DetectRemovable` (review NIT): the root
was the text before the first backslash, so `\\?\X:\` paths were taken for fixed disks
(`GetDriveType("")` answers `DRIVE_NO_ROOT_DIR` - measured, not "the current directory's drive";
`GetDriveType("C:")` without a backslash answers like `"C:\"` - measured); now `X:\` is asked,
also behind `\\?\`, and UNC is never removable. The self-extractor's exe (`PackMultiVol` + SFX) is created outside
`CreateNextFile` and is not recorded - unreachable (no SFX package is shipped, 104/106).
`WriteSFXCentralDir` reopens volume `StartDisk` with `SeccondPass` (`OPEN_EXISTING`) - never
recorded, never `TempNameOurs` (106 review N3); on a fixed disk that volume is already in the list
from the first pass. Found while reading: `WriteSFXCentralDir` ignores `CreateNextFile`'s result
(`if (ret) ret;`) and then writes through `TempFile` - a NULL dereference if the reopen fails;
SFX-only, unreachable, recorded.

## R2. Item 2 - multi-volume into a name that exists

`MakeFileName(n, seqNames, archive, name, winZipNames)` (`zip/common.cpp`): with *sequential
names* (forced on a fixed disk by the options dialog: `PackOptions->SeqNames || !(Flags &
PD_REMOVALBE)`) and *WinZip names* (configuration, default on) the volumes are `name.z01`,
`name.z02`, ...; without WinZip names `name01.zip`, `name02.zip`, ... (no rename); without
sequential names (removable only) `name.zip` on every disk. At the end:

```
if (!ErrorID && Options.SeqNames && Config.WinZipNames) { ... MoveFileU8(name, ZipName); ... }
```

`MoveFileU8` -> `MoveFileW` (no `MOVEFILE_REPLACE_EXISTING`): when `ZipName` exists the rename
fails, the result is not checked, `ErrorID` stays 0 - the set ends with `name.z0N`, the old
`name.zip` keeps its name, and a **Move then deletes the sources** (the operation "succeeded").
No byte is lost (the data is in the volumes), but nothing opens the set until the user finds the
problem and renames by hand.

How `ZipName` can exist: the core's Pack dialog asks "Add into existing archive or overwrite?"
(`IDS_CONFIRM_ADDTOARCHIVE`, `fileswn7.cpp`) before any packer runs; *Overwrite* deletes it first
(106 checked that it is not a source), *Add* (or the question switched off - Configuration >
Confirmations "Add to archive") calls the plug-in with the existing name. The ZIP options dialog
then offers multi-volume and titles itself "Create New Archive" (`IDS_CREAETARCH`) - a
multi-volume archive is always new. `PackToArchive` (`zip/add_del.cpp`) still holds the original
authors' refusal, commented out:

```
case PA_MULTIVOL:
    //if (noexist)
    ErrorID = PackMultiVol(next, param);
    //else
    // ErrorID = IDS_CANTMULTIVOL;
```

`IDS_CANTMULTIVOL` (1060): "Archive of the same file name already exists.\nThe multi-volume
archives can be created only like a new archive." - present and translated in all 11 language
sources (`translations/*/zip.slt` row 1060; Romanian starts with a lower-case letter, recorded).
It was probably disabled because it refused more than needed: without WinZip names nothing is
renamed and an existing `name.zip` does not matter, and with sequential names off (removable)
`CreateNextFile` already asks "Overwrite?" for `name.zip` itself.

Options considered: (a) ask "Overwrite?" again (`OverwriteDialog`) and rename with replace at the
end - contradicts the *Add* the user just chose, and an overwrite decided before a long pack would
have to delete the old archive only after the set is complete (new replace logic, new failure
mode); (b) **refuse before anything is created with the existing text, exactly where the rename
will happen** (fixed disk, sequential + WinZip names, no SFX): the user chooses *Overwrite* or
another name; (c) number the last volume differently - an invalid split set. Chosen (b), plus:
the rename's result is checked - a failure (the name appeared during the pack, removable media
where the last disk holds a `name.zip`, access denied) is reported with the archive's name
(`IDS_CANTMULTIVOL` for "exists", else `IDS_ERRCREATE` + the system text), the pack counts as
failed (no Move deletion) and R1's clean-up deletes the set.

## R3. Items 3 and 4 - a pack into an archive that is one of its own sources

Routes from the core into a packer (`PackToArchive` of a plug-in or an external packer):

| Route | Code | Existing archive among the sources before 119 |
|---|---|---|
| Pack dialog (Alt+F5), name exists, *Add* / no question | `CFilesWindow::Pack` -> `CPackerConfig::ExecutePacker` (`fileswn7.cpp`, `packers.cpp`) | ZIP: the plug-in holds the archive open for writing (`PackNormal`, `OPEN_ALWAYS`, share read) - reading it as a source fails, "sharing violation" Retry/Skip/Cancel (106 B-zip rows); 7-Zip: packs to a temporary archive and replaces the old one - the old archive ends up inside the new one; Move: the plug-in locks the archive before deleting the sources (Open Salamander forum t=3859) - "Delete Error (32)", Skip (106 B-7z rows) |
| Pack dialog, *Overwrite* | same | refused since 106 ("Cannot copy a file to itself.", no name) |
| F5 / F6 into the archive shown in the other panel | `FilesAction` -> `PackCompress` (`fileswn8.cpp`, `pack2.cpp`) | as *Add* (106 H rows) |
| drag & drop, cut + paste into an archive panel | `DragDropToArcOrFS` -> `PackCompress` (`fileswna.cpp`) | as *Add* (same call; 106 X-drag) |
| an edited archive member packed back | `CFileTimeStamps` -> `PackCompress` (`salamdr3.cpp`) | n/a - the sources are the disk cache's temporary copies |

No loss on any of them (106 measured B and H on both packers), but neither plug-in says what is
wrong, ZIP's *Skip* silently adds the rest, and 7-Zip's result contains the old archive as an
item. 7-Zip's own console refuses exactly this with `-sdel` ("It is not allowed to include
archive to itself").

Where to check: the plug-ins cannot see the selection's identity any better than the core, and a
check in each packer would need a new text in each (7-Zip has none; ZIP's `IDS_PACKEDSOURCE`
"This file is one of the files being packed. The archive cannot be written over it." speaks of
*writing over*, which an *Add* does not do). The core already has the identity rule for exactly
this question - `PackArchiveIsSelectedSource` (106: archive identity vs every selected item, and
for selected folders the archive's folders up to the root; `SalPackTargetInSelection`) - and the
three routes above are the only core callers of a packer with a disk selection. One check in the
core, before the packer, covers ZIP, 7-Zip and the external RAR packer on every route, with the
core's existing texts.

The Pack dialog: 106 asked "Add or Overwrite?" first and refused only the *Overwrite* answer.
Every answer to that question is now refused, so the question is skipped: the refusal comes
before it (and before the Move's link scan, which may take long). 106's check inside the
*Overwrite* branch stays as a guard (the archive could change between the two checks).

Cost: one `FILE_READ_ATTRIBUTES` open per selected top-level item plus one per folder above the
archive, only when the archive exists. The first version argued this is small against the pack
that follows; the code review (SF5) pointed out that it runs on the UI thread with no wait window
and no Esc - over SMB thousands of items freeze the panel for seconds before the packer's own
progress appears. Pre-filter: when the archive has usable ids and exactly one link, its real
folder (from the resolved path) decides - not the panel folder: no plain file can be the archive;
the panel folder: only the item with the archive's long or 8.3 name can be. Folders, links
(reparse points) and every uncertain case keep the per-item check. The archive's folders are also
taken from the resolved path (review NIT: a junction or SUBST letter in the typed path hid the
real parents). On a file system without file ids a selected item with the archive's size and
times (or a selected folder with an ancestor's times) is a "maybe" and refused (house rule since
103/106: nothing is lost by a refusal).

**Behaviour change**: packing (Add, F5, F6, drag & drop) into an archive that is itself selected,
or that lies inside a selected folder, is refused as a whole; before, ZIP added the other files
after the user skipped the archive, and 7-Zip packed the old archive into the new one. Deselect
the archive.

## R4. Item 5 - the refusal's text

Core strings with "itself": `IDS_CANNOTCOPYFILETOITSELF` "Cannot copy a file to itself.",
`IDS_CANNOTMOVEFILETOITSELF` "Cannot move a file to itself.", `IDS_CANNOTMOVEDIRTOITSELF`
"Cannot move a directory to itself." - none with a `%s`. But the core has a dialog that shows a
file's name beside an error text: `CFileErrorDlg` with the template `IDD_ERROR3` ("Name:" +
"Error:" + OK; used by `fileswn5.cpp` for "Error Creating Directory"). The name is drawn by
`CStaticText` with path ellipsis (`STF_PATH_ELLIPSIS`), UTF-8; the error by
`SalSetWindowTextU8`. So the refusal can name the archive without a new string:

    [Pack]          Name:  C:\...\src.zip
                    Error: Cannot copy a file to itself.      (Move: "Cannot move a file to itself.")

Captions: Pack dialog `IDS_PACKTITLE` ("Pack"), F5 / drag copy `IDS_ERRORCOPY` ("Copy Error"),
F6 / drag move `IDS_ERRORMOVE` ("Move Error"), the 106 guard `IDS_ERROROVERWRITINGFILE`. The
named archive is what to leave out of the selection (for a selected folder: the folder holding
it). "Deselecting helps" in words would need a new core string in 8 languages; not added (the
maintainer's rule: no new strings unless clearly needed) - recorded.

Probe limit: `CStaticText` keeps its text to itself (WM_GETTEXT returns the empty template text -
106's result shows `[Static id=1150] Name:` with no name), so the probe can check the form (the
"Name:" label beside "to itself") but not the drawn name; a person sees it.

## R5. Summary of decisions

| Item | Decision | Code |
|---|---|---|
| 1 | record every created volume with its identity; a failure (fixed disk) deletes each recorded volume that still holds that file; removable media: the current volume as before; nothing once the archive is complete | `salpackvol.h` (new, pure), `zip/add.cpp` `PackMultiVol`, `CreateNextFile`, `DeleteCreatedVolumes` |
| 2 | refuse before anything is created with `IDS_CANTMULTIVOL` (fixed disk, sequential + WinZip names, no SFX); a failed final rename is reported and the pack fails | `SalMultiVolFinalNameTaken`, `PackMultiVol` |
| 3, 4 | the core refuses every pack into an archive that is one of its own sources, before the question / the packer, on all three routes | `fileswn7.cpp` (`PackArchiveIsSelectedSource` public, `ShowPackIntoItselfRefusal`), `fileswn8.cpp`, `fileswna.cpp` |
| 5 | the refusal names the archive (`CFileErrorDlg`, `IDD_ERROR3`); no new string | `ShowPackIntoItselfRefusal` |
