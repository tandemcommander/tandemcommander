---
title: Accented archive edits and long archive paths: rows the probes could not drive
type: person-step
status: open
severity: 2
area: archives
source: leftover:096
who: person
created: 2026-10-02
updated: 2026-10-17
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Accented archive edits and long archive paths: rows the probes could not drive

## Problem

Features 096 (an edited archive member with a non-ASCII name is packed back) and 097 (archives with paths over 259 bytes refused instead of cut, later widened by 160) left rows the hidden-desktop probes could not drive: 096 - the RAR external packer with an accented name, a critical shutdown with an edited accented file, an accented %TEMP%; 097 - a real mouse drag.

## Evidence

specs/096-archive-edit-accented/fix-log.md ~line 51 'Not driven: the RAR external packer with an accented name; a critical shutdown with an edited accented file; an accented %TEMP%'. specs/097-archive-long-path/fix-log.md 'Not driven' and NEXT-WORK §5 L1536-1542 ('a real mouse drag was not driven'); drop/paste into such an archive was widened by feature 160 (NW §A.12). NEXT-WORK §5 L1929-1934. These rows are not in NW §B's person-step lists. Migrated from specs/NEXT-WORK.md §5 (at 7993914c).

## Expected

Each step below done once on a Release or Debug build and its result recorded; a failure becomes an item of its own.

## Notes

Check specs/096-archive-edit-accented/quickstart.md and specs/160-*/quickstart.md first - a step may already be written there. The 096 rows need WinRAR installed and configured as the external packer; the shutdown row needs a real sign-out or shutdown.

## Steps

- [ ] (096) WinRAR configured as the external packer: F4 on a member with an accented name (e.g. `čšž.txt`) in a .rar archive, change and save, leave the archive -> the Archive Update question appears and the archive holds the edit.
- [ ] (096) An F4 edit of an accented member pending (not packed back yet), then a real sign-out or shutdown -> no hang or loop; the temporary copy is kept, not deleted.
- [ ] (096) %TEMP% / %TMP% set to a folder with an accented name, program restarted: F4 edit of an archive member, save, leave -> packed back.
- [ ] (097, 160) A real mouse drag of a file from a panel onto a ZIP archive whose full path is longer than 259 bytes -> packed into that archive (no cut path, no other archive touched).

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §5–§8 (feature 242)
