---
title: A shortcut whose target path has 260 or more characters is followed to a cut path
type: bug
status: new
severity: 6
area: long-paths
source: measure:304
who: agent
created: 2026-10-22
updated: 2026-10-22
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# A shortcut whose target path has 260 or more characters is followed to a cut path

## Problem

When a shortcut (`.lnk`) points at a folder or file whose path has 260 or more characters on a
volume without 8.3 short names, the core follows it to a CUT path - the first 259 characters, in
the `\\?\` form, usually ending in the middle of a name. Enter on such a shortcut or *Go to
Shortcut Target* then fails or, when the cut falls on a backslash, opens the parent folder; a
file dropped onto the shortcut goes to that other folder (or fails); Browse For Folder on such a
network location (feature 286) takes the cut path. The core's `SalShellLinkGetPathU8` reads the
target into 32,768 units and trusts the shell's NOERROR - but the shell itself cuts the answer.

## Evidence

Measured in feature 304 (`specs/304-plugin-picker-shortcut-cut/fix-log.md`, *Measurement before*
and *Found on the way*; programs `specs/304-plugin-picker-shortcut-cut/probe/measure3.cpp`), on
Windows 11 10.0.26300 at 3fa858bb: a `.lnk` written with `SetIDList` from an item list built
folder by folder (`SetPath` refuses 260+ units) to a target of 260 / 261 / 300 / 400 units on
D: (no 8.3 names): `IShellLinkW::GetPath(SLGP_UNCPRIORITY)` answers NOERROR with exactly 259
units (`\\?\D:\Build\...` cut mid-name) with a 260-unit AND with a 32,768-unit buffer. On C:
(8.3 names) it answers the 8.3 form (the same folder, whole).
`SHGetNameFromIDList(SIGDN_FILESYSPATH)` of the link's item list gives the whole name.

Consumers at f64fde96 (all through `src/common/salshelllink.h` `SalShellLinkGetPathU8`, line 38,
which only checks NOERROR and the UTF-8 fit):
- `src/fileswn0.cpp:898` / `:909` - Enter on a shortcut;
- `src/fileswn2.cpp:190` / `:202` / `:223` - Go to Shortcut Target;
- `src/shellsup.cpp:584` - a drop onto a shortcut (`GetCurrentDir`, feature 194);
- `src/common/salshelllink.h:187` - `SalFolderShortcutTargetU8` (Browse For Folder, feature 286).

The plug-ins' twin (`src/plugins/shared/splfiledlg.h` `LinkTargetWholeW` /
`WholeFolderShortcutTargetW`) was fixed by feature 304 the same way the core could be.

## Expected

`SalShellLinkGetPathU8` never returns a cut target: an answer of MAX_PATH - 1 units or more is
followed only when the link's item list proves it whole (equal, or the answer is the beginning
of the longer item-list name - then the whole name in the plain form); otherwise it fails (the
callers' existing "too long" / "not a valid shortcut" handling). saltests checks with a real
long-target shortcut on a volume without 8.3 names (the build folder) and a fake link for the
refusal, as `TestFolderShortcutCut304` does.

## Approach

Reuse feature 304's rule: a header-only helper in `src/common/` (or include the plug-in's
`WholeFolderShortcutTargetW` logic there) - `GetIDList` + `SHGetNameFromIDList(SIGDN_FILESYSPATH)`
only for answers of 259+ units, plain form (`\\?\` / `\\?\UNC\` removed). Check `SLGP_RAWPATH`
callers (`fileswn0.cpp:909`, `fileswn2.cpp:223`) separately: the raw path may hold environment
strings, so the item-list name is not comparable there - fail closed.

## Notes

Reachable only with a shortcut written by a program that stores a long item list (the shell's
own `SetPath` refuses such targets) and a target on a volume without 8.3 names (many non-system
NTFS volumes, ReFS / Dev Drive). Severity 6: usually the cut names no existing folder (an error);
a cut on a backslash names the parent folder - a dropped file lands in another folder, not lost.
Not measured through the panels' Enter / drop (needs a real mouse for the drop).

## Log

- 2026-10-22 — created (source measure:304)
