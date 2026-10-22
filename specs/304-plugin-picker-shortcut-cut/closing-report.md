# Closing report - 304-plugin-picker-shortcut-cut
Backlog item: plug-in-folder-picker-may-cut-a-folder-shortcut-target-of - Plug-in folder picker may cut a folder shortcut target of 260 or more units
Outcome: closed

## What changed

- `src/plugins/shared/splfiledlg.h` (header-only, compiled into PictView, UnCAB, Undelete and
  saltests):
  - `SplFileDlgDetail::PlainPathAllocW` - `\\?\UNC\x` -> `\\x`, `\\?\x` -> `x`.
  - `SplFileDlgDetail::WholeFolderShortcutTargetW(answer, listName)` - the pure rule: an answer
    under 259 units as before; 259+ units only when the link's item-list name equals it or the
    answer begins the longer name (ordinal, case ignored, plain forms) - then the item-list name;
    otherwise NULL = refuse.
  - `SplFileDlgDetail::LinkTargetWholeW(link, &refused)` - `GetPath(SLGP_UNCPRIORITY)` into
    32,768 units on the heap; for 259+ units `GetIDList` + `SHGetNameFromIDList(SIGDN_FILESYSPATH)`;
    refused when not proven whole (also low memory for that buffer).
  - `ResolveNetHoodFolderW(path, BOOL* refused = NULL)` - uses it; `SplBrowseForFolderU8` shows the
    existing `SplShowNameTooLongW` message on a refusal and picks nothing.
- `src/saltests/saltests.cpp`: `refused == FALSE` assertions in the 121 block;
  `TestFolderShortcutCut304` - the pure rule, the link part with a fake `IShellLinkW`, and real
  folder shortcuts (item list built folder by folder) with targets of 250 / 259 / 260 / 300 / 400
  units in `%TEMP%` and next to `saltests.exe`.
- No plug-in call site, UI string or plug-in interface changed.

## Measurements (before / after, commands)

`probe/measure3.cpp` (`cl /nologo /EHsc /std:c++latest /utf-8 /I src\plugins\shared /I src\common
measure3.cpp ole32.lib shell32.lib user32.lib`, vcvars64), run with a base folder:
- D:\Build (no 8.3 names): before - `GetPath` NOERROR, 259 units, cut, `ResolveNetHoodFolderW`
  returns the cut path (does not exist) for 260 / 261 / 300 / 400 units (4 of 4 cut); after -
  whole 260 / 261 / 300 / 400 units, exists (0 of 4 cut). 259 units whole before and after.
- %TEMP% (C:, 8.3 names): the 8.3 form (the same folder) before and after.
`measure.cpp` / `measure2.cpp`: `SetPath` refuses 260+ units; `SHParseDisplayName` of a long path
gives the 8.3 form (why the test builds the item list folder by folder).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` - `TOTAL: 0 finding(s)`.
- `.\build.cmd` (Debug x64) - `BUILD SUCCEEDED`, exit 0.
- saltests - `saltests: 26701 checks, 0 failed`; `saltests 304: 1 volume(s) without 8.3 names
  tested, GetPath's cut reproduced 3 time(s)`.
- Negative controls: the rule taking every answer as it is - 18 failed; the refusal flag never set
  - 3 failed; both restored - 0 failed.
- GUI probe: none - the Browse tree needs a real mouse (NOT DRIVEN, person step below).

## Reviews (findings and what was done)

One independent refute-first review: no MUST.
- SHOULD 1 (promised Inbox item missing) - added
  `a-shortcut-whose-target-path-has-260-or-more-characters-is`.
- SHOULD 2 (refusal glue untested) - `LinkTargetWholeW` extracted, driven by a fake link; negative
  control 3 failed.
- NOTE 1 / 3 - spec corrected (low memory scope; UnCAB's own 256-byte limit); NOTE 2 / 4 / 5
  accepted (fix-log *Review*).

## Owed to a person (with the new person-step items)

- `check-the-plug-in-folder-picker-with-a-long-target-network` - pick a long-target network
  location in UnCAB / PictView / Undelete in the real dialog.

## New Inbox items (slug - title)

- `a-shortcut-whose-target-path-has-260-or-more-characters-is` - A shortcut whose target path has
  260 or more characters is followed to a cut path (measure:304).
- `check-the-plug-in-folder-picker-with-a-long-target-network` - Check the plug-in folder picker
  with a long-target network location (leftover:304, person step).
