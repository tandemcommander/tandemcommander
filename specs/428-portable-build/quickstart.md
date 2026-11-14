# Quickstart: validating the portable build (feature 428)

How to prove the feature works end to end. Details of behaviour are in [contracts/](contracts/)
and [data-model.md](data-model.md); this guide only says what to run and what must come out.
GUI rows run on the hidden desktop (`tools/run_on_hidden_desktop.ps1`); every probe backs up and
restores `HKCU\Software\Tandem Commander` (the installed edition's key must come out **unchanged**
— that is itself a check). Probes live in `specs/428-portable-build/probe/`.

## Prerequisites

- The normal prerequisites of `build.cmd` (VS 2022, Python).
- For `dist` and signed rows: `tools\codesign\codesign.cfg` and the certificate (the maintainer's
  machine).
- An installed Tandem Commander (any 0.3.x) for the side-by-side rows.

## 1. Build

```batch
build.cmd portable                       :: Debug portable -> build\tandemcommander\Debug_x64_portable\
build.cmd full release portable          :: Release portable + setup\output\tandemcommander-<ver>-x64-portable.zip
build.cmd release portable               :: must fail before any work (no 'full')
build.cmd full release portable setup    :: must fail before any work
build.cmd dist                           :: maintainer: signed installer + signed ZIP, summary with SHA-256
```

Expected: the normal `Debug_x64\` / `Release_x64\` trees are byte-for-byte unchanged by a portable
build (compare a file-hash list before / after); `make_portable_zip.py` refuses a normal-edition
exe; the ZIP has one top folder and the contents of
[contracts/package-layout.md](contracts/package-layout.md).

## 2. Unit and gate tests

```batch
build\tandemcommander\Debug_x64\saltests.exe     :: new groups: TestPortable428 (scope, names, relativize/expand, start decision), update-check portable asset
python specs\428-portable-build\probe\roundtrip_gate.py   :: real config hive -> dump -> parse -> compare: 0 differences
```

## 3. No traces (SC-002, US1)

`probe\notrace_probe.ps1`: snapshot (HKCU, readable HKLM, HKCR — minus the documented Windows
bookkeeping list; `%APPDATA%`, `%LOCALAPPDATA%` minus `Temp`), unpack the ZIP into a fixture folder,
start the portable program, drive every Configuration page and the enabled plug-ins' settings,
open a text file in the code viewer and a `.md` in the Markdown viewer, close; snapshot again.

Expected: 0 differences attributable to the program; `%TEMP%\TandemCommander-portable-*` gone
after exit; `settings\tandemcommander.reg` present, a second start shows the changes; the
installed edition's key unchanged.

## 4. Carry it along (SC-003, US2)

`probe\move_probe.ps1`: configure (including a user-menu item and a hot path to a tool inside the
portable folder, an FTP bookmark, a saved password with a master password), close, copy the folder
to another path and expose it as another drive letter (`subst`), start from there.

Expected: every checked setting present; the user-menu item and hot path point into the new
location; the file contains `$(PortableDir)` instead of the old folder; the password opens with the
master password.

## 5. Failure handling (SC-006, US6)

- Kill the program at random moments of a save (20 runs): `tandemcommander.reg` always parses;
  the next start has the last complete settings.
- Deny write on the portable folder (a deny ACE for the test user): the program starts with the
  saved settings, shows `IDS_PORTABLE_CANNOTSAVE` once, no second message at exit, nothing written
  anywhere else.
- Corrupt `tandemcommander.reg`: the `.bak` is used with a note; corrupt both: renamed
  `.damaged-<UTC>`, defaults, note.

## 6. Side by side (SC-007, FR-011a)

Installed and portable running at once, *Only one instance* on in both: starting each activates
only its own copy; 10 settings changed in each never appear in the other; two portable copies in
different folders likewise; two windows of the same portable folder share settings.

## 7. Identity (US4, SC-008)

Title `Tandem Commander <ver> [portable]` (and `… [portable] (Administrator)` elevated) in all 8
languages; About shows "Portable edition" and the `settings` link, the link opens the folder in the
active panel; the exe and the window carry the badge icon; installed and portable are separate
taskbar groups; the normal edition's title and About are unchanged.

## 8. Update check (US5)

With 123's Debug seam (`TC_UPDATECHECK_URL` to the fixture server): a release with the portable
ZIP → notification with the page link only; a release without it → nothing; Configuration >
General shows only the check box; no file appears in `%LOCALAPPDATA%`.

## 9. Explorer integration and passwords

Drag a file from a ZIP panel to an Explorer window → `IDS_PORTABLE_NOSHELLEXT`; disk-to-Explorer
drag still works. First password saved without a master password → the note; "Do not show this
again" holds across a restart.

## Owed to a person (release checklist line)

Real FAT32 and exFAT USB sticks on two PCs with different drive letters; a ZIP downloaded with a
browser (Mark of the Web, SmartScreen with the signed build); the badge icon on a real taskbar in
Light and Dark; real drag and drop to Explorer (the message).
