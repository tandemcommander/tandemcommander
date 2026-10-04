# Research for feature 106: a pack writes its archive over a file it packs

Branch `106-zip-overwrite-source` (from `105-pictview-saveas-loss`, HEAD cfd49e2b), 2026-10-04.
Machine: Windows 11 10.0.26200, ACP 1250, Czech Windows UI, user not elevated, NTFS `C:` with
8.3 names, `\\localhost\C$` reachable, 7-Zip 22.01 installed (used to read results), WinRAR not
installed. Pre-change build preserved as `build\tandemcommander\Debug_x64_pre106`. The committed
probe `probe/packself_probe.ps1` drives the program on the hidden desktop; its first run on the
build before is `probe/packself_result_measurement_pre106.txt` (the final probe version on that
build: `probe/packself_result_pre106.txt`).

The defect as recorded (103 research row 15): "ZIP plug-in: self-extractor / multi-volume first
volume / next volume (`add.cpp PackSelfExtract`, `PackMultiVol`, `CreateNextFile`) -
`CREATE_ALWAYS` of the new archive's file after 'overwrite?' - none against the selection".

## 0. Headline

1. **The premise is right for multi-volume ZIP, and the loss is total, not "garbage in the
   archive".** Multi-volume is reachable on a fixed disk (Extended Pack Options, shown by
   default; on a fixed disk the volumes are always `name.z01`, `name.z02`, ... and the last is
   renamed to `name.zip` - "WinZip names", default on). Measured on the build before:
   - a selected file named like **volume 1** (`a.z01`, archive `a.zip`): "Overwrite file a.z01?"
     *Yes* -> `CREATE_ALWAYS` with share mode 0 truncates it **before the selection is even
     listed** (the first volume was created before `EnumFiles2`); reading it then fails with a
     sharing violation; the error path deletes the current volume name - **`a.z01` is gone**, on
     a **Copy** too. Same with `A.ZIP` (case), the folder's 8.3 name and
     `\\localhost\C$\...` (rows C-*), and when the volume name is a **hard link** of a selected
     file in another folder (C-hardlink-copy: the source's data is overwritten with volume data
     through the link, and the archive holds that instead of the source);
   - named like a **later volume** (`a.z04`): the source is read and packed into volumes 1-3,
     then volume 4 is created over it. Copy: the source now holds **archive data** (D-later-copy).
     Move: the archive is complete except that `CleanUpSource` deletes "the source" `a.z04` -
     which is volume 4 - and `b.bin`: **the archive is broken ("Missing volume: a.z04") and both
     files are gone** (D-later-move);
   - **a declined overwrite deletes the file**: an unrelated, not selected `out\a.z02`, the
     question for volume 2 answered *Cancel* -> the cleanup `DeleteFileU8(TempName)` deleted
     `a.z02` (TempName had already been set to the declined name). Volume 1's question declined
     keeps the file only because that error path skips the cleanup (E-decline-vol1).
2. **The self-extractor routes are unreachable** (104): no `sfx\*.sfx` package is shipped, so
   *Create self-extracting archive* is disabled and *Create SFX* says "no SFX installed".
   `PackSelfExtract` and the SFX branch of `PackMultiVol` have the same order (create the exe,
   then list the files) - changed with the same rule, compiled, not driven.
3. **A route the premise did not name loses the source on every packer: the core's Pack dialog,
   "Overwrite".** When the archive name exists the core asks "Add into existing archive or
   overwrite existing one?"; *Overwrite* runs `SalDeleteFile(archive)` before the packer. If the
   archive is one of the selected files (`src.zip` + `b.bin` packed into `src.zip`), that file is
   deleted first and is not in the result (ZIP: the new archive file is open, reading `src.zip`
   fails; 7-Zip: the item is missing). Rows A-*: ZIP and 7-Zip, Copy and Move, same name, case,
   8.3 file name, `\\localhost\C$` - **every row lost `src.zip`**, also on Copy.
4. **No loss on the other routes** (measured, unchanged):
   - ZIP, *Add* into an existing archive that is itself selected (B-zip-*, also with *Backup ZIP*
     off = update in place), and F5/F6 into the archive shown in the other panel while it is
     selected on the left (H-zip-*): the plug-in holds the archive open for writing (share read)
     during the whole operation, so reading it as a source fails with a sharing violation
     (Retry/Skip/Cancel); a skipped file is `AF_NOADD` and Move does not delete it;
   - 7-Zip plug-in (B-7z-*, H-7z-*): it writes a temporary archive and replaces the old one; the
     old archive ends up **inside** the new one (as `7z a` does without `-sdel`); Move first
     locks the archive (an Open Salamander fix, forum t=3859), so deleting it fails ("Delete
     Error", 32 - Skip) and it stays. 7-Zip's own console refuses this only with `-sdel` ("It is
     not allowed to include archive to itself", measured with 7z.exe 22.01);
   - TAR: no packing (`PackToArchive` is commented out);
   - the external packer RAR (WinRAR): not installed - not driven; it runs after the core's
     dialog, so route 3's refusal covers it. 7-Zip console is not a packer since 084;
   - ZIP *Create SFX* from an archive (`add_del.cpp`): unreachable (no SFX); and its exe cannot
     be the open archive (the archive is open with share read only - `CREATE_ALWAYS` fails);
   - ZIP *Repair*: the code is inside `/* */`.

## 1. The ZIP plug-in's write routes

| Route | Output created | Before the fix | Fix |
|---|---|---|---|
| `PackNormal` (plain archive, new or update) | archive `OPEN_ALWAYS` (RW, share read) or backup temp `Sal*.tmp` (`CREATE_ALWAYS`, a new unique name), then delete + rename | archive held open for writing: a selected archive cannot be read (32), not truncated; the temp name is new | unchanged |
| `PackMultiVol` volume 1 | `CreateNextFile`: `CREATE_NEW`, on "exists" the plug-in's "Overwrite?" -> `CREATE_ALWAYS` share 0 | created **before** the files were listed; no check | listing first; identity check before the question and before every `CREATE_ALWAYS` (also "All") |
| `PackMultiVol` volume n | `NextDisk` -> `CreateNextFile` while packing | no check; cleanup deleted the current name even when it was declined | the same check; `TempNameOurs` |
| last volume -> `name.zip` | `MoveFileU8` (never replaces) | an existing `name.zip` stays, the last volume keeps its `.zNN` name (silent) | unchanged, recorded |
| `PackMultiVol` + SFX, `PackSelfExtract` | `name.exe`: `TestIfExist` ("Overwrite?") -> `CREATE_ALWAYS` | before listing; unreachable | listing first; identity check before the question |
| `CreateSFX` (menu) | `name.exe` from the open archive | unreachable; the open archive cannot be truncated | unchanged |

`CleanUpSource` (Move) deletes only `AF_ADD`/`AF_OVERWRITE` items and only when the whole
operation succeeded (`!ErrorID && !UserBreak`); a file skipped on a read error becomes
`AF_NOADD`. So "Move must never delete a source whose packing failed" held already - the loss in
D-later-move was the identity of the source with an output, which the fix now refuses.

## 2. The comparison

`src/common/salsamefile.h` (103) gives the file system's identity: volume serial + 64-bit file
index, the 128-bit id where available (ReFS), and metadata for file systems without usable ids.
For an output that would be written over:

- the same id -> the same file; a hard link counts (`CREATE_ALWAYS` truncates the shared data;
  103's `Links > 1 -> legacy` was for *delete then recreate*, which keeps the data under the
  other name - not the case here);
- no usable ids on one side (WebDAV reports 0) and equal size + last write (+ creation when
  known) -> "maybe" -> refused (nothing is lost by a refusal);
- otherwise another file -> the old handling (the overwrite question).

Cost: the ZIP check runs only when an output file already exists, and opens every listed source
(`FILE_READ_ATTRIBUTES` opens - no share conflicts, no WebDAV download). The first version
opened only sources whose *listed* size equalled the output's size; the review showed (SF-1,
reproduced) that NTFS updates a directory entry's size only for the name a write went through,
so a hard-linked source written through its other name is listed with a stale size - the filter
is gone. The core check runs only on the *Overwrite* answer: one identity
per selected item and per folder above the archive.

## 3. Ordering in the multi-volume pack

`PackMultiVol` used to: open progress -> [SFX: create the exe] -> `CreateNextFile` (volume 1) ->
`EnumFiles2` -> `MatchAll` -> 65,535 check -> pack. Now: open progress -> `EnumFiles2` ->
`MatchAll` -> 65,535 check -> (nothing to pack / error: return, nothing created) -> [SFX: check
+ create the exe] -> `CreateNextFile` -> pack. `EnumFiles2` does not use the output (it only
calls the enumerator and checks empty folders); the enumerator's error dialogs had no progress
dependency. With nothing to pack the old code created volume 1 and deleted it again (and could
ask "Overwrite a.z01?" for nothing).

## 4. Strings

The ZIP plug-in has no text for "this file is one of the files being packed" and cannot load the
core's ("Cannot copy a file to itself." lives in the core's language module, which a plug-in
cannot name). One new string `IDS_PACKEDSOURCE` = 1255, in the free part of the 1248-1263 bundle
(5 of 16 used): the translation tool's bundle ordinals do not move. Shown through the plug-in's
`ProcessError` (file name + text, OK). The core reuses `IDS_CANNOTCOPYFILETOITSELF` /
`IDS_ERROROVERWRITINGFILE`.
