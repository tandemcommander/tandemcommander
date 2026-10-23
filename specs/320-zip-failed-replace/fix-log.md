# Fix log - 320-zip-failed-replace

Backlog item `zip-says-the-archive-was-not-changed-after-a-failed-replace` (source measure:319).

## Measurement at 4252bcb6 (main, before the feature)

Debug x64 build of 4252bcb6 (`.\build.cmd`, up to date). Sites (Grep `IDS_ERRRESTORE`): the only two
replace steps of the ZIP plug-in, both in the default temporary-copy mode (`Config.BackupZip`,
`DefConfig` true):

- `CZipPack::PackNormal` (`src/plugins/zip/add.cpp`) - Pack / copy / move files into an existing
  archive (`PackToArchive` -> `PA_NORMAL`);
- `CZipPack::DeleteFromArchive` (`src/plugins/zip/add_del.cpp`) - Delete inside an archive.

Both: `ClearReadOnlyAttr(ZipName); if (!DeleteFileU8(ZipName) || !MoveFileU8(TempName, ZipName))
ErrorID = IDS_ERRRESTORE; SetFileAttributesU8(ZipName, ZipAttr | FILE_ATTRIBUTE_ARCHIVE);`. The
temporary file (`CreateTempFile`: `SalGetTempFileName(<archive folder>, "Sal")`) is deleted only on
the error / cancel path before this step - never after it. Two shapes:

- (a) delete fails -> archive unchanged, `Sal*.tmp` left (measured below);
- (b) delete succeeds, rename fails -> the archive gone, the new content only in `Sal*.tmp`, message
  "Archive was not changed" (319's stream case; not reproducible on an ordinary file here).

Read-only archives are refused before any work (`IDS_READONLY` in `PackToArchive` and
`DeleteFromArchive`), so read-only cannot make the replace fail.

Probe `probe/zipreplace_probe.ps1` (written for the measurement from 319's; 098's library), first run
from a scratch folder under `%TEMP%`, then copied unchanged:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\zipreplace_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib E:\Projects\tandemcommander\specs\098-long-path-overruns\probe\fix_probe_lib.ps1"
```

`a.zip` (seed.txt, keep.txt) held open by the probe's process (`CreateFileW` GENERIC_READ, sharing
read + write = 3, or + delete = 7):

- add-locked (share 3; Pack 'plain' into a.zip, "add?" Yes, Add Files box OK) -> ZIP "Cannot replace
  original archive with temporary working file. Archive was not changed."; a.zip unchanged; new
  `src\Sal623.tmp` - FAIL;
- del-locked (share 3; Change Directory into a.zip, Select seed.txt, Delete, Yes) -> the same
  message; a.zip unchanged; new `src\Sal272.tmp` - FAIL;
- add-ctl, del-ctl (not held), add-sharedel, del-sharedel (share 7) -> a.zip changed as asked,
  nothing new - PASS.

`probe/result_before.txt` is the run with a seventh row, del-stream (Change Directory into
`src\report:zip.zip`): the core refused the path with error 123 ("Error Changing Directory"), the
driver looped on the error box until the row was ended (END FAIL "did not exit"). So an archive in a
stream is not reachable through the panel; Pack refuses the name since 319. The row was removed
from the probe (a comment says why). Registry restored, identical (SHA-256 CF69145A...).

## Decisions

- D1: both sites use `SalReplaceWithTempW` (`src/common/salsafereplace.h`, header-only, feature 105;
  CLAUDE.md "Replacing a user's file") - ReplaceFileW in one step, a fallback rename only where the
  file system does not support it, the target never deleted first.
- D2: results - `srrDone`: attributes as before; `srrFailedKept`: delete the temporary file,
  `IDS_ERRRESTORE` (true now); `srrLeftAtTemp`: keep the temporary file, `IDS_ERRCREATE` for the
  archive with the system error and the temporary file's name, `IDS_NODISPLAY`; `srrFailedBothGone`:
  `IDS_ERRACCESS` for the archive with the system error, `IDS_NODISPLAY`. No new string.
