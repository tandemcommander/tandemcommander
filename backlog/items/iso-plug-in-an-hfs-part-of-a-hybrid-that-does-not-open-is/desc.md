---
title: ISO plug-in: an HFS+ part of a hybrid that does not open is dropped without a mark
type: bug
status: new
severity: 6
area: archives
source: review:330
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: S
feature: -
related: [iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot, iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let]
depends-on: []
reason: -
---

# ISO plug-in: an HFS+ part of a hybrid that does not open is dropped without a mark

## Problem

A hybrid disc image (ISO 9660 and / or UDF plus HFS+) is listed with one folder per file system.
When its HFS+ part does not open, the ISO plug-in drops it without a message and without marking
the listing incomplete; Unpack with "Delete archive after unpacking" then extracts the other parts
and the image is deleted - files that exist only in the HFS+ part (Mac-only resources, files hidden
from the other parts) are lost. Feature 330 marks the listing when a declared ISO 9660 or UDF part
does not open, but left the HFS+ part's quiet handling as it was.

## Evidence

- Review 2 of feature 330 (`specs/330-iso-unreadable-folder/fix-log.md`, section Review, review 2,
  NOTE 3; found by reading, not reproduced): `src/plugins/uniso/udfiso.cpp` `CUDFISO::Open` at
  91f37bcf (about line 76, "Scan HFS part but silently ignore any problem"):
  `hfs->Open((udf || iso) ? TRUE : quiet)` - a failure deletes the part, no mark; 330's
  `PartMissing` covers only `HasISO` / `HasUDF`.
- `CISOImage::OpenTrack` (`isoimage.cpp`) chooses `CUDFISO` for `fsUDF_ISO9660_HFS`,
  `fsISO9660_HFS`, `fsUDF_HFS` (and the APFS types, which open `CHFS` too).

## Expected

When the image's descriptors declare an HFS+ part and it does not open, the listing is marked
incomplete, so a whole unpack fails and the image is kept (fail closed). The quiet open stays (no
new box); APFS parts, which the plug-in never lists, need their own decision (marking them would
make every APFS hybrid's whole unpack fail).

## Notes

- Related: `iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot` (a valid xorriso hybrid
  shows a box at the open) - first measure whether valid hybrids' HFS+ parts open; marking a part
  that fails on valid images would make their whole unpack fail.
- Probe images: feature 329's `mkimg329.sh` (xorriso `-hfsplus on`) and 322's `mkimg322.sh`, with the
  HFS+ volume header patched.

## Log

- 2026-10-24 — created (source review:330)
