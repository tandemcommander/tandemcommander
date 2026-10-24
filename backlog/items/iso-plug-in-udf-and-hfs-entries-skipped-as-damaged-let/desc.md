---
title: ISO plug-in: UDF and HFS+ entries skipped as damaged let Unpack delete the image
type: bug
status: open
severity: 7
area: archives
source: review:329
who: agent
created: 2026-10-23
updated: 2026-10-24
verified: 2026-10-24 6070ac51
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: UDF and HFS+ entries skipped as damaged let Unpack delete the image

## Problem

When the ISO plug-in skips an entry of a UDF or HFS+ volume because the image is damaged or holds
something it does not handle, it does not mark the listing incomplete. A whole-image Unpack with
"Delete archive after unpacking" then extracts what was listed, reports success, and the image is
deleted - the skipped entries are lost. Feature 329 marks the listing incomplete for entries the
panel listing refuses and for out-of-memory failures, not for these.

## Evidence

Branch 329-uniso-other-readers-refused at 2abc8895:
- `src/plugins/uniso/udf.cpp` `CUDF::AddFileDir`: a file whose ICB cannot be read (`MapICB` fails,
  about line 852) ends its directory (`ADD_FAILED` -> `ERR_TERMINATE`), no mark.
- `src/plugins/uniso/hfs.cpp` `CHFS::ListDirectory`: a record of a type other than folder / file ends
  the whole HFS+ listing (`return FALSE`, about line 514); feature 322's skips - a record that does
  not fit its node (about line 308), a name over 255 units (330), a record shorter than its structure
  (338), a name that does not convert (347) - continue without a mark.
- `src/plugins/uniso/uniso.cpp` `UnpackWholeArchive` fails only when `ListingLeftOut` is set.
- Review 1 of feature 329 (`specs/329-uniso-other-readers-refused/fix-log.md`, *Review*): found by
  reading; not reproduced with an image.

## Expected

A listing that skipped an entry the image holds (a damaged record, an unreadable ICB, a record
type the reader does not handle) is marked incomplete, so a whole unpack of it fails and "Delete
archive after unpacking" keeps the image (CLAUDE.md: a "safe to delete?" check fails closed).
Thread records and the volume-label record, which are not entries, stay skipped without a mark.

## Notes

- The ISO 9660 counterpart is `iso-plug-in-unpack-deletes-image-with-unreadable-folder` (review 4 of
  328); the two could be done in one feature (same mark, different readers).
- Not reproduced: a probe needs a UDF image with a damaged file ICB, or an HFS+ catalog record
  patched to a bad length (feature 322's probe images).

## Log

- 2026-10-23 — created (source review:329)
- 2026-10-23 — moved to Next position 3
- 2026-10-24 — related item iso-plug-in-unpack-deletes-image-with-unreadable-folder done in feature 330
- 2026-10-24 — verified at 6070ac51: HFS+ part present at 6070ac51: probe iso332 H-TYPE/KEY/LONG/SHORT image deleted; UDF part fixed by 330 (U-FILE kept)
