---
title: User Menu on items in folders of 260 or more bytes: work, or refuse aloud
type: bug
status: new
severity: 4
area: long-paths
source: manual
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: L
feature: -
related: [user-menu-messages-and-folder-leftovers, user-menu-find-route-person]
depends-on: []
reason: -
---

# User Menu on items in folders of 260 or more bytes: work, or refuse aloud

## Problem

The User Menu handles every item through `MAX_PATH` buffers (the `UM_GetNextFileName` contract: `path[MAX_PATH]`, `name[MAX_PATH]`; `initDir`, `firstItemDir`, `CompareName1/2`, `FullPathLeft/Right/Inactive`). Items whose folder or full name has 260+ bytes (UTF-8: about 87 CJK letters already) cannot be used with any User Menu item. Feature 225 made the panel's no-name case refuse "too long name"; other places cut the text and rely on a later length check: the Find window's route cuts path and name at 259 bytes ("User Menu is not long-path capable yet"), the panel's selection route cuts the panel path, and the compare names end empty (the user is then asked for them). Each such route must either work with the whole path or refuse aloud - never act on a cut one.

## Evidence

At 50cf9e7d (by reading):

- `src/finddlg1.cpp` `GetNextItemFromFind` (~851-852): `lstrcpyn(path, file->Path, MAX_PATH); lstrcpyn(name, file->Name, MAX_PATH);` with the comment "longer UTF-8 paths/names are truncated here".
- `src/mainwnd4.cpp` `GetNextFileFromPanel`: ~463 refuses a 260+ byte panel path only when nothing is selected (225); the selection branch ~491-492 cuts path and name.
- `src/mainwnd4.cpp` `ExpandCommand2` (~601-622): `IDS_TOOLONGNAME` when path + name do not fit - the refusal the cut texts above rely on; a cut name with an empty path part is not caught there.
- `src/mainwnd3.cpp` (~2800-2812) and `src/finddlg1.cpp` (~2790-2805): `CompareName1/2` via `lstrcpyn` + `SalPathAppend(..., MAX_PATH)`, emptied when too long.
- Features 027, 225 (`specs/225-user-menu-long-names/`); split from `user-menu-messages-and-folder-leftovers`.

## Expected

Measured first (a probe with a 260+ byte folder and a name of 90 CJK letters, panel focus, panel selection, Find results): every User Menu route either runs the command on the whole name or refuses with "too long name" before anything runs; no route acts on, or shows, a cut path. Whether "work" (heap buffers through `UM_GetNextFileName` and the expansion) or "refuse" is chosen per route is recorded in the spec; CLAUDE.md "a path or name is never cut".

## Notes

The batch route's `cd /d` and cmd itself limit the folder (cmd's current folder is limited to MAX_PATH): "refuse" may be the only option there. The Find route itself is owed to a person (`user-menu-find-route-person`).

## Log

- 2026-10-20 — created (source manual)
