---
title: ISO plug-in: after a folder that cannot be read, no later folder of the image is listed
type: improvement
status: open
severity: 4
area: archives
source: leftover:330
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: after a folder that cannot be read, no later folder of the image is listed

## Problem

When the ISO plug-in cannot read one folder of a disc image (its directory lies past the end of the
image, a record of it fails the safety checks), it shows "Error reading directory structure ...
Incomplete content of ISO image" and from then on descends into no later folder of the ISO 9660, UDF
or Xbox walk - readable folders after the damaged one are listed empty, their files cannot be viewed
or extracted. Feature 330 made such a listing fail a whole unpack (the image is kept by "Delete
archive after unpacking") but kept the walk as it was (the "separate question" of its backlog item).

## Evidence

At 330's branch (`330-iso-unreadable-folder`):
- `src/plugins/uniso/iso9660.cpp` `CISO9660::ListDirectoryRe`: a nested `ERR_TERMINATE` becomes
  `ret = ERR_CONTINUE`, and folders are descended only `if (ret == ERR_OK)` ("descend only when
  everything is OK"); `src/plugins/uniso/udf.cpp` `CUDF::ScanDir` the same (`ret == ERR_OK` before
  `ScanDir`); `src/plugins/uniso/xdvdfs.cpp` `CXDVDFS::ScanDir` likewise.
- Probe `specs/330-iso-unreadable-folder/probe/iso330_probe.ps1` rows RD-EXT, RD-REC, UD-EXT, XD-EXT
  (`result_after.txt`): the tree `a/side.txt`, `top.txt`, `zlast/z.txt` with folder `a` unreadable -
  only `top.txt` is extracted; `zlast/z.txt` is readable but its folder is never descended.

## Expected

After a folder that cannot be read, the walk goes on with the next records and descends later
folders, so every readable file is listed; the listing stays marked incomplete (330) and the error
box is shown once per damaged folder as today (or once per listing - to be decided in the spec).

## Notes

- The early stop may have been deliberate upstream (a damaged image can hold garbage records; feature
  328's visited set now bounds cycles). A fix must keep a crafted image from looping or flooding boxes:
  measure with 328's LOOP rows and a few damaged folders in one image.
- Not a data-loss defect since 330: a whole unpack of such a listing fails and the image is kept.

## Log

- 2026-10-24 — created (source leftover:330)
- 2026-10-24 — moved to Next position 23
