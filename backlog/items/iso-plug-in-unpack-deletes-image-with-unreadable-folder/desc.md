---
title: ISO plug-in: Unpack with Delete archive deletes an image whose folder could not be read
type: bug
status: open
severity: 7
area: archives
source: review:328
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: Unpack with Delete archive deletes an image whose folder could not be read

## Problem

When the ISO plug-in cannot read a folder of an ISO 9660 volume (an extent past the end of the image,
a record that fails its safety checks), it shows "Error reading directory structure ... Incomplete
content of ISO image" and goes on - but from then on it descends into no later folder, and the
listing is not marked incomplete. Unpack (Alt+F9) with "Delete archive after unpacking" then extracts
what was listed, reports success and the core deletes the image: files that were never extracted are
lost. Feature 328 made a whole unpack fail when the listing left out entries the panel refuses
(`CISOImage::ListingLeftOut`), not after a read error.

## Evidence

- Review 4 of feature 328 (`specs/328-uniso-refused-entry/fix-log.md`, section Review 4):
  `%TEMP%\rev328d\mkrd.sh` (genisoimage -R of `a/side.txt`, `top.txt`, `zlast/z.txt`) +
  `patchrd.py` (folder A's extent pointed past the end) + `rd_probe.ps1` (row RDERR-UNP-DEL): on
  328's HEAD and on main alike the box, 1 of 3 files extracted (`top.txt`; `z.txt` is readable but its
  folder is never descended) and the image deleted.
- `src/plugins/uniso/iso9660.cpp` `CISO9660::ListDirectoryRe`: the failed `ReadBlock` and the record
  safety checks return `ERR_CONTINUE` / `ERR_TERMINATE` after `Error(IDS_ERROR_LISTING_IMAGE)`
  without `Image->ListingLeftOut.SetIncomplete()`; the parent's "descend only when everything is OK".
- `src/plugins/uniso/uniso.cpp` `UnpackWholeArchive`: fails only when `ListingLeftOut` is set.

## Expected

A listing that met a read error is marked incomplete, so a whole unpack of it fails and "Delete
archive after unpacking" keeps the image (CLAUDE.md: a "safe to delete?" check fails closed). Whether
later folders should still be descended after a read error is a separate question (it would list
`zlast\z.txt`).

## Log

- 2026-10-23 — created (source review:328)
- 2026-10-23 — auto-triage: severity 6 -> 7: data loss in a narrow scenario - files never extracted are lost when Delete archive after unpacking deletes a damaged image
- 2026-10-23 — moved to Next position 2
- 2026-10-23 — related item iso-plug-in-udf-xbox-and-hfs-entries-the-listing-refuses done in feature 329
