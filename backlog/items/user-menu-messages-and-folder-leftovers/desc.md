---
title: User Menu: messages name the command, System32 fallback, silent batch ends
type: bug
status: open
severity: 4
area: panels-ui
source: review:226
who: agent
created: 2026-10-15
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [user-menu-unc-folder-pushd]
depends-on: []
reason: -
---

# User Menu: messages name the command, System32 fallback, silent batch ends

## Problem

Left from features 225, 226, 229, 234 and 238 (User Menu): the refusal message names the command, not the file (238); a missing item folder's message names the command, not the folder (234); a `.lnk` command's own "Start in" vs `lpDirectory`; a panel folder that cannot be set falls back to System32 - refuse a relative command instead; a failed chcp / `cd` ends a hidden batch silently; a kept shell ends at the OEM code page; `editwnd.cpp:355/482` read COMSPEC with the A call; long paths in the User Menu.

## Evidence

Migrated from specs/NEXT-WORK.md §D "From the GitHub issues after 0.1.9" (at 7993914c), L717-736. Features 225 (`specs/225-user-menu-long-names/`), 226, 229 (`salbatchtext.h`), 234 (`specs/234-user-menu-item-folder/`), 238.

## Expected

Messages name the file / folder at fault; a command that would run relative to System32 is refused; a failed chcp / `cd` in a hidden batch is reported; COMSPEC is read wide; long panel paths work or are refused aloud.

## Notes

The other A `SetCurrentDirectory` calls on UTF-8 paths are speed hints only (not a defect, per the source).

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §D (GitHub issues after 0.1.9) (feature 242)
