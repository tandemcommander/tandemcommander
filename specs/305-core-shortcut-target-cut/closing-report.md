# Closing report - 305-core-shortcut-target-cut
Backlog item: a-shortcut-whose-target-path-has-260-or-more-characters-is - A shortcut whose target path has 260 or more characters is followed to a cut path
Outcome: closed

## What changed

- `src/common/salshelllink.h`:
  - new `SalPlainPathAllocW` and `SalShellLinkWholeTargetW` (pure rule, the core twin of feature
    304's `WholeFolderShortcutTargetW`);
  - `SalShellLinkGetPathU8`: a GetPath answer of 259+ units is returned only when the link's item
    list (`GetIDList` + `SHGetNameFromIDList(SIGDN_FILESYSPATH)`) proves it whole - then the whole
    name in the plain form; otherwise `HRESULT_FROM_WIN32(ERROR_FILENAME_EXCED_RANGE)`;
    `SLGP_RAWPATH` 259+ always refused; shorter answers unchanged (item list not read);
  - new `SalFolderShortcutLinkTargetU8` (the loaded `target.lnk` part of
    `SalFolderShortcutTargetU8`), which passes the refusal on as its "too long" result - Browse
    For Folder refuses instead of silently picking the shortcut folder.
- No call site changed (`fileswn0.cpp` Go to Shortcut Target, `fileswn2.cpp` Enter,
  `shellsup.cpp` drop, `shellib.cpp` Browse); no UI text; plug-ins untouched.
- `src/saltests/saltests.cpp`: `TestShellLinkWholeTarget305`.
- Probe: `probe/lnk305_probe.ps1` + `probe/mklnk305.cpp`; measurement `probe/measure_core.cpp`.

## Measurements (before / after, commands)

- `probe/measure_core.cpp` (`cl /nologo /EHsc /std:c++latest /utf-8 /I src\common ...`), base on
  D: (no 8.3 names): before 260 / 261 / 300 / 400 units -> NOERROR, 259 units cut, not existing
  (UNCPRIORITY, RAWPATH, `SalFolderShortcutTargetU8`); after -> whole and existing, RAWPATH 259+
  refused. C: (8.3 names): 8.3 form before and after.
- GUI probe on the hidden desktop
  (`tools\run_on_hidden_desktop.ps1 ... lnk305_probe.ps1 -Exe build\...\tandemcommander.exe -MkLnk mklnk305.exe`,
  fixture `build\tc305` on E:): before PASS 6 / FAIL 4 (ENTER-300 / FOCUS-300 error message,
  ENTER-SEP / FOCUS-SEP silently the parent folder); after PASS 10 / FAIL 0. Registry restored,
  identical both times.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd`: `BUILD SUCCEEDED`.
- saltests: `27046 checks, 0 failed`; `saltests 305: 1 volume(s) without 8.3 names tested,
  GetPath's cut reproduced 8 time(s)`.
- Negative controls: the rule returning the answer as it is -> 84 failed; the raw-path refusal
  removed -> 13 failed; the refusal pass-through in the folder-shortcut part removed -> 3 failed;
  each restored, 0 failed.
- Probe: PASS 10, FAIL 0, NOT DRIVEN 0 (re-run on the final code).

## Reviews (findings and what was done)

One independent refute-first review: no MUST. SHOULD 1 (the folder-shortcut refusal pass-through
untested) fixed - extracted `SalFolderShortcutLinkTargetU8`, driven by a fake link, negative
control 3 fails. SHOULD 2 (a whole UNC answer of exactly 259 units on a mapped drive is now
refused) accepted as fail-closed and recorded in the spec and the changelog. NOTEs: the unanchored
prefix proof (same as 304, accepted), RAWPATH 259 (recorded), the Network plug-in's own cut (new
Inbox item), quickstart count (fixed). Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- `check-a-drop-onto-a-long-target-shortcut-and-browse-on-a` - a drop onto a long-target shortcut
  and Browse on a long network location in the real UI (needs a real mouse).

## New Inbox items (slug - title)

- `network-plug-in-follows-a-network-shortcut-to-a-cut-target` - Network plug-in follows a network
  shortcut to a cut target of 260 or more units (review:305).
- `check-a-drop-onto-a-long-target-shortcut-and-browse-on-a` - Check a drop onto a long-target
  shortcut and Browse on a long network location (leftover:305, person step).
