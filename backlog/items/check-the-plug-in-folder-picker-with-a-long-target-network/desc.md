---
title: Check the plug-in folder picker with a long-target network location
type: person-step
status: open
severity: 4
area: other-plugins
source: leftover:304
who: person
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Check the plug-in folder picker with a long-target network location

## Problem

Feature 304 made the plug-ins' folder picker (PictView, UnCAB, Undelete) follow a picked network
location whose target has 260 or more characters whole, or refuse it - never a cut path. The rule
and the link reading are proven by saltests with real folder shortcuts, but picking such a network
location in the real Browse dialog needs a real mouse, which the hidden desktop does not have.

## Evidence

`specs/304-plugin-picker-shortcut-cut/fix-log.md`, *Not driven (owed to a person)*;
`specs/304-plugin-picker-shortcut-cut/quickstart.md` step 4. The fixture program:
`specs/304-plugin-picker-shortcut-cut/probe/measure3.cpp` (writes a folder shortcut `sc` whose
`target.lnk` names targets of 259-400 characters; the last one written stays: 400 characters).

## Expected

Every step below passes on a Debug or Release build of feature 304 or later.

## Steps

- [ ] Preparation: build `measure3.cpp` (see the fix-log, *Measurement before*) and run it with a
      base folder on a drive without 8.3 names, e.g. `measure3.exe D:\Build\tc304` - it leaves
      `D:\Build\tc304\sc` (desktop.ini + target.lnk pointing at a 400-character folder). Copy the
      folder `sc` into `%APPDATA%\Microsoft\Windows\Network Shortcuts` (it then shows under
      This PC > Network locations in the Browse tree).
- [ ] UnCAB: open a `.cab`, start the unpack dialog, Browse, pick the network location `sc` ->
      the field shows the whole 400-character path (not 259 characters, not ending in the middle of
      a name, no `\\?\`); OK then refuses it as too long (UnCAB's own 256-byte limit).
- [ ] PictView: Save As > Browse folder, pick `sc` -> the system message "The filename or
      extension is too long."; nothing is put into the field.
- [ ] Undelete: the target-folder Browse of a restore, pick `sc` -> the same message; the
      previous target stays.
- [ ] Control: a network location to a short folder (Explorer > Add a network location) is
      still followed to its target in all three plug-ins.
- [ ] Clean-up: delete `sc` from `Network Shortcuts` and the base folder (`D:\Build\tc304`).

## Log

- 2026-10-22 — created (source leftover:304)
- 2026-10-22 — moved to Person steps position 19
