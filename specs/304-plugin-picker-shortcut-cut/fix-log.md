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
(`SalFolderShortcutTargetU8`, 286). Recorded as the Inbox item
`a-shortcut-whose-target-path-has-260-or-more-characters-is` (measure:304).

## Decisions

- Every `GetPath` answer of MAX_PATH - 1 = 259 units or more is "possibly cut". It is followed
  only when the link's item-list name (`SHGetNameFromIDList(SIGDN_FILESYSPATH)`), in the plain
  form (`\\?\` / `\\?\UNC\` removed), equals the answer or extends it (the answer is its
  prefix) - then the item-list name, plain form, is the result (whole). Anything else is refused
  with the picker's existing "too long" message (`SplShowNameTooLongW`), nothing picked.
- Answers under 259 units: unchanged behaviour.

## Analyze

`speckit-analyze`: 0 CRITICAL, 0 HIGH. MEDIUM C1 (SC-002 names a 250-unit target, T006 did not)
fixed in tasks.md. LOW C2 (FR-006 "no new text / no interface change" has no task of its own)
accepted: the build and the review check it.

## Implementation

`src/plugins/shared/splfiledlg.h`:
- `SplFileDlgDetail::PlainPathAllocW` - the plain form (`\\?\UNC\x` -> `\\x`, `\\?\x` -> `x`).
- `SplFileDlgDetail::WholeFolderShortcutTargetW(answer, listName)` - the pure rule
  (data-model.md): under 259 units the answer as before; 259+ units only when the item-list name
  equals it or extends it (ordinal, case ignored, plain forms) - then the item-list name, plain;
  otherwise NULL = refuse.
- `ResolveNetHoodFolderW(path, BOOL* refused = NULL)` - `GetPath` into 32,768 units on the heap
  (no `WIN32_FIND_DATAW`); for 259+ units `GetIDList` + `SHGetNameFromIDList(SIGDN_FILESYSPATH)`;
  `*refused` TRUE when the target cannot be read whole (also low memory).
- `SplBrowseForFolderU8` - a refused target: `SplShowNameTooLongW` (the existing message),
  nothing picked.

No call site of the plug-ins changed (they call `SplBrowseForFolderU8`); no new UI text; the
plug-in interface untouched.

`src/saltests/saltests.cpp`:
- 121 block: `refused == FALSE` for no desktop.ini / no target.lnk / a short target / UNC.
- `TestFolderShortcutCut304`: the pure rule (every row of data-model.md: short, 259 equal, the
  measured `\\?\D:\` cut, `\\?\UNC\` cut, letter case, other name, shorter item-list name, UNC vs
  drive form, NULL / "" answer, NULL / "" item-list name); end to end with real folder shortcuts
  (item list built folder by folder) whose target has 250 / 259 / 260 / 300 / 400 units in
  `%TEMP%` (C:, 8.3 names) and next to `saltests.exe` (E:, no 8.3 names): the result names the
  target folder by identity (volume serial + file index), in the plain form, whole on a volume
  without 8.3 names - or the pick is refused; 250 and 259 are followed as before. Negative
  control inside: the raw `GetPath` answer on the volume without 8.3 names - cut reproduced 3
  times (260 / 300 / 400).

## Checks

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| build | `.\build.cmd` (PowerShell) | `BUILD SUCCEEDED`, exit 0 (saltests, uncab.spl, pictview.spl, undelete.spl rebuilt) |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 26694 checks, 0 failed`; `saltests 304: 1 volume(s) without 8.3 names tested, GetPath's cut reproduced 3 time(s)` |
| negative control | `WholeFolderShortcutTargetW` made to return every answer as it is (the rule before), rebuilt | `26694 checks, 18 failed` - 9 pure-rule rows and, end to end, 3 x (another folder, `\\?\` form, not whole) for 260 / 300 / 400; restored, rebuilt, 0 failed |

## Measurement after

`probe/measure3.cpp` rebuilt against the fixed header:
- base `D:\Build\tcm_plugpick3c` (no 8.3 names): `ResolveNetHoodFolderW` 259 / 260 / 261 / 300 /
  400 units, **whole 1, exists 1** for all (before: 259 units, cut, does not exist, for 260+).
- base `%TEMP%` (C:, 8.3 names): 259 whole; 260+ the 8.3 form (87 - 107 units), exists - as
  before.
Fixture folders removed (`tcm_plugpick*` on C: and D:); saltests removes its own.

## Not driven (owed to a person)

Picking a network location in the real dialog needs a real mouse (the Browse tree, hidden desktop
has none) and a network location whose target is 260+ characters on a drive without 8.3 names.
Person step: create such a network location (This PC > Add a network location, or a folder
shortcut in `%APPDATA%\Microsoft\Windows\Network Shortcuts` whose target.lnk names the long
folder), then in UnCAB's Browse pick it - the field gets the whole path (its OK then refuses it as
too long, `CB_MAX_CAB_PATH` 256 - UnCAB's own limit); in PictView Save As /
Undelete target Browse - the system message "The filename or extension is too long.", nothing picked.

## Review

### Review 1 (independent agent, refute-first)

No MUST. Re-ran `measure3` against the branch's header: D: 260 / 261 / 300 / 400 whole, C: 8.3
form as before; its own probe tried cuts on a separator, inside a surrogate pair, 255-260 units,
UNC (`\\localhost\D$`), a mapped drive, 1,000-5,000-unit targets on C: and a link without item
list (the shell rebuilds it) - the answer was always cut at exactly 259 units and the result
whole. Callers (PictView `dialogs.cpp:1969`, UnCAB `dialogs.cpp:197`, Undelete `dialogs.cpp:796`
/ `:890`, `fs2.cpp:1522`) write their buffer only on TRUE; none can end with a cut path.

- SHOULD 1: the fix-log promised an Inbox item for the core's `SalShellLinkGetPathU8` that did not
  exist. **Done**: `a-shortcut-whose-target-path-has-260-or-more-characters-is` (measure:304).
- SHOULD 2: the refusal glue (`*refused = TRUE` when the rule refuses) was untested - its negative
  control (`if (FALSE && ...)`) left saltests at 0 failed. **Fixed**: the loaded-link part moved
  into `SplFileDlgDetail::LinkTargetWholeW(IShellLinkW*, BOOL*)` (ResolveNetHoodFolderW calls it);
  saltests drives it with a fake `IShellLinkW` (`CFakeLink304`): a 259-unit answer without item
  list -> refused; with an item list naming another folder -> refused; a short answer -> as before
  without reading the item list; no path (S_FALSE) / GetPath failing -> not refused (the folder
  itself, as before). Negative control repeated: `if (FALSE && result == NULL)` -> `26701 checks,
  3 failed` (the three refusal rows); restored -> 0 failed.
- NOTE 1 (spec over-claimed low memory): spec edge case corrected - only the new target buffer
  refuses; earlier failures keep feature 121's behaviour.
- NOTE 2 (end-to-end proof depends on a volume without 8.3 names): accepted; the glue is now
  covered machine-independently by the fake link, the pure rule by its own checks; saltests prints
  how many such volumes were tested.
- NOTE 3 (UnCAB's OK refuses a path over 256 bytes, `CB_MAX_CAB_PATH`): spec scenario 3 and the
  person step say so.
- NOTE 4 / 5 (the reused "too long" text; case-insensitive prefix compare): accepted as designed.

No second review: review 1 had no MUST finding (SKILL step 7); the change after it is the
extraction of the glue into a function plus tests, checked by the negative control above.

## Checks after the review

| Check | Result |
|---|---|
| `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| `.\build.cmd` | `BUILD SUCCEEDED`, exit 0 |
| saltests | `saltests: 26701 checks, 0 failed`; `saltests 304: 1 volume(s) without 8.3 names tested, GetPath's cut reproduced 3 time(s)` |
