---
title: Create Directory refuses a relative name in a folder whose path is 260+ bytes
type: bug
status: in-progress
severity: 5
area: long-paths
source: measure:259
who: agent
created: 2026-10-20
updated: 2026-10-21
verified: 2026-10-21 449f35fc
effort: S
feature: 274
related: []
depends-on: []
reason: -
---

# Create Directory refuses a relative name in a folder whose path is 260+ bytes

## Problem

A user in a disk folder whose path is 260 bytes or longer (deep trees, names in scripts with three bytes per letter) presses F7 and types a new folder's name: Create Directory joins the relative name with the panel path through `SalGetFullName` with its default `nameBufSize` (MAX_PATH), which refuses the join with "The path specified is too long." - although the rest of the routine (feature 027) takes paths up to `SAL_MAX_PATH_UTF8`. Typing the full path works. Edit New File had the same limit and was fixed in feature 259.

## Evidence

By reading at 16c7b517 (not measured): `src/fileswn5.cpp:2047` `CFilesWindow::CreateDir` - `SalGetFullName(path, &errTextID, Is(ptDisk) ? GetPath() : NULL, nextFocus)` (no `nameBufSize`; `path` is `SAL_MAX_PATH_UTF8`); `src/salamdr3.cpp` `SalGetFullName` "path..." branch `if (l1 + l2 >= nameBufSize) err = IDS_TOOLONGPATH`. Seen while measuring feature 259 (`specs/259-long-name-refusals/fix-log.md` *Limits left*). The probe `specs/259-long-name-refusals/probe/editnew259_probe.ps1` (row REL) is a model for a probe of F7 (command `CM_CREATEDIR`).

## Expected

F7 in a panel whose path is 288 bytes creates a folder from a typed relative name (also of 100 CJK letters); a name over 255 UTF-16 units and a path over the program's limit are refused with a message that says so; a probe row shows the refusal before and the creation after.

## Notes

Also check the other callers of `SalGetFullName` without `nameBufSize` that take a relative name from a dialog (`fileswn5.cpp`, `fileswn7.cpp`, `mainwnd4.cpp` - see `grep -n "SalGetFullName(" src/*.cpp`); some may be the same defect - list them in the feature, fix only F7 unless they are the same few lines.

## Log

- 2026-10-20 — created (source measure:259)
- 2026-10-20 — moved to Next position 8
- 2026-10-21 — verified at 449f35fc: probe createdir274 at 449f35fc: F7 refuses nd in a 288-byte folder and 100/255 CJK letters (also in a short folder) with path too long; 256 letters get the same text
- 2026-10-21 — run started, feature 274
