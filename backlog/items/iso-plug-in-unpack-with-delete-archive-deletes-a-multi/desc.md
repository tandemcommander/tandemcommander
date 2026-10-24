---
title: ISO plug-in: Unpack with Delete archive deletes a multi-session image whose session track cannot be opened
type: bug
status: in-progress
severity: 7
area: archives
source: review:330
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: 2026-10-24 21c3ce91
effort: S
feature: 334
related: []
depends-on: []
reason: -
---

# ISO plug-in: Unpack with Delete archive deletes a multi-session image whose session track cannot be opened

## Problem

A multi-session disc image is listed with one folder per session (the default, "Session NN"). When
one session's track cannot be opened, the ISO plug-in shows its multi-session error box and lists the
other sessions - but the listing is not marked incomplete, so Unpack (Alt+F9) with "Delete archive
after unpacking" extracts the other sessions, reports success, and the image is deleted: the files of
the session that could not be opened are lost. The single-session path has the same gap: when the
last data track does not open but another track (audio) lists, the listing is accepted as complete.
Feature 330 marks the listing incomplete for unreadable folders and file-system parts inside a track,
not for whole tracks.

## Evidence

- Review 2 of feature 330 (`specs/330-iso-unreadable-folder/fix-log.md`, section Review, review 2;
  found by reading, not reproduced - it needs a multi-session container image, e.g. CUE/CCD/MDS/NRG):
  `src/plugins/uniso/isoimage.cpp` `CISOImage::ListImage` at 91f37bcf (about lines 1404-1430):
  `if (OpenTrack(track, TRUE)) ListDirectory(...) else ret = FALSE;` then
  `if (!ret) Error(IDS_ERROR_OPENING_MULTISESSION); return TRUE;` - no
  `ListingLeftOut.SetIncomplete()`; the `else` branch (about 1432-1446) returns TRUE when any other
  track lists after `OpenTrack(LastTrack)` failed.
- `src/plugins/uniso/uniso.cpp`: `Options.SessionAsDirectory = TRUE` by default (line 362);
  `UnpackWholeArchive` fails only when the listing is marked (`ListingLeftOut`, feature 328).

## Expected

A listing that left out a track or session that could not be opened is marked incomplete, so a whole
unpack fails and "Delete archive after unpacking" keeps the image (CLAUDE.md: a "safe to delete?"
check fails closed). The error box and the listing of the other sessions stay as they are.

## Notes

- A probe needs a crafted multi-session image (an NRG of two data sessions, as feature 329's
  `img329.py` writes NRG audio images, with the second session's track pointing past the end).
- Audio tracks that do not open are skipped silently today (`case fsAudio`); whether they count as
  missing content (they cannot be extracted anyway) is part of the spec.

## Log

- 2026-10-24 — created (source review:330)
- 2026-10-24 — moved to Next position 4
- 2026-10-24 — verified at 21c3ce91: reproduced at 21c3ce91: crafted NRG images, multi-session track 2 not opening / past the end and single-session last track not opening - Unpack with Delete archive deleted the image, b.txt lost (probe 3 FAIL rows)
- 2026-10-24 — run started, feature 334
