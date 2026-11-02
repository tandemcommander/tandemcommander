---
title: ISO plug-in: an ISO 9660 folder met again is listed empty and the image deleted
type: bug
status: open
severity: 5
area: archives
source: measure:401
who: agent
created: 2026-11-02
updated: 2026-11-02
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: an ISO 9660 folder met again is listed empty and the image deleted

## Problem

When two folder records of an ISO 9660 volume name one directory with the same start block and the
same data length (a crafted or damaged image; a "hard-linked" folder), the ISO plug-in lists the
second folder empty and does not mark the listing incomplete. A whole Unpack with "Delete archive
after unpacking" then counts as complete and deletes the image, although the second folder's path
was never extracted (its files exist only under the first path). The UDF and Xbox walks mark such a
listing incomplete since feature 400 (review 2: fail closed, the image kept); the ISO 9660 walk keeps
feature 328's rule (met again = `ERR_OK`, nothing marked).

## Evidence

- `src/plugins/uniso/iso9660.cpp` `CISO9660::ListDirectoryRe` (after feature 401):
  `if (!Visited->insert(key).second) return ERR_OK;` - no `Image->ListingLeftOut.SetIncomplete()`;
  compare `CXDVDFS::VisitFolder` (`src/plugins/uniso/xdvdfs.cpp`) and `CUDF::VisitFolder`
  (`src/plugins/uniso/udf.cpp`), which mark the listing.
- Feature 401's probe `specs/401-uniso-share-length/probe/iso401_probe.ps1` row IS-HLINK (image
  `img401.py isohlink`: folders A and B at block 21 with 2048 bytes, TOP.TXT; block 21 holds X.TXT):
  a/x.txt and top.txt extracted, B empty, no window, the image deleted - before and after 401.
- Feature 400's probe rows XD-HLINK / UD-HLINK expect the image kept for the same layout in the Xbox
  and UDF walks.

## Expected

A folder of an ISO 9660 volume met again (same block, same length) marks the listing incomplete, as
the UDF and Xbox walks do, so a whole unpack fails and the image is kept; loops stay bounded. The
probe row IS-HLINK then expects the image kept; feature 328's LOOP rows and the rows of a well-formed
image (one record per directory) are unchanged.

## Notes

- Crafted or damaged images only (genisoimage / xorriso write one record per directory; Rock Ridge
  relocated folders are not followed by the plug-in). Not checked: whether 328's Rock Ridge count walks
  (`CountUnder`) meet such a folder - a count walk must stay quiet (no mark).
- 328 chose "listed empty" for ISO 9660; 400 chose "fail closed" for UDF / Xbox. Whether ISO 9660
  follows 400 is the item's question; severity 5 because the data itself is extracted under the first
  path.

## Log

- 2026-11-02 — created (source measure:401)
- 2026-11-02 — moved to Next position 3
