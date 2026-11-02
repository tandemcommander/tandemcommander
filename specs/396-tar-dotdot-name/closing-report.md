# Closing report - 396-tar-dotdot-name
Backlog item: tar-member-name-with-dotdot-extracted-into-wrong-folder - A tar member whose name contains .. is extracted into a wrong folder
Outcome: closed

## What changed

- `src/common/saltarlink.h`: `SalTarNormalizeNameU8` - the `..` branch removes the whole last
  component of the output (steps back over the trailing `\`, walks back to the previous `\` or the
  start); on an empty output it does nothing (never above the root). The legacy `dst -= 2` /
  `dst++` walk kept the first byte of the dropped component when it was the first one. Comments of
  the file header and the function updated.
- `src/plugins/tar/untar.cpp`: comment only - 309's link rule (a link name with `..` is reported,
  never matched) kept on purpose.
- `src/saltests/saltests.cpp`: 309's pin `TarNorm309("sub/../a.txt")` now `"a.txt"`; new
  `TestTarDotDot396` (15 table checks; brute force over 19,531 names against the legacy loop for
  names without `..` and a reference resolver for all; never longer than the source).
- No UI string, dialog, plug-in interface or setting changed (no `.slt` refresh).

## Measurements (before / after, commands)

Probe `specs/396-tar-dotdot-name/probe/dotdot_probe.ps1` (fixtures `mkdotdot.py`, Python tarfile)
on the hidden desktop (`tools\run_on_hidden_desktop.ps1`, Debug x64):

- before (main 6db68ab0): PASS 7 / FAIL 5 (`result_before.txt`) - `s/a.txt`, `q/f.txt` instead of
  `a.txt`, `f.txt`; an Overwrite question that with Yes replaced the unrelated `s/a.txt`; GNU and PAX
  long names under `s\`; Copy of the listing the same wrong files.
- after: PASS 12 / FAIL 0 (`result_after.txt`) - every file where its name points, no question,
  309's link row unchanged.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s)
- `.\build.cmd` -> BUILD SUCCEEDED
- `saltests.exe` -> 30858 checks, 0 failed (negative control on the legacy rule: 12 failed)
- feature probe 12 / 0; regressions 306 30 / 0, 308 12 / 0, 309 16 / 0, 395 46 / 0
  (`probe/regress_*.txt`)

## Reviews (findings and what was done)

- Review 1: no MUST, no SHOULD. It re-ran the probe (12 / 0) and 309's (16 / 0) and compared
  33,235,296 names of the new header with the legacy loop and its own reference - equal. NOTE 1
  (resolved names can now meet another member's name - the Overwrite question; recorded as a
  limit), NOTE 2 (`z/..` takes 395's report - intended), NOTE 3 (pre-existing misleading WriteFile
  message for a file named `x/y/..` -> Inbox item below), NOTE 4 (link rule kept - as specified),
  NOTE 5 (closing entries - written).

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below (no `## [Unreleased]` section exists in `CHANGELOG.md`; versions
  and sections are the maintainer's):

  - **A TAR member whose name contains `..` was unpacked into a wrong folder, possibly over another file** (feature 396).
    - **Before:** a TAR, cpio or rpm archive member stored under a name such as `sub/../a.txt`
      (rare - GNU tar does not write such names) was listed and unpacked as `s\a.txt`: the first
      letter of the dropped folder survived as a folder of its own. When the archive also held a
      file `s/a.txt`, Unpack asked to overwrite it and with Yes replaced it with the other file's
      data.
    - **Now:** `..` removes the whole folder before it and never leads above the archive's root -
      `sub/../a.txt` is listed and unpacked as `a.txt`, `../../empty` as `empty`. Names without
      `..` are unchanged.
    - **Limitation:** a name resolved this way can be the same as another member's name (`a.txt`
      and `sub/../a.txt`); Unpack then asks to overwrite, as for two members stored under one name.
      A hard link whose target name contains `..` is still reported, not extracted.

No person-step item: every row was driven on the hidden desktop.

## New Inbox items (slug - title)

- `unpack-of-a-tar-file-member-whose-name-ends-in-a-folder-mark` - Unpack of a tar file member
  whose name ends in a folder mark shows a WriteFile error
