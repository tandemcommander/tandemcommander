---
title: unrar plug-in: a member name over 259 bytes overflows a stack buffer on F3 / F4
type: bug
status: new
severity: 7
area: archives
source: review:260
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: [f3-f4-refuse-archive-members-whose-path-inside-the-archive]
depends-on: []
reason: -
---

# unrar plug-in: a member name over 259 bytes overflows a stack buffer on F3 / F4

## Problem

The unrar plug-in (disabled in the default build, `plugins.cfg` unrar=off) copies the member's path inside the archive into a stack buffer of MAX_PATH characters when one member is extracted for F3 / F4. A RAR member whose path inside the archive has 260-519 bytes (a long CJK name, or a long folder path) overflows the buffer - a crash or worse for anyone who enables the plug-in. It was reachable before feature 260 through long folder paths inside the archive; since 260 the disk cache no longer refuses root-level names of that length first, so more names reach it.

## Evidence

At aec864cf: `src/plugins/unrar/unrar.cpp` `CPluginInterfaceForArchiver::UnpackOneFile` (line ~593): `TCHAR justName[MAX_PATH]; lstrcpy(justName, nameInArchive);` (line ~615-616), later `SalPathAppend(TargetName, justName, MAX_PATH)` (~686). By reading (review 1 of feature 260, S2 - `specs/260-archive-cache-long-names/fix-log.md`, *Review*); not driven (the plug-in is not built by default and needs a RAR fixture).

## Expected

`UnpackOneFile` takes a member name of any length the listing accepts: the name part is taken without a fixed buffer (or refused with a message when the target path cannot hold it), never copied past a buffer and never cut.

## Notes

Review 1 of 260 also saw unchm (`src/plugins/unchm/unchm.cpp` ~456) and demoplug refuse such names through a bounded `SalPathAppend` into MAX_PATH without a message - F3 then does nothing. Both are disabled; worth a look in the same pass. Severity from the band "crashes in an unusual scenario" (a disabled plug-in).

## Log

- 2026-10-20 — created (source review:260)
