---
title: Check feature 334 with real NRG and CCD disc images
type: person-step
status: open
severity: 6
area: archives
source: leftover:334
who: person
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: S
feature: -
related: [iso-plug-in-a-track-of-a-ccd-or-nrg-image-may-keep-an]
depends-on: []
reason: -
---

# Check feature 334 with real NRG and CCD disc images

## Problem

Feature 334 marks the ISO plug-in's listing incomplete for tracks it cannot read and for every audio
track, so Unpack (Alt+F9) with "Delete archive after unpacking" keeps such images. It was proven only on
crafted NRG images (two genisoimage sessions put into an NRG by a script) in the Debug build. Real images
written by Nero, CloneCD / Alcohol (CCD/IMG) and the Release build were not tried: a real image whose
tracks all open and that holds no audio must still be deleted, and a CCD image's data tracks may carry
an uninitialised type in Release (Inbox `iso-plug-in-a-track-of-a-ccd-or-nrg-image-may-keep-an`).

## Evidence

- `specs/334-uniso-session-missing/fix-log.md` (probe rows, all on crafted NRG images, Debug build),
  `specs/334-uniso-session-missing/quickstart.md`.

## Expected

The Steps below confirm on real images that complete data images are still unpacked and deleted, and
that images with audio or unreadable tracks are kept.

## Steps

- [ ] With a Release build carrying feature 334, take a real data-only NRG (Nero "Data disc", one
  session) and a real data-only CCD/IMG (CloneCD of a data CD). For each: select it, Alt+F9 (Unpack),
  tick "Delete archive after unpacking", OK. Expected: every file extracted, the image deleted. Repeat
  each three times (the CCD case depends on heap contents in Release).
- [ ] A real multi-session NRG (Nero, two data sessions): the same. Expected: "Session 01" and
  "Session 02" extracted, the image deleted.
- [ ] A real audio CD NRG and a mixed-mode (data + audio) or CD-Extra image: the same. Expected: the data
  files extracted, no audio file, the image KEPT (no message - Inbox
  `iso-plug-in-a-whole-unpack-of-an-image-with-audio-or-left`).
- [ ] If a complete data image is kept, or an audio image is deleted: report it as a new backlog item
  naming feature 334, with the image's track table (the viewer's info, F3 on the image).

## Log

- 2026-10-24 — created (source leftover:334)
- 2026-10-24 — auto-triage: severity 4 -> 6: a check guarding a data-loss fix (feature 334 keeps an image whose unpack left content out instead of deleting it)
- 2026-10-24 — moved to Person steps position 7
