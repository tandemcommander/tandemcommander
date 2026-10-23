# Closing report - 318-pack-name-trailing-dot
Backlog item: pack-archive-name-trailing-dot-or-space - Pack creates an archive with a trailing dot or space Windows tools cannot open
Outcome: closed

## What changed

- `src/common/salpackname.h`: `SalPackNameIsNotKeptAsTyped` (the last part, after the last `\` or
  `/`, ends with `.` or ` `, or is a reserved device name - `SalPackNameIsReservedDevice`: CON, PRN,
  AUX, NUL, COM0-9, LPT0-9, COM/LPT + superscript 1-3, before the first dot, trailing spaces
  ignored, any letter case). It replaces 317's `SalPackNameIsOnlyDotsAndSpaces` (a subset).
- `src/fileswn7.cpp` `CFilesWindow::Pack`: after `SalGetFullName`, such a name is refused through
  317's path ("The path specified is invalid.", the dialog again) unless a file of exactly that name
  already exists (`FileExists`, through `\\?\`, no trimming) - an existing archive is added to or
  overwritten as before.
- `src/saltests/saltests.cpp`: `TestPackName318` (68 checks) replaces `TestPackName317` (16).
- No new UI string, no plug-in or packer change.

## Measurements (before / after, commands)

- Before (efb9b0ad, `probe/result_before.txt`): `pack318_probe.ps1` on the hidden desktop -
  **12 FAIL / 30 PASS**: `report.`, `report.zip..`, `report.zip `, `report. `, `<src>\abs.` created
  literally and not openable through a plain path; `CON.zip`, `con.zip`, `NUL .zip`, `COM1.zip`,
  `lpt9.tar.zip`, `COM<sup1>.zip`, `<src>\prn.zip` created (openable on Windows 11 10.0.26300).
- Control of the review rows on the first fix (`probe/result_fix1.txt`): 8 PASS / 4 FAIL.
- After (`probe/result_after.txt`): **52 PASS / 0 FAIL**, registry restored and identical.
- Command: `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\318-pack-name-trailing-dot\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\318-pack-name-trailing-dot\probe\pack318_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd` (Debug x64): BUILD SUCCEEDED, exit 0.
- `saltests.exe`: `saltests: 27508 checks, 0 failed`; negative control (device part disabled):
  18 failed.
- Probes: 318's 52 / 0; 317's (`probe/regress_317.txt`) 28 / 0.
- clang-format: the changed lines clean.

## Reviews (findings and what was done)

One refute-first review: no MUST. SHOULD 1 (device names are ordinary files on Windows 11; adding
to an existing `aux.zip` was blocked) - fixed: refused only when no such file exists, spec FR-007,
the premise corrected in the spec. NOTE 2 (`/` passed the rule) - fixed. NOTE 3 (wrong spec
statement about folder parts) - corrected. NOTE 4 (existing literal `report.` archives) - fixed by
SHOULD 1. NOTE 5 (CHANGELOG / FEATURE-HISTORY) - written. No second review (no MUST). Details:
`fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

None. Not driven: typing with a real keyboard (the probe uses WM_SETTEXT - the dialog reads the
same text), external archivers (the check runs before any packer), Overwrite of an existing
`aux.zip` / `report.` (the route before 318).

## New Inbox items (slug - title)

- `pack-writes-the-archive-into-a-hidden-data-stream-when-its` - Pack writes the archive into a
  hidden data stream when its name holds a colon (measure:318).
