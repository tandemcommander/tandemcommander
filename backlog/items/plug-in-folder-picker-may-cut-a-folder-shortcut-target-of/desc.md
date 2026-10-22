---
title: Plug-in folder picker may cut a folder shortcut target of 260 or more units
type: bug
status: in-progress
severity: 5
area: other-plugins
source: measure:286
who: agent
created: 2026-10-21
updated: 2026-10-22
verified: 2026-10-22 3fa858bb
effort: S
feature: 304
related: []
depends-on: []
reason: -
---

# Plug-in folder picker may cut a folder shortcut target of 260 or more units

## Problem

The plug-ins' folder picker `SplBrowseForFolderU8` (`src/plugins/shared/splfiledlg.h`, feature
121; used by PictView, UnCAB, Undelete) follows a picked folder shortcut (a network location)
through `SplFileDlgDetail::ResolveNetHoodFolderW`, which reads the target with
`IShellLinkW::GetPath(tgt, MAX_PATH, ...)` into `WCHAR tgt[MAX_PATH]`. Feature 194 recorded that
`GetPath` into `MAX_PATH` units can hand back a **cut** target - another folder; a plug-in would
then restore / extract into it. The core's equivalent was fixed by features 194 / 286
(`SalShellLinkGetPathU8` reads into 32,768 units; `SalFolderShortcutTargetU8` refuses a target that
does not fit).

## Evidence

Found while enumerating the consumers in feature 286 (`specs/286-folder-shortcut-browse/fix-log.md`,
*Found on the way*), code at 547839c5: `src/plugins/shared/splfiledlg.h`
`ResolveNetHoodFolderW` - `WCHAR tgt[MAX_PATH]`, `link->GetPath(tgt, MAX_PATH, &data, SLGP_UNCPRIORITY)`;
called from `SplBrowseForFolderU8`. The truncating behaviour of `GetPath` is from the comment of
feature 194 in `src/shellib.cpp` / `src/common/salshelllink.h`; **not measured** here.

## Expected

A folder shortcut whose target has 260 or more UTF-16 units is followed whole (a 32,768-unit
buffer) or refused - never cut. Then the plug-in's own `MAX_PATH` / UTF-8 limit applies as for any
picked folder.

## Notes

Measure first: write a folder shortcut whose `target.lnk` names a target of 300 units (written with
`IShellLinkW`, as `saltests` `TestFolderShortcut286` does) and call `ResolveNetHoodFolderW` on it -
does `GetPath` return a cut path with `NOERROR`, or fail? Reachable only through a network location
in the user's profile (the Browse tree does not list a folder shortcut inside an ordinary folder,
feature 286 R4).

## Log

- 2026-10-21 — created (source measure:286)
- 2026-10-21 — no relation intended
- 2026-10-21 — moved to Next position 10
- 2026-10-22 — verified at 3fa858bb: reproduced at 3fa858bb: standalone program on D: (no 8.3 names), target.lnk by ID list to a 260-400 unit folder: GetPath NOERROR, 259 units, cut; ResolveNetHoodFolderW returns the cut path
- 2026-10-22 — run started, feature 304
