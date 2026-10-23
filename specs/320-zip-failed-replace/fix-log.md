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

## speckit-analyze

No CRITICAL / HIGH. Accepted: C1 (MEDIUM) - the "archive gone, temporary file kept" branch of the
ZIP mapping has no GUI or unit test of its own (needs a third party deleting the archive during the
operation); the shared rule's 105 checks cover `srrLeftAtTemp`; left to the review to read. C2 (LOW)
- no probe row for Move to archive with a held archive (the clean-up is skipped on any error, as
before). U1 (LOW) - the archive now keeps its own named streams / ACL / creation time after a
replace (ReplaceFileW); checked in saltests (T005).

## Change (T002-T005)

1. `src/plugins/zip/add_del.h` / `add.cpp`: `CZipPack::ReplaceArchiveWithTemp()` - wide names
   (`SplU8ToWExtAlloc`), `SalReplaceWithTempW(wZip, wTemp, TRUE, TRUE, &err)`, results as D2; on
   `srrDone` the attributes as before and, with "set zip file time to the newest file time", the
   time set again on the archive (see the trap below); no memory -> the temporary file deleted,
   `IDS_LOWMEM`. `#include "../../common/salsafereplace.h"` in its own include block (clang-format
   would otherwise realign the four include comments above it).
2. `CZipPack::PackNormal` (`add.cpp`) and `CZipPack::DeleteFromArchive` (`add_del.cpp`): the
   `ClearReadOnlyAttr` + `DeleteFileU8` + `MoveFileU8` + `SetFileAttributesU8` lines replaced by
   `ErrorID = ReplaceArchiveWithTemp();`.
3. `src/saltests/saltests.cpp`: `TestSafeReplace320` (19 checks) after `TestSafeReplace105`: a stream
   target (`report:zip.zip`) -> kept, stream and host unchanged, temporary file left to the caller;
   a target held with sharing read + write -> kept, 32; with + delete -> done; the replacement's
   last-write time kept onto a target without named streams; onto a target with `Zone.Identifier`
   the stream kept and the time moved.

Trap met (T005): the first version of check 4 expected the replacement's last-write time kept onto
an archive WITH a named stream - failed. Measured separately (PowerShell, ReplaceFileW with a NULL
backup name): without a named stream the replacement's time is kept (1997-05-05 stays); with
`Zone.Identifier` on the target the time becomes "now" - ReplaceFileW copies the stream into the
replacement. A downloaded archive (the usual case for the mark) with "set zip file time to the newest
file time" on would have lost that time, so `ReplaceArchiveWithTemp` sets it again after `srrDone`;
the unit checks were split into 4 (kept) and 5 (moved - documents why the plug-in re-applies it).
(A first PowerShell attempt passed `$null` for the backup name, which PowerShell turns into "" -
ReplaceFileW then fails; `[NullString]::Value` fixed the measurement.)

Negative control of shape (b) (the old algorithm on a stream, PowerShell `DeleteFileW(stream)` then
`MoveFileW(temp, stream)`): delete True, move False (123), the stream gone, the temporary file left -
exactly what 319 measured. The new rule on the same target: kept, unchanged (saltests check 1).

## Checks after the change

- `.\build.cmd`: BUILD SUCCEEDED, exit 0 (3 builds; the last after the include-block tweak).
- `saltests: 27559 checks, 0 failed` (27540 + 19; the first run after the first build failed check 4
  - the trap above). (One run right after the first build printed 27540: it ran an older binary
  while the output was being produced; every run after shows 27557/27559.)
- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- clang-format (VS 2022 LLVM, `.clang-format`): the changed lines of `add.cpp`, `add_del.cpp`,
  `add_del.h` and `TestSafeReplace320` clean; the remaining hunks are older lines outside the change.
- Probe (`probe/result_after.txt`, run on the second build; the third differs only by a blank line):
  **12 PASS / 0 FAIL** (6 RUN + 6 END); add-locked and del-locked: the replace message, nothing new,
  nothing changed (before: a new `Sal623.tmp` / `Sal272.tmp`); the four controls as before;
  registry restored, identical (SHA-256 CF69145A...).

Not driven: "archive gone, temporary file kept" (`srrLeftAtTemp`) and "both gone" - need a third
party deleting the archive during the operation (analyze C1); Move to archive with a held archive
(the clean-up runs only without an error, unchanged). No person step is owed.
