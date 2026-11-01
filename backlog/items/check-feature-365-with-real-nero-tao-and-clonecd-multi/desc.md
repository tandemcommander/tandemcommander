---
title: Check feature 365 with real Nero TAO and CloneCD multi-session dumps
type: person-step
status: new
severity: 5
area: archives
source: leftover:365
who: person
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: -
feature: -
related: [check-feature-334-with-real-nrg-and-ccd-disc-images]
depends-on: []
reason: -
---

# Check feature 365 with real Nero TAO and CloneCD multi-session dumps

## Problem

Feature 365 makes the ISO plug-in read Nero track-at-once tables (ETNF modes 0x05 / 0x06; every ETN2 entry
with its mode, first sector and end) and lay out CloneCD images from their table of contents (PLBA, the
sessions one after another in the `.img`). It was proven on crafted images only (genisoimage sessions,
`img365.py`), built from libmirage's and psx-spx's description of the formats. Real dumps may differ: the
meaning of an ETN2 entry's first-sector field, a CloneCD `.img` that keeps the 11400 sectors between
sessions, a stored pregap before a later session's first track.

## Evidence

- `specs/365-nrg-ccd-track-tables/fix-log.md` (probe `iso365_probe`, 9 rows on crafted images, 12 / 6
  before -> 18 / 0), `specs/365-nrg-ccd-track-tables/quickstart.md`, `research.md` R2 / R3.

## Expected

The Steps confirm on real dumps that every session is listed and unpacked with the right content, and
that "Delete archive after unpacking" deletes the image only then.

## Steps

- [ ] With a Release build carrying feature 365, take a two-session data CD burnt track-at-once
  (multi-session, "continue disc") and dump it with Nero as `.nrg` (Nero 6 or later: an "NER5" image with
  ETN2 chunks). Open it in Tandem Commander: expected two folders `Session 01`, `Session 02` with the
  files of each session. Alt+F9 (Unpack), tick "Delete archive after unpacking", OK: expected every file
  extracted with its content (compare with the disc), no message, the image deleted.
- [ ] A one-session data CD burnt track-at-once and dumped with Nero 6 or later (`.nrg`): opened and
  unpacked whole, the image deleted (review 1: the ETN2 first-sector field is now read relative to the
  first track; a one-session image must still open as before 365).
- [ ] The same disc dumped with CloneCD (`.img` + `.ccd` + `.sub`): the same result. Note whether the
  `.ccd`'s `[TRACK 2]` `INDEX 1` is 0 (counted from the session) or the track's PLBA, and whether it has an
  `INDEX 0` row (a stored pregap before session 2's first track is a known limit of 365: the session is
  not listed and the image is kept).
- [ ] A CD-Extra / Enhanced CD (audio tracks in session 1, a data session 2) dumped with CloneCD: the
  data session's files listed and extracted; the image KEPT (audio tracks are never extracted).
- [ ] If a session is missing, a file has wrong content, or an image is deleted without every file:
  report it as a new backlog item naming feature 365, with the `.ccd` (or the NRG chunk dump - the last
  few KB of the file) and the image's track table (F3 on the image).

## Log

- 2026-11-01 — created (source leftover:365)
