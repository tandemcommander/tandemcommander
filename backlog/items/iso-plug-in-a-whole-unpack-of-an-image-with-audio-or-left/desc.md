---
title: ISO plug-in: a whole unpack of an image with audio or left-out tracks fails without saying why
type: improvement
status: open
severity: 3
area: archives
source: review:334
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: S
feature: -
related: [iso-plug-in-a-track-of-a-ccd-or-nrg-image-may-keep-an]
depends-on: []
reason: -
---

# ISO plug-in: a whole unpack of an image with audio or left-out tracks fails without saying why

## Problem

Since feature 334 a disc image whose listing left out content - an audio track (the plug-in never
extracts audio), an unknown track, a track that does not open, lies past the end of the image or no
session covers, another data track of a one-session image - is marked incomplete, so Unpack (Alt+F9) of
the whole image fails and "Delete archive after unpacking" keeps the image. For most of these cases the
user gets no message at all (feature 330's silent cases are the same): the files that could be read are
extracted, the image simply stays, and nothing says why. Audio CDs, CD-Extra and game discs with audio
tracks are the common case. Only names refused by the listing (feature 328) and a session that does
not open (the multi-session box) are reported.

## Evidence

- Review 2 of feature 334, NOTE 1 (`specs/334-uniso-session-missing/fix-log.md`, section Review).
- `src/plugins/uniso/uniso.cpp` `ListArchive`: `ReportListingLeftOut` only when
  `ListingLeftOut.Count > 0`; `UnpackWholeArchive` returns FALSE on `pd->ListingLeftOut` without a box.
- Probe `specs/334-uniso-session-missing/probe/iso334_probe.ps1` rows S-MIXED, M-MIXED, A-CD, M-PAST,
  S-TERM, S-OK: image kept, "no window".

## Expected

A whole unpack that fails only because the listing is incomplete says so once (e.g. "The image was not
deleted: some of its content (audio tracks, a session that could not be read) was not extracted"),
without a box on every panel listing; a new UI string with the `.slt` refresh.

## Notes

- Feature 334 kept the UI unchanged on purpose (its item: "the error box ... stay as they are").

## Log

- 2026-10-24 — created (source review:334)
- 2026-10-24 — moved to Next position 74
