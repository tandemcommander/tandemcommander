---
title: Check a drop onto a long-target shortcut and Browse on a long network location
type: person-step
status: open
severity: 4
area: long-paths
source: leftover:305
who: person
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: S
feature: -
related: [check-the-plug-in-folder-picker-with-a-long-target-network]
depends-on: []
reason: -
---

# Check a drop onto a long-target shortcut and Browse on a long network location

## Problem

Feature 305 made the core's shortcut reader (`SalShellLinkGetPathU8`) return the whole target of a
shortcut whose target has 260 or more characters on a volume without 8.3 names, or refuse it -
never the 259-character cut the shell answers. Enter and Go to Shortcut Target were driven on the
hidden desktop (probe PASS 10); two routes need a real mouse and were not: a file dropped onto such
a shortcut in a panel, and Browse For Folder on a network location with such a target.

## Evidence

`specs/305-core-shortcut-target-cut/fix-log.md`, *Not driven (owed to a person)*. The link writer:
`specs/305-core-shortcut-target-cut/probe/mklnk305.cpp` (build:
`cl /nologo /EHsc /std:c++latest /utf-8 mklnk305.cpp ole32.lib shell32.lib` in a vcvars64 prompt;
usage `mklnk305.exe <lnk> <base> <part> [<part> ...]` - writes a `.lnk` whose item list names
`<base>\<part>\...`, every folder must exist). `lnk305_probe.ps1` (`Make-Target`) shows how the
probe builds a 300-character target with a 259-character parent.

## Expected

Every step below passes on a Debug or Release build of feature 305 or later.

## Steps

- [ ] Preparation: on a drive without 8.3 names (e.g. `D:` or the build folder's drive; `C:`
      usually has them and the cut does not happen there) make a folder `D:\tc305p`, in it a chain
      of folders whose full path is 259 characters (`P`), and in `P` a folder `zzz...` so that the
      whole target `T` has 300 characters. Write `D:\tc305p\go.lnk` with `mklnk305.exe` naming `T`.
- [ ] Drop: open `D:\tc305p` in a panel, drag a small file from the other panel onto `go.lnk` and
      drop it (Copy) -> the copy confirmation names `T` (300 characters, ending in `zzz...`), and
      after OK the file is in `T`, not in its parent `P` (before feature 305 it went to `P`).
- [ ] Browse: copy a network location folder (a folder with the folder-shortcut `desktop.ini` and
      a `target.lnk` naming `T` - `measure_core.cpp` of the same folder writes one as `sc`) into
      `%APPDATA%\Microsoft\Windows\Network Shortcuts`; F5 (Copy) > Browse..., pick it under This
      PC > Network locations -> "The path specified is too long." and the target field keeps its
      previous text (never the 259-character cut, never the shortcut folder itself).
- [ ] Control: the same two steps with a 250-character target -> the drop lands in the target,
      Browse fills the field with it.
- [ ] Clean-up: delete the network location from `Network Shortcuts` and the folder `D:\tc305p`
      (Shift+Del in the program handles the long names).

## Log

- 2026-10-22 — created (source leftover:305)
- 2026-10-22 — moved to Person steps position 20
