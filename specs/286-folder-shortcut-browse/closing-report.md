# Closing report - 286-folder-shortcut-browse
Backlog item: folder-shortcut-browse-result-max-path - Folder-shortcut code gets only a MAX_PATH Browse result
Outcome: closed

## What changed

- `src/shellib.cpp`: the Browse For Folder routine (`GetTargetDirectory`) hands back a picked
  folder whole or refuses it. `SalSHGetPathFromIDListU8` no longer falls back to the code-page
  `SHGetPathFromIDList` (it reports "too long"); the Browse dialog keeps OK enabled for such a
  folder; `GetTargetDirectory` resolves into its own buffer, shows "The path specified is too
  long." and returns FALSE (nothing picked, `path` unchanged) for a folder - or a folder
  shortcut's target - that does not fit `MAX_PATH` bytes. `ResolveNetHoodPath` returns BOOL and
  uses the header rule. `src/shellib.h`: its declaration.
- `src/common/salshelllink.h`: `SalIsFolderShortcutIni` (whole class id) and
  `SalFolderShortcutTargetU8` (names on the heap, opened wide / `\\?\`; target read whole; NOERROR /
  S_FALSE / "too long").
- `src/saltests/saltests.cpp`: `TestFolderShortcut286` (45 checks, real folder shortcuts).
- Plug-in interface unchanged (`GetTargetDirectory`, `MAX_PATH`, code-page result for plug-ins).

## Measurements (before / after, commands)

Probe `probe/fsc286_probe.ps1` on the hidden desktop (Configuration > Drives > browse button, the
folder picked in the tree, OK, field read back):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\286-folder-shortcut-browse\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\286-folder-shortcut-browse\probe\fsc286_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -FixtureBase E:\Projects\tandemcommander\build\probe286 -Label <label>"
```

| Row | Before (7537240b) | After |
|---|---|---|
| pick-long (90 CJK letters, 327 bytes) | FAIL - a 146-byte code-page path `????...` accepted | PASS - "The path specified is too long.", field unchanged |
| pick-ctl (20 CJK letters) | PASS - whole | PASS - whole |
| fsc-long / fsc-ctl / fsc-long-init | the tree lists only the plain sibling / OK disabled | INFO, the same (folder shortcuts are not listed inside ordinary folders) |

The folder-shortcut rule: `saltests` `TestFolderShortcut286` - a 90-letter target refused at
`MAX_PATH` and whole with a large buffer, 259 / 260-byte exact limit, a 256-byte shortcut folder
recognised, not-a-shortcut cases S_FALSE; negative control of the old rule (target dropped
silently). Fixture base `build\probe286`: the Browse tree hides the hidden AppData folder holding
`%TEMP%` (fix-log *Probe environment deviation*).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd` (Debug x64): `BUILD SUCCEEDED`.
- `saltests.exe`: `saltests: 25167 checks, 0 failed` (45 new); negative control
  (`S_FALSE` instead of "too long"): 2 failed - exactly the two "too long" checks; restored.
- Probe after: Rows PASS 7, FAIL 0, NOT DRIVEN 0 (+3 INFO); registry restored and identical
  (SHA-256 A3805966...).

## Reviews (findings and what was done)

One independent refute-first review: no MUST. SHOULD 1 (`path` changed on the folder-shortcut
refusal) fixed and re-checked; SHOULD 2 (`GetMyDocumentsOrDesktopPath` cuts a Documents path) ->
Inbox; SHOULD 3 (the refusal wiring has no automated check; verified by code reading, GUI owed to a
person) recorded; NOTE 7 / 8 fixed; NOTE 4 -> Inbox; NOTE 5 / 6 recorded (older). Details:
`fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

- `confirm-a-network-location-with-a-long-target-is-refused-in` - a real network location with a
  long target picked in the Browse dialog is refused; a short one is followed.

## New Inbox items (slug - title)

- `my-documents-drive-opens-a-cut-path-when-documents-needs` - My Documents drive opens a cut path when Documents needs more than 259 bytes
- `plug-in-folder-picker-may-cut-a-folder-shortcut-target-of` - Plug-in folder picker may cut a folder shortcut target of 260 or more units
- `confirm-a-network-location-with-a-long-target-is-refused-in` - Confirm a network location with a long target is refused in Browse
