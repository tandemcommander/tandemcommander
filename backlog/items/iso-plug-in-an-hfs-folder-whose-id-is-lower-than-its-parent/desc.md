---
title: ISO plug-in: an HFS+ folder whose ID is lower than its parent lists its contents at the root
type: bug
status: open
severity: 5
area: archives
source: review:329
who: agent
created: 2026-10-23
updated: 2026-10-31
verified: 2026-10-31 5cf6564a
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: an HFS+ folder whose ID is lower than its parent lists its contents at the root

## Problem

The ISO plug-in lists an HFS+ volume record by record in catalog order (sorted by parent folder
ID) and finds each record's folder among the folders already listed; a record whose parent was not
listed yet is put at the HFS+ volume's root. A folder whose own catalog ID is lower than its parent's
(created first, then moved on a Mac into a newer folder) has its contents read before its own record,
so they appear at the root of `HFS (...)` instead of inside it - and a Copy or Unpack writes them to
the wrong place. Since feature 329 a folder the listing refuses is left out with its contents; for
such a folder the contents are already listed at the root when the folder is met.

## Evidence

- `src/plugins/uniso/hfs.cpp` `CHFS::ListDirectory` (branch 329-uniso-other-readers-refused at
  2abc8895, about line 401): "The items are sorted according to parentID which means our parent
  must have been parsed already" - the lookup in `pFolders`, falling back to `rootPath`.
- Review 1 of feature 329 (`specs/329-uniso-other-readers-refused/fix-log.md`, *Review*): found by
  reading; not reproduced (no image with such a folder was made).

## Expected

Every HFS+ entry is listed in its own folder whatever the catalog order (e.g. a first pass that
collects folder IDs, names and parents, then paths built from the parent chain, with a guard against
cycles), and a left-out folder's whole subtree stays out of the listing.

## Notes

- Not reproduced. An image could be made on macOS (`hdiutil`), or by patching an xorriso HFS+
  hybrid's catalog (feature 322's `probe/mkimg322.sh` makes one).
- Severity 5: wrong placement, not loss; a narrow image layout. Unsure - lower value taken.

## Log

- 2026-10-23 — created (source review:329)
- 2026-10-23 — moved to Next position 4
- 2026-10-31 — verified at 5cf6564a: reproduced at 5cf6564a: crafted xorriso HFS+ images (folders moved into newer ones, catalog re-sorted) - Unpack writes a.txt, b.txt, sub/s.txt, k.txt, kd/kd.txt at the HFS root; probe 5/3
