---
title: Check feature 352 with real CloneCD dumps (one and two sessions)
type: person-step
status: new
severity: 3
area: archives
source: leftover:352
who: person
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: [check-feature-334-with-real-nrg-and-ccd-disc-images]
depends-on: []
reason: -
---

# Check feature 352 with real CloneCD dumps (one and two sessions)

## Problem

Feature 352 made the ISO plug-in's CloneCD reader stricter: every needed `.ccd` row (`MODE`, `INDEX 1`,
`Session`, `Point`, `PLBA`, `ADR`, `PreGapMode`, `PreGapSubC`) must appear once per section and hold a
number, and every `[Entry n]` must name an existing `[Session n]`; otherwise the `.ccd` is refused ("Bad
format of .CCD file") and the image is kept by a whole unpack. A `.ccd` whose `[Session n]` sections and
track splits disagree - by reading every real multi-session dump, whose `INDEX 1` values are absolute -
opens with its listing marked incomplete, so a whole unpack keeps it without a message. All of it was
measured with crafted images only; a real `.ccd` written by CloneCD (or another dumping program) was
not tried.

## Evidence

- `specs/352-uniso-ccd-session-bounds/fix-log.md` (*Measurements after*, *Review*); probe
  `specs/352-uniso-ccd-session-bounds/probe/iso352_probe.ps1`, images by `probe/img352.py` (crafted).
- `src/plugins/uniso/img.cpp` (`processTrackSection`, `processEntrySection`, `processSessionSection`,
  `CISOImage::ReadSessionCCD`), `src/common/salisotrack.h` (`SalIsoCcdReadInt`, `CSalIsoCcdFields`,
  `SalIsoCcdSessionIndex`, `SalIsoCcdLayoutTrusted`).

## Expected

A real single-session CloneCD dump opens and unpacks as before (no box, everything extracted, deleted
with "Delete archive after unpacking"); a real multi-session dump opens, and a whole unpack keeps it.

## Steps

- [ ] With a build carrying feature 352, take a real CloneCD dump of a single-session data CD
  (`.img` + `.ccd` + `.sub`). Select the `.img`, Enter: expected no "Bad format of .CCD file" box, the
  files listed. Then Alt+F9 (Unpack), tick "Delete archive after unpacking", OK: expected every file
  extracted and the image deleted.
- [ ] A real CloneCD dump of a multi-session data CD (two sessions): Enter - expected no "Bad format"
  box, the files of the last session listed; Alt+F9 with "Delete archive after unpacking": expected the
  image KEPT (no message - feature 352's layout mark until
  `iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables` is fixed).
- [ ] If either `.ccd` shows "Bad format of .CCD file": attach the `.ccd` (a text file) to a new backlog
  item naming feature 352 - a real file whose rows the stricter reader refuses.

## Log

- 2026-10-31 — created (source leftover:352)
