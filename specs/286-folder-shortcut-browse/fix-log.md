# Fix log - 286-folder-shortcut-browse

Backlog item `folder-shortcut-browse-result-max-path` - *Folder-shortcut code gets only a MAX_PATH
Browse result*. Autonomous run (`/tandem-backlog-implement`), start at `main` 7537240b.

## Measurement before (7537240b, Debug x64, incremental build current)

Site: `GetTargetDirectory` (`src/shellib.cpp`) = `SHBrowseForFolder` ->
`SalSHGetPathFromIDListU8(res, path, MAX_PATH)` -> `ResolveNetHoodPath(path)`.

Consumers enumerated (Grep):

- `GetTargetDirectory` callers: `dialogs2.cpp` (user-menu Browse), `dialogs5.cpp` (Drives
  "If path is inaccessible go to"), `execute.cpp` (`BrowseDirCommand`), `fileswn0.cpp` /
  `fileswn3.cpp` / `toolbar6.cpp` (change drive > Network, `onlyNet`), `finddlg1.cpp` (Find
  "Look in" browse), `salamdr3.cpp` (archive update copy, Copy/Move/... target menu
  `DIRECTORY_COMMAND_BROWSE`), `zip.cpp` `CSalamanderGeneral::GetTargetDirectory` (plug-ins:
  Automation, FTP, demoplug; converts the result to the code page - frozen by 069). All use
  `path` only when it returns TRUE; several pass the same buffer as `path` and `initDir`.
- `SalSHGetPathFromIDListU8` (static in `shellib.cpp`): `DirectoryBrowse` (OK enabling),
  `GetTargetDirectoryAux`, `GetMyDocumentsOrDesktopPath` (buffer `2 * MAX_PATH`).
- `ResolveNetHoodPath`: only `GetTargetDirectory` (declared in `shellib.h`).
- Plug-in twin (not changed): `src/plugins/shared/splfiledlg.h` `SplFileDlgDetail::IsFolderShortcutIni`
  / `ResolveNetHoodFolderW` (feature 121) for `SplBrowseForFolderU8`.

Probe `probe/fsc286_probe.ps1` (hidden desktop; Configuration > Drives, field 488, browse button
360; the folder selected in the Browse tree by `TVM_EXPAND` / `TVM_SELECTITEM`, OK, field read back):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\286-folder-shortcut-browse\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\286-folder-shortcut-browse\probe\fsc286_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -FixtureBase E:\Projects\tandemcommander\build\probe286 -Label before"
```

- `pick-long` (a folder of 90 CJK letters, 147 units / 327 bytes) **FAIL**: the field received a
  146-byte code-page path ending in `????...` - another, non-existent folder - nothing asked.
- `pick-ctl` (20 CJK letters, fits) PASS: whole.
- `fsc-long`, `fsc-ctl` (a folder shortcut + a plain sibling `zz` in a parent): the tree lists only
  `zz` - **the Browse tree does not list a folder shortcut lying in an ordinary folder**; with the
  shortcut alone the parent had no child at all. `fsc-long-init` (the shortcut as the initial
  folder): OK disabled. So the folder-shortcut branch is reachable only through network locations
  (folder shortcuts in `%APPDATA%\Microsoft\Windows\Network Shortcuts`, shown under This PC /
  Network); this machine has none and the probe does not write into the user's profile -> GUI
  NOT DRIVEN, proven by `saltests`, owed to a person.
- Registry restored and identical (SHA-256 A3805966...).

Folder-shortcut code at HEAD (read): `ResolveNetHoodPath` reads `target.lnk` with
`SalShellLinkGetPathU8(link, tgt, 3 * MAX_PATH)` and follows only when `strlen(tgt) < MAX_PATH`
- a longer target leaves `path` = the shortcut's own folder, silently. Its `name[MAX_PATH]`
buffers make `path + "\desktop.ini"` / `"\target.lnk"` fail for a shortcut folder near the limit
-> silently not recognised. `desktop.ini` id compare was a prefix compare (`{}` matched; 121
noted it for the plug-in twin).

### Probe environment deviation

The first run used `%TEMP%` as the fixture root: every row picked `C:\` - the Browse tree hides
hidden folders when Explorer does (`Hidden=2` on this machine) and `%TEMP%` lies under the hidden
`AppData`. The probe therefore takes `-FixtureBase` - a visible, disposable folder inside the
gitignored build output (`build\probe286`); every typed path starts with the fixture root; the
fixture is deleted at the end.

## Decisions

See spec *Clarifications*: refuse (not follow) a long result - the caller's buffer is `MAX_PATH`
by the plug-in interface's contract; "nothing picked" after the message; OK stays enabled for a
too-long file-system folder; unreadable shortcuts keep the folder as before; no code-page fallback
(also for `GetMyDocumentsOrDesktopPath`, research R2).

## Implementation

- `src/common/salshelllink.h`: `SalIsFolderShortcutIni` (whole class id) and
  `SalFolderShortcutTargetU8` (names on the heap, opened wide / `\\?\`; target read whole into a
  `SAL_MAX_PATH_UTF8` heap buffer; `NOERROR` / `S_FALSE` / `ERROR_FILENAME_EXCED_RANGE`).
- `src/shellib.cpp`: `SalSHGetPathFromIDListU8` - no code-page fallback, `tooLong` out;
  `DirectoryBrowse` keeps OK enabled for a too-long file-system folder; `GetTargetDirectoryAux`
  (now `static`) decodes into a local buffer and writes `path` only on success;
  `ResolveNetHoodPath` returns BOOL (FALSE = target too long) through the header rule;
  `GetTargetDirectory` shows `IDS_TOOLONGPATH` and returns FALSE for both refusals.
- `src/shellib.h`: `BOOL ResolveNetHoodPath`.
- `src/saltests/saltests.cpp`: `TestFolderShortcut286` (45 checks): the pure id test; real
  folder shortcuts in `%TEMP%` - short target, a 90-CJK-letter target (refused at `MAX_PATH`,
  whole with a large buffer), exact limit 259 / 260 bytes, a shortcut folder of 256 bytes
  (+ `\target.lnk` > `MAX_PATH`: recognised), another class / `{}` / no `desktop.ini` / no
  `target.lnk` (S_FALSE), a missing folder, arguments; negative control of the old rule
  (target read fine in `3 * MAX_PATH`, dropped by `strlen < MAX_PATH`).

## Checks after

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` (PowerShell) | `BUILD SUCCEEDED` |
| unit rules | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 25167 checks, 0 failed` (45 new) |
| negative control | `res = S_FALSE` instead of `ERROR_FILENAME_EXCED_RANGE` in the header, rebuilt | `saltests: 25167 checks, 2 failed` - exactly the two "too long" checks (lines of the 90-letter and the 260-byte target); header restored, rebuilt, 0 failed |
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)`, exit 0 |
| probe after | `probe/result_after.txt` (same command, `-Label after`) | `pick-long` **PASS** (one box "The path specified is too long.", field unchanged); `pick-ctl` PASS (whole); `fsc-*` INFO (as before: the tree lists only the sibling / OK disabled); END rows PASS (exit 0, no reports); Rows PASS 7, FAIL 0, NOT DRIVEN 0; registry restored, identical (SHA-256 A3805966...) |

Before -> after: `pick-long` FAIL (146-byte code-page path `????...` accepted) -> PASS (refused).

## Owed to a person (NOT DRIVEN)

- The folder-shortcut route in the GUI: a network location (folder shortcut in
  `%APPDATA%\Microsoft\Windows\Network Shortcuts`) whose target needs more than 259 bytes in
  UTF-8 (e.g. `\\localhost\C$\` + a folder of 90 CJK letters), picked in Configuration > Drives >
  browse (under This PC): expected one "The path specified is too long." and the field unchanged;
  a network location with a short target: the field holds the target. The probe does not write
  into the user's profile.

## Found on the way (out of scope)

- The plug-in twin `SplFileDlgDetail::ResolveNetHoodFolderW` (`src/plugins/shared/splfiledlg.h`,
  feature 121, used by `SplBrowseForFolderU8`) reads a folder shortcut's target with
  `IShellLinkW::GetPath(tgt, MAX_PATH, ...)` into `WCHAR[MAX_PATH]`; feature 194 recorded that
  `GetPath` into `MAX_PATH` units can hand back a cut target - a target of 260+ units would be
  another folder. Not measured here -> Inbox item (`measure:286`).

## Review

Independent refute-first review (general-purpose agent, 2026-10-21): **no MUST findings**. It
re-ran the build, saltests (25167 / 0 failed), the encoding guard (TOTAL 0) and the probe (PASS 7,
FAIL 0, registry identical); its own negative control (`strlen(whole) < targetSize - 1`) failed
exactly the 259-byte exact-limit check; a throw-away check confirmed that `SHGetPathFromIDListW`
of a real folder shortcut gives the shortcut's own folder (so `ResolveNetHoodPath` is live code).

- SHOULD 1 (fixed): on the folder-shortcut refusal `path` already held the shortcut folder
  although FALSE was returned (contract: `path` unchanged) - no caller reads it after FALSE, but
  the plug-in forwarder's buffer changed. Now `GetTargetDirectory` resolves into its own
  `picked[MAX_PATH]` and copies into `path` only on TRUE (`GetTargetDirectoryAux` writes into that
  buffer directly). Re-checked: build OK, saltests 25167 / 0 failed, encoding TOTAL 0, probe after
  PASS 7 / FAIL 0 (pick-long PASS, pick-ctl PASS), registry identical.
- SHOULD 2 (out of scope -> Inbox `my-documents-drive-opens-a-cut-path-when-documents-needs`):
  `GetMyDocumentsOrDesktopPath` cuts a Documents path to the caller's `MAX_PATH` with `lstrcpyn`.
- SHOULD 3 (recorded): the wiring "`ResolveNetHoodPath` FALSE -> message + FALSE" has no automated
  check (the rule has; the GUI route cannot be driven without the user's profile) - verified by
  code reading; the GUI confirmation is the person-step item.
- NOTE 4: the Inbox item for the plug-in twin - added (`plug-in-folder-picker-may-cut-a-folder-shortcut-target-of`).
- NOTE 5: a folder of 260+ UTF-16 units stays unpickable with OK disabled (older; spec Assumptions).
- NOTE 6 (older, recorded only): `DirectoryBrowse` passes the UTF-8 initial folder to the `A`
  `BFFM_SETSELECTION` - an initial folder with letters outside ASCII is not preselected; no data
  risk.
- NOTE 7 (fixed): the test's early return on low memory now removes its folder and uninitialises COM.
- NOTE 8 (fixed): the comment "never silently the shortcut folder itself" overstated - an unreadable
  target still keeps the folder (spec Clarification); comment corrected.

A second review was not required (no MUST findings).
