---
title: ISO plug-in: a UDF folder entry without descriptors is listed empty and the image deleted
type: bug
status: new
severity: 7
area: archives
source: review:361
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: a UDF folder entry without descriptors is listed empty and the image deleted

## Problem

A damaged UDF folder entry with no allocation descriptors (L_AD 0) is listed as an empty folder without a mark; a whole unpack with Delete archive after unpacking then deletes the image.

## Evidence

- Review 2 of feature 361 (`specs/361-uniso-udf-entry-bound/fix-log.md`, *Review*): two copies of feature 330's
  `ud.iso` (`specs/330-iso-unreadable-folder/probe/mkimg330.sh`: `a/side.txt`, `top.txt`, `zlast/z.txt`) with folder
  `zlast`'s file entry (sector 263, short descriptors) or folder `a`'s (sector 261) set to L_AD 0; Alt+F9 with
  "Delete archive after unpacking" on the Debug build of 46806c89: `UDF/zlast/z.txt` (resp. `UDF/a/side.txt`) not
  extracted, no window, the image **deleted** (reviewer's log `%TEMP%/rev361r2/probe_lad0.txt`, not kept).
- `src/plugins/uniso/udf.cpp` at 46806c89: `CUDF::ReadFileEntry(Uint8*, bool, Uint16, CICBTag*, CAD*, int)` returns 0
  for an empty area and writes only the terminating descriptor (line 543: Length 0, Location 0 - `Offset` is not
  set); `CUDF::MapICB(CAD, CICBTag*, CAD*)` (line 569) returns 1 for it; `ListDirectory` (line 952) and `ScanDir`
  (line 1031) walk the folder from `dirICB.Offset` (line 990) over Length 0 - nothing, `ERR_OK`, the listing is not
  marked (feature 330's `ListingLeftOut`).
- Not a regression of 361: the same path on main.

## Expected

Such a folder entry is treated as unreadable: the listing is marked incomplete and a whole unpack keeps the image.

## Approach

`MapICB(CAD, CICBTag*, CAD*)` is used only for folders (root and sub-folders): a folder holds at least its parent
identifier, so 0 descriptors means a damaged entry - return 0 there (the root: "Bad root ICB"; a sub-folder: listed
empty and the listing incomplete, 330). An embedded folder (descriptor type 3) with L_AD 0 is the same case. Probe
rows on `ud.iso` copies (330's seed) and a control that a real empty folder (genisoimage, mkudffs) still lists.

## Notes

- Found by review 2 of feature 361 (SHOULD 1); outside that item (no hang, no read past the sector). In a Release
  build `ScanDir` also starts from the descriptor's uninitialised `Offset` field - not measured.

## Log

- 2026-10-31 — created (source review:361)
