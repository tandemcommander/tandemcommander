---
title: Changing to a plug-in path cuts the name to focus at 259 bytes and may focus another item
type: bug
status: open
severity: 3
area: long-paths
source: review:380
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Changing to a plug-in path cuts the name to focus at 259 bytes and may focus another item

## Problem

`CFilesWindow::ChangePathToPluginFS` copies the name it should focus after the change
(`suggestedFocusName`) into `char backup3[MAX_PATH]` with `lstrcpyn`. A name over 259 bytes of UTF-8
is cut, possibly inside a character, and the panel then focuses the item whose name is the cut text
(if one exists) or nothing. Reached for example by the Registry Editor's Find window, *Focus*, on a
value or key whose UTF-8 name is over 259 bytes (a key name may hold 255 characters - up to 765
bytes; the plug-in's value names up to 511 characters), and by every plug-in that calls
`ChangePanelPathToPluginFS` with a focus name. The path itself is refused correctly when it is too
long (`strlen(fsUserPart) >= MAX_PATH` → `IDS_TOOLONGPATH`). Breaks "a path or name is never cut";
the wrong focus may lead the user's next key press to another item.

## Evidence

Found by the independent review of feature 380 (`specs/380-regedt-full-path-cut/fix-log.md`,
*Review*, NOTE 3); confirmed by reading at 89c410a1: `src/fileswn2.cpp`
`CFilesWindow::ChangePathToPluginFS`, `char backup3[MAX_PATH]; ... lstrcpyn(backup3,
suggestedFocusName, MAX_PATH);` (around line 3114). Entry from plug-ins:
`src/zip.cpp` `CSalamanderGeneral::ChangePanelPathToPluginFS`; Registry Editor caller
`src/plugins/regedt/menu.cpp` `MID_FOCUS` (name buffer `3 * MAX_KEYNAME` bytes). Not reproduced in
the GUI.

## Expected

The focus name is kept whole (a heap copy or a `SAL_MAX_PATH_UTF8` buffer), or, when it cannot be
kept, no focus name is used - never a cut one. A probe (Registry Editor Find on a value with a
300-byte name next to a value named by its first 259 bytes) shows the right item focused.

## Notes

Severity 3: focus only, narrow (names over 259 bytes); raise it if a probe shows the cut name
focusing an existing other item.

## Log

- 2026-11-01 — created (source review:380)
- 2026-11-01 — moved to Next position 88
