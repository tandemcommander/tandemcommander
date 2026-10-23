# Closing report - 315-unpack-default-whole
Backlog item: unpack-dialog-offers-a-long-target-panel-path-cut-and - Unpack dialog offers a long target panel path cut and unpacks into the cut folder
Outcome: closed

## What changed

- New header-only rule `src/common/salunpackdefault.h`: `SalUnpackDefaultCopy` (whole or empty),
  `SalUnpackDefaultAddSubdir` (path + `\` + archive name whole; else the name alone - a subfolder
  next to the archive - or empty), `SalUnpackEmptyTarget` (an empty target after OK: the archive's
  folder whole, or refused when it - or the subfolder name alone, with the setting - does not fit).
- `CFilesWindow::Unpack` (`src/fileswn7.cpp`): the other panel's path offered whole or left out; the
  subfolder by the rule (never the bare path); a plug-in's unpack mask whole or `*.*`; the empty
  target refused with the existing "The path specified is too long." and the dialog again.
- `saltests` rows (`TestUnpackDefault315`), header in `saltests.vcxproj`.
- No new UI string, no stored data, no plug-in interface change.

## Measurements (before / after, commands)

Probe `probe/unpack315_probe.ps1` on the hidden desktop
(`tools\run_on_hidden_desktop.ps1 ... -File specs\315-unpack-default-whole\probe\unpack315_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe`):

- Before (main 32718c27): `probe/result_before.txt` + `probe/result_before_src.txt` - 6 FAIL
  (other-ascii, other-cjk, alt-ascii, alt-cjk: cut entry, files in a new cut folder or garbage text;
  subdir: bare path, files straight into the other panel; src-long: empty target cut, new cut
  folder); controls ctl, ctl-alt, ctl-subdir PASS.
- After: `probe/result_after.txt` - 11 rows PASS (also longname-sd / longname-sd-ua added after
  review 1), 0 FAIL; registry restored, identical hash.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd` (Debug x64): BUILD SUCCEEDED.
- `saltests.exe`: 27,440 checks, 0 failed. Negative controls: the header made to cut and keep the
  bare path - 8 failed; the subfolder check of `SalUnpackEmptyTarget` removed - 1 failed; restored.
- Probe: 11 / 0 (before 6 FAIL of 9 rows). Feature 299's `unpack299_probe.ps1`: 12 / 0
  (`probe/regress_299.txt`).
- The plug-in mask site is not driven (no plug-in of the tree passes a mask): saltests and reading.

## Reviews (findings and what was done)

One refute-first review (details in `fix-log.md`, *Review*): no MUST. SHOULD 1 (an archive name
too long even alone, with the subfolder setting: the empty entry unpacked without the subfolder) -
fixed (`SalUnpackEmptyTarget`, probe rows, saltests rows). SHOULD 2 (with "Use the other panel" on,
Enter on a long other panel unpacks next to the archive) - accepted, the item's choice ("left out
(an empty / the other default)", "changes least"); the probe now checks the destination. NOTE 3
(leading space of the archive name lost in the subfolder) - Inbox. NOTEs 4-6 recorded / done at
closing.

## Owed to a person (with the new person-step items)

Nothing. The probe drives the dialog by messages (no keyboard needed for this change).

## New Inbox items (slug - title)

- unpack-into-a-subfolder-named-after-an-archive-whose-name - Unpack into a subfolder named after an
  archive whose name starts with a space drops the space
