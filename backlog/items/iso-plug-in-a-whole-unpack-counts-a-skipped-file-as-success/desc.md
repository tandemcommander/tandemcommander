---
title: ISO plug-in: a whole unpack counts a skipped file as success and deletes the image
type: bug
status: open
severity: 7
area: archives
source: review:337
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: M
feature: -
related: [iso-plug-in-a-whole-unpack-of-an-image-with-audio-or-left]
depends-on: []
reason: -
---

# ISO plug-in: a whole unpack counts a skipped file as success and deletes the image

## Problem

Unpack (Alt+F9) of a whole disc image with "Delete archive after unpacking" reports success whenever the
user did not cancel. When a file of the image cannot be read (a damaged sector, a sector the image stores
only in part) or cannot be created in the target, the plug-in asks "Skip / Skip all / Cancel"; after Skip
the unpack goes on, returns success, and the core deletes the image - the skipped file's only copy is
lost. Two listed records with the same name (a damaged or crafted directory) can also let one file
overwrite the other before the image is deleted.

## Evidence

- Found by reading in the reviews of feature 337 (`specs/337-uniso-form2-partial/fix-log.md`, *Review*,
  review 1 NOTE and review 2 NOTE 2); not reproduced in the GUI.
- At 80f04f75: `src/plugins/uniso/uniso.cpp` `CPluginInterfaceForArchiver::UnpackWholeArchive` sets
  `ret = isoImage.ExtractAllItems(...) != UNPACK_CANCEL` - `UNPACK_ERROR` (Skip) counts as success; only
  the listing's `ListingLeftOut` mark (features 328-337) makes it fail.
- `src/plugins/uniso/isoimage.cpp` `CISOImage::ExtractAllItems` returns `UNPACK_CANCEL` or falls through;
  `src/plugins/uniso/rawfs.cpp` / `iso9660.cpp` `UnpackFile` return `UNPACK_ERROR` after Skip / Skip all
  (read error, `IDS_ERROR_READING_SECTOR`; file creation errors).

## Expected

A whole unpack in which any file was skipped (or not extracted whole) fails, so "Delete archive after
unpacking" keeps the image; the files extracted stay. Measured first with a probe (a hidden-desktop row
that answers Skip in the read-error box is feasible: the box is a plug-in dialog) - before / after.

## Notes

- How other archive plug-ins and the core treat a skipped file at "Delete archive after unpacking" was not
  checked; the fix may belong to the core's rule rather than to the ISO plug-in alone.
- Same-name records: not verified whether the core's listing keeps both entries (review 2's reading).

## Log

- 2026-10-24 — created (source review:337)
- 2026-10-24 — moved to Next position 1
