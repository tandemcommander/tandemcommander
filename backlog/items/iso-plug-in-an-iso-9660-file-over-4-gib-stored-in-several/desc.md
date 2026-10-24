---
title: ISO plug-in: an ISO 9660 file over 4 GiB stored in several extents extracts wrong
type: bug
status: open
severity: 5
area: archives
source: review:338
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: an ISO 9660 file over 4 GiB stored in several extents extracts wrong

## Problem

ISO 9660 level 3 stores a file of 4 GiB or more as several directory records of one name, each with the
multi-extent flag (bit 7 of the file flags) on all but the last. The ISO plug-in does not know the flag:
most likely each record is listed as its own file of that name and an unpack writes them one over the
other, leaving only the last part in the target. Since feature 338 a whole unpack notices the second write
over the first and keeps the image, but the extracted file is still wrong (and Copy (F5) extracts the same
wrong file).

## Evidence

- Review 1 of feature 338 (`specs/338-uniso-skip-fails-unpack/fix-log.md`, section *Review*, SHOULD 2);
  read at c99f39e5, not reproduced (needs a >4 GiB file in an image, e.g. `xorriso -iso-level 3` or
  `genisoimage -iso-level 3` with a sparse 5 GiB file).
- `src/plugins/uniso/iso9660.cpp` - the directory walk (around line 474) has no handling of the
  multi-extent flag; `CISO9660::UnpackFile` reads one extent of `fileData->Size` bytes.

## Expected

A multi-extent file is listed once with its whole size and extracted whole (all extents in order); if that
is not done, it is at least reported as not extracted. Measured first with such an image.

## Notes

- Before 338 the image was deleted after such an unpack; now it is kept (WroteOverOwn).
- Not verified how the listing shows the records (two entries of one name, or one hidden by the core).

## Log

- 2026-10-24 — created (source review:338)
- 2026-10-24 — moved to Next position 10
