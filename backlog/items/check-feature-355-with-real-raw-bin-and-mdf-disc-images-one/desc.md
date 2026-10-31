---
title: Check feature 355 with real raw .bin and .mdf disc images, one and two sessions
type: person-step
status: new
severity: 3
area: archives
source: leftover:355
who: person
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: [check-feature-354-with-real-cooked-disc-images-multi-session]
depends-on: []
reason: -
---

# Check feature 355 with real raw .bin and .mdf disc images, one and two sessions

## Problem

Feature 355 marks the listing of a raw disc image (2352-byte sectors with the CD sync pattern, any name but
an `.img` whose `.ccd` is missing - a `.bin` without its `.cue`, an `.mdf`, a raw `.iso`) incomplete when
more than 16 whole sectors lie past the volume the plain detection lists and their user data is not all zero
(or more than 512 sectors lie there), so a whole unpack with "Delete archive after unpacking" keeps it. It
was measured with crafted images only: no real `.bin` / `.cue` / `.mdf` existed on the machine. How a real
one-session dump ends (post-gap, run-out sectors) and where a real two-session dump puts its second session
were not seen.

## Evidence

- `specs/355-uniso-raw-sessions/fix-log.md` (*Measurement before*, *Deviation and limits*, *Review*); probe
  `specs/355-uniso-raw-sessions/probe/iso355_probe.ps1`, images by `probe/img355.py` (crafted).
- `src/common/salisotrack.h` (`SalIsoRawRestDecision`), `src/plugins/uniso/isoimage.cpp`
  (`CISOImage::Open`, the plain branch, block of feature 355).

## Expected

A real one-session data CD dumped as a raw `.bin` (its `.cue` moved away) or an Alcohol 120% `.mdf` (its
`.mds` moved away) unpacks whole and is deleted with "Delete archive after unpacking"; a real two-session
data CD dumped the same way is kept.

## Steps

- [ ] With a build carrying feature 355, take a raw BIN/CUE dump of a single-session data CD; copy only the
  `.bin` into an empty folder. Select it, Alt+F9 (Unpack), tick "Delete archive after unpacking", OK:
  expected every file extracted and the `.bin` deleted. If it is kept, record the `.bin` size, the volume
  size any ISO tool shows, and the tail's content (zero or not) in a new backlog item.
- [ ] The same with an Alcohol 120% `.mdf` of a single-session data CD (only the `.mdf` copied): expected
  extracted and deleted (or recorded as above).
- [ ] The same with a raw `.bin` and an `.mdf` of a two-session data CD: expected the first session's files
  extracted and the image KEPT.

## Log

- 2026-10-31 — created (source leftover:355)
