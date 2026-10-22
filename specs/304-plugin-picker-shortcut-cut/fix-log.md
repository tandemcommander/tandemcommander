# Fix log: 304 - the plug-in folder picker never cuts a folder shortcut's target

Backlog item `plug-in-folder-picker-may-cut-a-folder-shortcut-target-of` (source measure:286).

## Measurement before (main at 3fa858bb)

Standalone programs, built with `cl /EHsc /std:c++latest /utf-8 /I src\plugins\shared
/I src\common` (vcvars64) and run from the run's scratch folder; copies in `probe/`:

- `measure.cpp` - the item's suggestion (a 351-unit target written with `IShellLinkW::SetPath`):
  `SetPath` = `0x80004005` (E_FAIL); the saved link has no path, `GetPath` = S_FALSE, "",
  `ResolveNetHoodFolderW` = NULL. **The item's suggested way cannot write such a link** (also
  `TestFolderShortcut286`'s way).
- `measure2.cpp` - targets of 250 / 259 / 260 / 261 / 300 units, written four ways:
  `SetPath(path)` works up to 259 units, E_FAIL from 260; `SetPath(\\?\path)` E_INVALIDARG /
  E_FAIL always; `SHParseDisplayName(path)` + `SetIDList` works but the item list is the 8.3 form
  (`GetPath` 87-90 units); `SHParseDisplayName(\\?\path)` E_INVALIDARG.
- `measure3.cpp <base>` - the item list built folder by folder (`IShellFolder::ParseDisplayName`
  per component, `ILCombine`) + `SetIDList`; `SHGetNameFromIDList(SIGDN_DESKTOPABSOLUTEPARSING)`
  of it = the whole name (`\\?\` + 260..400 units).
  - base `%TEMP%` (C:, 8.3 names generated): `GetPath` NOERROR with the 8.3 form (87 / 87 / 90 /
    108 units) - the same folder; `ResolveNetHoodFolderW` returns that, it exists. Not cut.
  - base `D:\Build\tcm_plugpick3` (D:, no 8.3 names; E: and F: likewise): for 260, 261, 300, 400
    units `GetPath` = **NOERROR, exactly 259 units, `\\?\D:\Build\...` cut in the middle of the
    last name**, with a `MAX_PATH` buffer AND with a 32,768-unit buffer.
    `ResolveNetHoodFolderW` returns that cut path (it does not exist; a cut that falls on a
    backslash would name the existing parent folder). 259 units: whole.

**Defect confirmed** (`BL verify`). Reachable: a network location (NetHood folder shortcut)
whose `target.lnk` names a long target on a drive without 8.3 names, picked in PictView
(Save As > Browse folder, 260-byte buffer), UnCAB (Browse, 780-byte buffer - a cut ASCII path
fits and is taken), Undelete (temp folder, target folder - 260 bytes).

A 32,768-unit buffer alone (the item's *Expected* hint) does **not** fix it: the shell cuts
before copying into the caller's buffer.

## Found on the way (out of scope)

The core's `SalShellLinkGetPathU8` (`src/common/salshelllink.h`, 32,768 units) receives the same
cut answer with NOERROR: Enter on a shortcut / Go to Shortcut Target (`fileswn0.cpp`,
`fileswn2.cpp`), drop onto a shortcut (`shellsup.cpp`, 194), folder-shortcut Browse
(`SalFolderShortcutTargetU8`, 286). Recorded as an Inbox item (measure:304).

## Decisions

- Every `GetPath` answer of MAX_PATH - 1 = 259 units or more is "possibly cut". It is followed
  only when the link's item-list name (`SHGetNameFromIDList(SIGDN_FILESYSPATH)`), in the plain
  form (`\\?\` / `\\?\UNC\` removed), equals the answer or extends it (the answer is its
  prefix) - then the item-list name, plain form, is the result (whole). Anything else is refused
  with the picker's existing "too long" message (`SplShowNameTooLongW`), nothing picked.
- Answers under 259 units: unchanged behaviour.
