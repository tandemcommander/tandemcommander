# Fix log - 395-cpio-solo-empty-name

Backlog item `unpack-silently-drops-a-cpio-file-whose-only-name-normalizes` - Unpack silently drops a
cpio file whose only name normalizes to empty.

## Measurement before (main bb8aa693, Debug x64 - `.\build.cmd` -> BUILD SUCCEEDED, up to date)

New probe `probe/cpiosolo_probe.ps1` (fixtures `probe/mkcpiosolo.py`, copied from 394's probe; odc
writer from 393's, a new ustar writer), run from a work folder before the branch existed:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <work>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <work>\cpiosolo_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib E:\Projects\tandemcommander\specs\098-long-path-overruns\probe\fix_probe_lib.ps1"
```

Result `probe/result_before.txt`: PASS 22 / FAIL 10; registry restored, identical.

- FAIL (the defect, 9 rows): `UNP-SOLO-DOT-DEL`, `-DOTSLASH-`, `-NUL-`, `UNP-CRC-SOLO-DOT-DEL`,
  `UNP-ODC-SOLO-DOT-DEL`, `UNP-RPM-SOLO-DOT-DEL`, `UNP-ORPHAN-DOT-DEL`, `UNP-CRC-ORPHAN-DOT-DEL`,
  `UNP-TAR-SOLO-DOT-DEL` - each extracted only `ok.txt`, showed no window and DELETED the archive.
- FAIL (the probe's own fault): `COPY-SOLO-DOT` counted the core's Copy dialog as a window; the
  row now accepts that dialog and rejects any box with an error code.
- PASS (controls): `UNP-SOLO-DOT-ZERO-DEL`, `UNP-ORPHAN-DOT-ZERO-DEL`, `UNP-DOTDIR-DEL`,
  `UNP-TAR-DOTDIR-DEL`, `UNP-WAIT-DOT-DEL` (a.txt = AAA), `UNP-SOLO-DOT-MASK` (mask `*.txt`).

Decision on tar (the item's Notes): a ustar regular member `.` with data is dropped the same way
(row `UNP-TAR-SOLO-DOT-DEL`) - so it gets the same rule.

Cause (code at HEAD): `ReadArchiveHeader`, "skip invalid names", marks every member whose name
normalizes to nothing `Ignored` (cpio: also `NameEmpty`, 394). `DoUnpackArchive` then passes
`simulate = Ignored || !found` to `WriteOutData` (a single-name member) or, for a newc / crc group
member, `SalCpioLinkDecide` returns `SAL_CPIO_LINK_SKIP` when no name waits (orphan group): the data
is read past, nothing sets `refused`, the operation returns TRUE and the core deletes the archive.

## Analyze (speckit-analyze, one pass - no CRITICAL / HIGH)

- C1 MEDIUM - the data-first layout whose later name is not asked has no probe row: accepted, the
  pending decision is covered by the saltests of the pure rule (a mask matching the raw `.` but not
  `a.txt` cannot be typed reliably).
- C2 LOW - no row with two such members (one box): accepted, the once-flag follows 306's.
- C3 LOW - F3 unchanged only through 394's VIEW row in the regression run: accepted.

## Consumers enumerated (Grep)

- `WriteOutCpioGroupMember`: called only by `DoUnpackArchive` (the new `emptyAsked` parameter has a
  default `FALSE`; no other caller).
- `NameEmpty` / the "skip invalid names" branch: `IsCpioGroupMember`, `DoUnpackArchive`,
  `UnpackOneFilePass` (394) - unchanged; `NameEmptyRegular` is read only by `DoUnpackArchive` and
  `WriteOutCpioGroupMember`.
- Who can ask for such a member: `DoUnpackArchive` through `UnpackWholeArchive` (a mask - matches
  the raw name) and `UnpackArchive` (panel names - the member is never listed, so never matched);
  `UnpackOneFilePass` (F3, single copy, the further passes of 325) asks by a listed name only.
  So the report can only come from a whole Unpack - the Copy row stays silent (measured).
- `CCpioGroups` end of archive: both end paths of `DoUnpackArchive` (`TAR_EOF` and the trailer)
  call `WriteOutCpioEmptyNames` and now `ReportCpioEmptyLost`.

## Implementation

- T002 `src/common/salcpiolink.h`: `SAL_EMPTY_NAME_SILENT / REPORT / PENDING`,
  `SalEmptyNameDataDecide(regularFile, hasData, asked, groupMember, cpioAction, groupState)` and
  `SalEmptyNamePendingCleared(cpioAction)`.
- T003 saltests `TestEmptyNameData395` - 19 checks (30813 -> 30832).
- T004 `tar.h`: `SCommonHeader::NameEmptyRegular`, `CArchive::EmptyNameShown`, `ReportEmptyName`,
  `SCpioGroup::EmptyLost / EmptyLostName`, `ReportCpioEmptyLost`, `WriteOutCpioGroupMember(...,
  emptyAsked)`; resets in `Initialize` and the constructor.
- T005 `ReadArchiveHeader`, "skip invalid names": `NameEmptyRegular` = cpio: mode `CP_IFREG`;
  tar: `!Ignored && !IsDir && LinkType == 0` as `ReadTarHeader` left them (computed before the
  branch sets `Ignored` and clears `LinkType`).
- T006 `ReportEmptyName`: `GetErrorText(ERROR_INVALID_NAME)` + blank line + `"<raw name>"`, once
  per operation (heap buffer sized for the whole name - never cut).
- T007 `DoUnpackArchive`: `emptyAsked = found && NameEmptyRegular` taken before 394's
  `found = FALSE`; a member outside a group -> `SalEmptyNameDataDecide` REPORT ->
  `ReportEmptyName`, `refused = TRUE` (the rest is extracted, the operation fails).
- T008 `WriteOutCpioGroupMember`: the action computed once; a pending loss is cleared by a later
  `WRITE` / `COPY` / `REPORT` of the group; an `emptyAsked` member whose decision is PENDING marks
  the group (`EmptyLost`, raw name).
- T009 `ReportCpioEmptyLost` at both end paths: a pending group -> the report, `refused = TRUE`.

## Measurement after (branch, Debug x64)

- `.\build.cmd` -> BUILD SUCCEEDED (exit 0).
- `saltests.exe` -> `saltests: 30832 checks, 0 failed`.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Probe `probe/result_after.txt`: PASS 32 / FAIL 0 (16 RUN rows); each of the 9 data rows shows
  `[TAR Plugin Error] (123) Název souboru či adresáře nebo jmenovka svazku je nesprávná. "."` (`"./"`,
  `""` for those rows), extracts `ok.txt` and KEEPS the archive; the 7 controls show no window
  (Copy: only the core's Copy dialog) and the archive is deleted as asked; registry restored,
  identical. (The `COPY-SOLO-DOT` FAIL of the before run was the probe's own check, fixed before
  this run; the row is a control - the member is never listed.)
- Negative control `probe/result_negctl.txt` (both report sites disabled by a temporary edit - the
  non-group decision compared with -1, `ReportCpioEmptyLost` with `false &&` -, rebuilt, then
  `git checkout -- src/plugins/tar/untar.cpp` from the index holding the fix, rebuilt): PASS 23 /
  FAIL 9 - exactly the 9 data rows (no window, archive deleted); the controls pass. Both sites were
  disabled together: the two orphan rows reach only the end-of-archive report (group members), the
  seven solo rows only the immediate one - each site is exercised by its own rows.
- No UI string, dialog or resource changed (the text is the system's): no `.slt` refresh needed
  (stop-rules §2.13 not triggered).
- Regression probes (`probe/regress_*.txt`, label regress-395, the branch build): 306 30 / 0,
  308 12 / 0, 309 16 / 0, 310 52 / 0, 321 tar 20 / 0, 321 unpack 12 / 0, 393 28 / 0, 394 22 / 0 -
  each as recorded by feature 394 (394's data-first rows still show only their "(2)" box: the
  pending loss is cleared by the REPORT at `a.txt`).
