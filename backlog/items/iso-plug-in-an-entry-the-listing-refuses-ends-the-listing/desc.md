---
title: ISO plug-in: an entry the listing refuses ends the listing with Error, a folder lost
type: bug
status: open
severity: 6
area: archives
source: review:326
who: agent
created: 2026-10-23
updated: 2026-10-23
verified: -
effort: M
feature: -
related: [iso-plug-in-joliet-and-iso-9660-names-are-not-made-safe]
depends-on: []
reason: -
---

# ISO plug-in: an entry the listing refuses ends the listing with Error, a folder lost

## Problem

When the panel listing refuses an entry of an ISO 9660 volume (a folder part over MAX_PATH - 5
bytes, feature 222's bound; a long Latin-1 name that `EnsureU8Name` makes longer), the ISO plug-in
shows "Error", clears what it had listed (`dir->Clear`) and goes on: the image opens with the deep
folder - or, in a hybrid or multi-session image, other file systems' entries - missing. Feature 326
avoids it for volumes it newly reads as Rock Ridge (it lists such a volume with its ISO 9660 names,
as before, when a Rock Ridge name would be refused), but images whose records start with `RR`
(genisoimage) still hit it with deep Rock Ridge trees, and a deep xorriso tree now loses its Rock
Ridge names as a whole.

## Evidence

- Feature 326, review 1: `specs/326-uniso-rrip-without-rr/probe/result_review1_before.txt`, row DEEP
  (five folders of 60 letters, a 305-byte folder part): "UnISO - Error" at the open, the folder tree
  gone from the listing. After 326's fit check: `result_after_review1.txt`, DEEP - no message, the
  ISO 9660 names (`AXXX...\DEEP.TXT`).
- `src/plugins/uniso/iso9660.cpp` `CISO9660::AddFileDir`: on a refused `AddDir` / `AddFile` -
  `dir->Clear(pluginData); return Error(IDS_ERROR);`; `ListDirectoryRe` turns it into
  `ERR_TERMINATE` / `ERR_CONTINUE` and the walk goes on.
- The core's rule: `src/common/sallistingname.h` (`SalListingAcceptsDirU8` / `FileU8`), used by
  `CSalamanderDirectory::AddFile` / `AddDir` (`src/zip.cpp`).

## Expected

An entry the listing cannot take never wipes the rest of the listing; the user learns which entries
were left out (or the deep part is reachable another way); a Rock Ridge tree keeps its names where
they fit. Never a cut name.

## Notes

Feature 321 handled the same for TAR (`SalPaxNameUsableU8`: refused members left out of the listing,
reported when an extraction asks for them) - a model. Whether a partial Rock Ridge listing is better
than whole ISO 9660 names is a trade-off; not decided here.

## Log

- 2026-10-23 — created (source review:326)
- 2026-10-23 — moved to Next position 1
