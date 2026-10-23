# Fix log - 318-pack-name-trailing-dot

Backlog item `pack-archive-name-trailing-dot-or-space` (source measure:317).

## Measurement at efb9b0ad (main, before the feature)

Debug x64 build of efb9b0ad (`.\build.cmd`: BUILD SUCCEEDED, exit 0). A probe written for the
measurement from 317's driver (`specs/317-pack-name-space/probe/pack317_probe.ps1`) and 098's
library, first in a scratch folder under `%TEMP%`, now `probe/pack318_probe.ps1` (unchanged), run on
the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\pack318_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib E:\Projects\tandemcommander\specs\098-long-path-overruns\probe\fix_probe_lib.ps1"
```

Result (`probe/result_before.txt`): **12 FAIL / 30 PASS** (RUN + END rows), registry restored and
identical. Every row: the folder `plain` in the left panel, the name put into the entry with
WM_SETTEXT, OK, the ZIP plug-in's "Create New Archive" box answered OK. Each new file was also
opened through its plain (non-`\\?\`) path:

- created literally, plain open **no** (FileNotFound): `report.`, `report.zip..`, `report.zip `,
  `report. `, `<src>\abs.` (absolute) - FAIL;
- created literally, plain open **yes** on Windows 11 10.0.26300: `CON.zip`, `con` (-> `con.zip`),
  `NUL .zip`, `COM1.zip`, `lpt9.tar.zip`, `COM<sup1>.zip`, `<src>\prn.zip` - FAIL by the item's
  *Expected* (Windows 11 no longer maps a device name with an extension to the device);
- PASS: ` ..` refused ("The path specified is invalid.", 317); `plain.zip`, `report.v1.zip`,
  `CONSOLE.zip`, `con bla.zip`, `COM10.zip`, ` typed.zip`, `.cfg.zip` packed; the empty entry
  refused ("Empty name has no sense here.").

Reachability: Alt+F5 in a disk panel -> `CFilesWindow::Pack` (`src/fileswn7.cpp`) -> `CPackDialog`
(`Transfer` appends the extension only to a name without a dot - `report.` stays) -> OK ->
`SalGetFullName(fileBuf, ..., MAX_PATH, TRUE)` (keeps trailing dots / spaces) ->
`SalPackNameIsOnlyDotsAndSpaces` (317) -> `ExecutePacker`.

Consumers enumerated: `SalPackNameIsOnlyDotsAndSpaces` is called at `src/fileswn7.cpp` (Pack) and in
`src/saltests/saltests.cpp` (`TestPackName317`) only.

## Decisions

- R1: the check stays where 317's is - after `SalGetFullName`, before the "packed into itself"
  check, the question and the packer; the same error path (`IDS_PATHISINVALID`, the dialog again).
- R2: refused = the last part ends with `.` or ` `, or is a reserved device name (Microsoft's list:
  CON, PRN, AUX, NUL, COM0-9, LPT0-9, COM/LPT + superscript 1/2/3) before its first dot with trailing
  spaces removed, case-insensitive. Not refused: ` CON.zip`, a trailing tab, `CONSOLE.zip`,
  `con bla.zip`, `COM10.zip` (spec Clarifications).
- R3: 317's `SalPackNameIsOnlyDotsAndSpaces` is replaced by `SalPackNameIsNotKeptAsTyped` (a
  superset); its checks are carried over (`\t..` now TRUE: it ends with a dot).
- R4: no new string.

## speckit-analyze

No CRITICAL / HIGH. Accepted: C1 (LOW) `COM0` / `LPT0` / superscript 2, 3 only in saltests, not
probe rows - the same rule and path as the driven device rows; C2 (LOW) "no new string / no plug-in
change" has no own task - visible in the diff, `build.cmd` (not `full`) suffices.

## Change (T003-T005)

1. `src/common/salpackname.h`: `SalPackNameIsOnlyDotsAndSpaces` (317) replaced by
   `SalPackNameIsNotKeptAsTyped` (the last part ends with ' ' or '.', or
   `SalPackNameIsReservedDevice`) and `SalPackNameIsReservedDevice` (research R2); helper
   `SalPackNameUpperAscii`. Header-only, reads UTF-8 bytes; only ASCII letters are folded.
2. `src/saltests/saltests.cpp`: `TestPackName317` (16 checks) replaced by `TestPackName318`
   (63 checks): 317's carried over (`\t..` now TRUE), trailing dot / space cases, device names in
   every listed form, near misses (`CONSOLE.zip`, `con bla.zip`, `COM10.zip`, `COM.zip`,
   ` CON.zip`, `COM` + C2 B4, `PRN` + superscript, a device name / trailing dot in a folder part,
   a trailing tab), NULL / empty / no last part.
3. `src/fileswn7.cpp` `CFilesWindow::Pack`: the refusal after `SalGetFullName` calls
   `SalPackNameIsNotKeptAsTyped(fileBuf)` - same `IDS_PATHISINVALID` path, the dialog again; the
   comment extended for 318. No new string, no plug-in change.

## Checks after the change

- `.\build.cmd` (Debug x64): BUILD SUCCEEDED, exit 0.
- `saltests.exe`: `saltests: 27503 checks, 0 failed`, exit 0.
- Negative control of the unit checks: `SalPackNameIsNotKeptAsTyped` with the device part replaced
  by `return FALSE` (temporary, restored from a copy, rebuilt): `saltests: 27503 checks, 18 failed`
  - exactly the 18 device-name checks; restored build: 0 failed.
- Probe (`probe/result_after.txt`): **42 PASS / 0 FAIL** (before 30 / 12); registry restored,
  SHA-256 identical. Every refusal row: "The path specified is invalid." in a box titled Pack, the
  dialog again, nothing new, nothing changed; ` ..` the same as before; the 7 controls packed with
  the folder's file; the empty entry "Empty name has no sense here.".
- 317's probe (`probe/regress_317.txt`): 28 PASS / 0 FAIL.
- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`, exit 0.
- clang-format (VS 2022 LLVM): `salpackname.h` clean; the changed lines of `saltests.cpp` and
  `fileswn7.cpp` clean (the files' other differences are pre-existing, lines 1428 / 2003 of
  `fileswn7.cpp`).

Not driven: external archivers (the check runs before any packer - read); typing with a real
keyboard (WM_SETTEXT - the dialog reads the same text); "Use the other panel for packing" on (an
absolute name - the rows abs-trail-dot / abs-dev drive the same branch). No person step is owed.

## Review

One independent refute-first review (general-purpose agent, branch HEAD 3b9a6cf0): **no MUST**,
one SHOULD, four NOTEs.

- Re-ran: build, `saltests: 27503 checks, 0 failed`; the probe 42 / 0, registry identical. Negative
  control of its own: the refusal at `src/fileswn7.cpp` disabled (`nameOk && FALSE && ...`) -> 29
  PASS / 13 FAIL (the 12 rows + ` ..`, created through the ZIP plug-in); restored by hash, rebuilt,
  rows re-checked, `git status` clean.
- SHOULD 1 (fixed): device names are ordinary files on this Windows 11 (`aux.zip`, `CON.zip`, even
  `con` created and opened through plain paths) and the refusal also blocked adding to an existing
  archive: an `aux.zip` made by .NET, Alt+F5 `aux.zip` -> "The path specified is invalid." (before
  318: the "add or overwrite?" question). Fix: refused only when no file of exactly that name
  exists (`!FileExists(fileBuf)` - `\\?\`, no trimming; research R2a); spec FR-007 and
  Clarifications; the wrong premise corrected in the spec's Assumptions (device names are refused
  because the item names them, not because Windows 11 cannot open them).
- NOTE 2 (fixed): a `/` passed the rule (`./CON.zip`, `report./`, `report.zip /`, `sub/CON.zip`
  reached the ZIP plug-in, which refused them itself, nothing created). The rule now starts the last
  part after `\` or `/`; 5 saltests checks.
- NOTE 3 (fixed in the spec): the Edge Case "a folder part must exist" was wrong - the ZIP plug-in
  calls `CheckAndCreateDirectory`; `CON\a.zip`, `newd.\a.zip`, `sub.\a.zip` were refused by ZIP
  ("path not found"), nothing created. No defect, the wording corrected.
- NOTE 4 (fixed by SHOULD 1): an existing archive with a trailing dot or space (e.g. on a Samba
  share) could no longer be added to - now it can (row exist-trail-dot).
- NOTE 5: CHANGELOG / FEATURE-HISTORY entries - written at closing.

### After the review fix

- Control on the first-fix build (`probe/result_fix1.txt`, rows slash-dev, slash-dev-sub,
  trail-dot-plain, exist-aux, exist-trail-dot, ctl-plain): **8 PASS / 4 FAIL** - `./CON.zip` and
  `plain/CON.zip` reached the ZIP plug-in ("Cannot open or create file."), `aux.zip` and `report.`
  with an existing archive refused; trail-dot-plain (`report.` next to a plain file `report`) PASS.
- `.\build.cmd`: BUILD SUCCEEDED, exit 0. `saltests: 27508 checks, 0 failed` (+5 for `/`).
- Probe (`probe/result_after.txt`, overwritten): **52 PASS / 0 FAIL**, registry restored and
  identical: the 12 item rows and ` ..` refused; `./CON.zip`, `plain/CON.zip`, `report.` next to
  `report` refused, `report` unchanged; exist-aux: "The file "aux.zip" already exists..." -> Add,
  `aux.zip` holds seed.txt and f.txt; exist-trail-dot: "The file "report." already exists..." ->
  Add, the same; the controls as before.
- 317's probe (`probe/regress_317.txt`): 28 PASS / 0 FAIL.
- Not driven: Overwrite of an existing `report.` / `aux.zip` (Overwrite's aside, 176) - the same
  route as before 318 for these names; a second review was not run (no MUST).

## Out of scope

Measured, not changed (a scratch copy of the probe with four rows, the branch build, registry
restored and identical): `a*b.zip` and `report.zip<tab>` - the ZIP plug-in's "Cannot access file.
... syntax is incorrect", nothing created. **`report:zip` and `rep:x.zip` - an empty file `report`
/ `rep` created, the archive written into its alternate data stream** (`report:zip.zip`), invisible
to Explorer and the panel. Not this item's (it names trailing dots / spaces and device names) ->
Inbox item `pack-writes-the-archive-into-a-hidden-data-stream-when-its` (measure:318).
