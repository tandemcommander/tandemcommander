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

## Review

Review 1 (general-purpose agent): killed twice without a report (05:36Z and after a resume; the run
log `.git/tandem-backlog-loop/logs/20261023-052858-...jsonl` records `killed` / `stopped`; its last
call - waiting on a control probe - was rejected). It left no findings; it does not count as a review
round. Its partial work: a control probe run on the pre-feature build reproduced the stray
`Sal*.tmp` (add-locked, `SalF58.tmp`). It restored `add.cpp` / `add_del.cpp` (tree clean, checked).

Its killed probe left the product registry key changed: `%TEMP%\tc320_backup.reg` (06:02, SHA-256
CF69145A... = the state every probe run of this feature restored) against the current export
(C775064F...): only the panel paths / focus (the add-ctl fixture) and `Plugins.ver Version (x64)`
(00d724bc -> 00d728f2, the Debug build's). Not restored: the maintainer's installed Tandem Commander
(started 06:43, after the probe) is running on the same key and writes its state on exit; the backup
is kept for the maintainer (owed to a person). The fixture `%TEMP%\tc320_zipreplace` (probe files
only) was removed.

Review 2 (fresh, same prompt): without GUI probes (the probe refuses to start while another
tandemcommander.exe runs) and without temporary source changes; negative controls outside the tree.

Review 2 result: **no MUST**, 2 SHOULD, 5 NOTE. It re-built (up to date), `saltests: 27559 checks,
0 failed`, encoding guard 0; enumerated the callers (`PackToArchive` from Pack / copy / move /
archive-edit update; `DeleteFromArchive`; `CleanUpSource` runs only without an error; nothing deletes
`TempName` after an error); and compared the old and the new replace with standalone P/Invoke
scripts under `%TEMP%`: archive held (share 3) - old: stray tmp, new: kept + tmp deleted; **the
temporary file held without delete sharing - old: the archive deleted, rename 32, archive gone under
"not changed"; new: archive unchanged**; hidden / hidden+system kept; hard link as before; a file
symbolic link - old: the link replaced by a plain file, real archive stale; new: 1464, nothing
changed; seven ACL denials on the archive - replaced as before; a WSL network share - replaced. It
also read the killed reviewer's extended probe (`%TEMP%\rev320\after_review.txt`, not in the
repository): 30 PASS / 2 FAIL - the 2 FAILs (add-long-*) are the core's Pack dialog refusing a too
long path before the plug-in; rows symlink, newest-time and `Zone.Identifier` time PASS.

- SHOULD 1 (a file symbolic link can no longer be updated, fails safe with the true message) ->
  spec *Edge Cases* records it; Inbox item `zip-cannot-update-an-archive-reached-through-a-symbolic-link`
  (needs the temporary file next to the final path - beyond this item).
- SHOULD 2 (the "only copy" case does not say so) -> needs a new string, which a run does not add
  (FR-005, stop-rules 3 #2); Inbox item `zip-does-not-say-the-temporary-file-is-the-only-copy`.
- NOTE 1 (shape (b) IS reproducible on an ordinary file: the temporary file held without delete
  sharing) -> recorded here and in the spec's *Edge Cases*; the measurement above corrects the
  "not reproducible" of *Measurement*.
- NOTE 2 (in that case the held temporary file cannot be deleted, so it may remain - the archive is
  intact, the message true) -> spec *Edge Cases*; accepted.
- NOTE 3 (saltests test the shared rule, not the plug-in's mapping; only the probe catches a revert
  of the plug-in) -> accepted: the mapping is four lines with side effects, the probe is the guard
  (its before run FAILs).
- NOTE 4 (check 5 pinned an OS behaviour) -> fixed: the "time moved" assertion became a printed line
  (`saltests 320: a replace onto a file with a named stream moved the replacement's last-write
  time`); rebuilt: BUILD SUCCEEDED, `saltests: 27558 checks, 0 failed`, encoding guard 0.
- NOTE 5 (the archive keeps its ACL / creation time / named streams, Mark of the Web) -> as the
  spec's Clarifications decided; FAT/exFAT and SMB/NAS not driven (fail safe by the rule).

No second review round was needed (no MUST).
