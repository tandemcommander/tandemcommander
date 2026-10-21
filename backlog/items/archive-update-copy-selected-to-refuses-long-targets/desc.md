---
title: Archive Update: Copy Selected To refuses an edited member whose target path is over 259 units
type: improvement
status: new
severity: 3
area: long-paths
source: review:275
who: agent
created: 2026-10-21
updated: 2026-10-21
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Archive Update: Copy Selected To refuses an edited member whose target path is over 259 units

## Problem

When leaving an archive with edited members, the Archive Update dialog offers *Copy Selected To...* as the way to keep an edit that cannot be packed back. It copies each copy to the chosen folder + the member's folder inside the archive + its name through `SHFileOperationW`, and refuses with "too long name" when that target (or the source) has more than `MAX_PATH - 1` UTF-16 units. Since feature 275, F4 edits members whose path inside the archive has up to about 1,021 bytes (a folder part of up to 255 bytes + a name of up to 255 units), so for a deep member with long names the escape route is always refused; the user is left with *Update All* (which works) or *Ignore*, which discards the edit. Nothing is cut and nothing is lost silently - the refusal is shown.

## Evidence

At 97384331 (+ feature 275's branch): `src/salamdr3.cpp` `CFileTimeStamps::CopyFilesTo` - `tooLongName |= SalU8ToW(name, -1, NULL, 0) > MAX_PATH;` for the source and for `path + ZIPRoot + FileName`, the wide names in `WCHAR nameW[MAX_PATH]`, then `SalMessageBox(parent, LoadStr(IDS_TOOLONGNAME), ...)`; `char path[MAX_PATH]` from `GetTargetDirectory`. Review of feature 275, N1 (`specs/275-arcmember-long-path/fix-log.md`, *Review*). By reading; driving it needs the folder browser (the person-step `editing-long-named-archive-members-the-rows-the-feature-260` names it).

## Expected

*Copy Selected To...* copies an edited member to a target of any length the file system takes (a long-path capable copy instead of the `MAX_PATH`-limited shell call, or a copy without the member's inner folders when the user agrees), and refuses with a message only when the file system itself cannot take the path.

## Notes

Low severity: *Update All* packs such edits back correctly (probe 275 row EDITDEEP, 857 bytes); the limit is the shell call's, a refusal with a message.

## Log

- 2026-10-21 — created (source review:275)
