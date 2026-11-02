# Fix log - 399-zip-symlink-archive

Backlog item `zip-cannot-update-an-archive-reached-through-a-symbolic-link`.

## Measurement before (main at 2a5b7d40)

- `.\build.cmd` -> up to date (Debug x64).
- New probe `probe/zipsymlink_probe.ps1` (driver of 320's `zipreplace_probe.ps1`, library of 098),
  run on the hidden desktop:

  ```text
  powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <probe> -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -OutFile ..."
  ```

  Result `probe/result_before.txt`: **14 PASS / 4 FAIL**, registry restored and identical, fixture
  removed.
  - FAIL add-symlink, add-relsymlink, del-symlink, del-relsymlink: the ZIP box "Cannot replace
    original archive with temporary working file. Archive was not changed.", the real archive
    unchanged, the link still the link, nothing new.
  - PASS add-plain / del-plain, add-junction / del-junction (a directory junction in the folder part:
    the real archive updated - the item's "not verified" note answered: only a file link as the last
    component fails), add-symlink-locked (real archive held with sharing read + write: the message,
    nothing changed).
- How the routes name such an archive: Pack (the typed name, relative to the panel), the panel's
  Change Directory into the archive and Delete inside it all give the plug-in the link's path as
  `ZipName`; `CZipPack::CreateTempFile` makes `Sal*.tmp` in the folder of `ZipName` (next to the
  link) and `ReplaceArchiveWithTemp` -> `SalReplaceWithTempW(ZipName, ...)` -> `ReplaceFileW` onto
  the link fails with 1464 -> `srnKeepTarget` -> the temporary file deleted, `IDS_ERRRESTORE`.
- `ZipAttr` is read with `SalGetFileAttributes(ZipName)`: on a link that is the link's own
  attributes (`ARCHIVE | REPARSE_POINT`), not the real archive's.

## Consumers (fix protocol)

- `CZipPack::CreateTempFile` - called only from `PackNormal` (add.cpp) and `DeleteFromArchive`
  (add_del.cpp), both with `ZipFile` open and `Config.BackupZip` on.
- `CZipPack::ReplaceArchiveWithTemp` - the same two sites, after `CreateTempFile`.
- `TempName` is otherwise used by `PackMultiVol` / `NextDisk` (volume names, not touched here).
- `SalReplaceWithTempW` other callers (core `cfgimpdlg.cpp`, `salamdr2.cpp`; PictView `saveas.cpp`,
  `thumbs.cpp`; SFTP `operats.cpp`) - not changed (the helper itself is not changed).

## Decisions

- Update the real archive (item *Expected*, first option) - no new string.
- Follow only a name that is itself a name-surrogate reparse point and not a folder (a file symbolic
  link); everything else unchanged (spec Clarifications).
- Unresolvable link -> as today (fails safe with the true message).

## Analyze (speckit-analyze)

Round 1: CRITICAL 0, HIGH 0. MEDIUM U1 (T003 undecided pure row) fixed in tasks.md. Accepted:
MEDIUM C1 (FR-005 attributes from the real archive not proven by a check - beyond the measured
defect; the code path is the same `SetFileAttributes` as 320 on another name), LOW C2 (real folder
not writable - the existing error path), LOW C3 (FR-006 "no new text" - proven by the diff).
Round 2 (after the fix): CRITICAL 0, HIGH 0; C1-C3 as accepted.

## Implementation

- `src/common/salsafereplace.h`: `SalReplaceFollowsName` (pure: reparse point, not a folder,
  name-surrogate tag), `SalFinalPathPlainW` (pure: `\\?\C:\` / `\\?\UNC\` -> plain, anything else
  NULL), `SalReplaceTargetOfLinkW` (FindFirstFileW tag of the name + GetFinalPathNameByHandleW of the
  open handle). Existing functions unchanged.
- `src/plugins/zip/add_del.h/.cpp`: `CZipPack::ReplaceTarget` (UTF-8, heap, NULL = ZipName).
- `src/plugins/zip/add.cpp`: `CreateTempFile` resolves once with `ZipFile` open (both routes call it
  with the archive open - `PackNormal` and `DeleteFromArchive`, T007 checked; no change needed in
  `DeleteFromArchive`), keeps a target that fits `U8_MAX_PATH`, re-reads `ZipAttr` from the real
  archive, makes `Sal*.tmp` in the real archive's folder; `ReplaceArchiveWithTemp` replaces, sets
  the attributes and the newest time on the target; every message still names `ZipName`.
- No new string, no resource change (FR-006).

## Measurement after

- `.\build.cmd` -> BUILD SUCCEEDED (only the pre-existing C4018 warnings of `salamdr2.cpp`).
- `saltests.exe` -> `saltests: 282271 checks, 0 failed` (`TestSafeReplace399`: 9 pure rule rows,
  10 path rows, real file links under %TEMP% (absolute and relative, a non-ASCII name): the target
  resolved to the real file; the negative control - a replace onto the link's name - fails with
  1464 and keeps everything; the replace onto the resolved target with the temporary file next to
  it updates the real file, both links stay links, no temporary file left).
- Probe `probe/result_after.txt`: **18 PASS / 0 FAIL** (before 14 / 4): add-symlink,
  add-relsymlink, del-symlink, del-relsymlink now change only `real\a.zip`, the link still the same
  link, nothing new, no message; add-symlink-locked: the message, nothing changed; plain and
  junction rows as before. Registry restored and identical.
- Regression: 320's probe `zipreplace_probe.ps1` on the new build -> `probe/result_320_regression.txt`
  12 PASS / 0 FAIL.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- clang-format applied to the new code only (it would also re-flow unrelated old parts of
  `saltests.cpp` and an include block of `add.cpp` - those were left as they were).

## Review

Review 1 (general-purpose agent, refute-first): **no MUST, no SHOULD**, 2 NOTE. It re-ran the probe
on the branch build (18 / 0, registry identical), saltests (282271 / 0) and the encoding guard (0);
enumerated the callers (`PackNormal`, `DeleteFromArchive` only; the archive is open share-read
while it is resolved, so the replaced file is the file read); checked the panel refresh (the core's
`GetFileTime` follows the link); ran a copy of the probe with a hidden real archive (attributes
0x22 kept through add and delete - FR-005 proven, the analysis' C1 closed); and resolved, with a
test program on the header, a chain of two links, a link through a junction, a link to another
volume (C: -> E:, the temporary file on E:, srrDone, link kept), a link to a SUBST drive, a link to
`\\localhost\E$\...` (UNC form), an upper-case name, and a link to a hard link.

- NOTE 1 (`add.cpp` `CreateTempFile`: the real archive's attributes read through the plain path - with
  `LongPathsEnabled=0` and a target of 260+ characters the read fails, `ZipAttr` keeps the link's
  0x420 and a hidden / system attribute of the real archive is dropped after the replace; content
  safe) -> fixed: the attributes are read through `SplU8ToWExtAlloc(target)` (the `\\?\` form).
  Rebuilt: BUILD SUCCEEDED; probe 18 / 0 (registry identical); saltests 282271 / 0.
- NOTE 2 (Pack's Overwrite into a link name moves the link aside and writes a plain file there; a
  cancelled pack into a zero-length archive deletes `ZipName`, the link) -> outside this item (add
  and delete only): Inbox item `pack-overwrite-into-an-archive-reached-through-a-symbolic`
  (review:399).
- Clean-up: the reviewer left `E:\rev399scratch_eB` (one 4-byte `y.zip`); the run's sandbox refused
  to delete it -> person step `delete-the-review-scratch-folder-rev399scratch-eb-on-drive-e`.

No second review was needed (no MUST).
