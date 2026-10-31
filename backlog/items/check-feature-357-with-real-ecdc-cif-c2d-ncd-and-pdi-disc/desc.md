---
title: Check feature 357 with real ECDC, CIF, C2D, NCD and PDI disc images, one and two sessions
type: person-step
status: open
severity: 3
area: archives
source: leftover:357
who: person
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: [check-feature-355-with-real-raw-bin-and-mdf-disc-images-one]
depends-on: []
reason: -
---

# Check feature 357 with real ECDC, CIF, C2D, NCD and PDI disc images, one and two sessions

## Problem

Feature 357 applies feature 355's rule of the rest past the listed volume to disc images the ISO plug-in's
plain detection opens through the Easy CD Creator (ECDC), NRG-offset, 2336, NCD, PDI, CIF, WinOnCD C2D (also
Mode 2 and Roxio) or CIF 2332 layout: more than 16 whole sectors past the volume whose user data is not all
zero (or more than 512 sectors) mark the listing incomplete, so a whole unpack with "Delete archive after
unpacking" keeps the image. It was measured with crafted images only: no real image of those formats existed
on the machine. A real one-session image that ends with more than 16 sectors of non-zero vendor data (a
trailer, a table) would now be kept after a whole unpack - nothing is lost, but the user deletes it by hand.

## Evidence

- `specs/357-uniso-other-layouts/fix-log.md` (*Measurement before*, *Review*, NOTE 1); probe
  `specs/357-uniso-other-layouts/probe/iso357_probe.ps1`, images by `probe/img357.py` (crafted from 334's
  genisoimage seeds).
- `src/common/salisotrack.h` (`SalIsoPlainRawRuleApplies`, `SalIsoRawRestDecision`),
  `src/plugins/uniso/isoimage.cpp` (`CISOImage::Open`, the plain branch, `plainLayout`).

## Expected

A real one-session data CD image in each of those formats unpacks whole and is deleted with "Delete archive
after unpacking"; a real two-session image in the same format is kept.

## Steps

- [ ] With a build carrying feature 357, take a real Easy CD Creator image of a single-session data CD
  (`.bin` or the image without its `.cue`), copy it alone into an empty folder, select it, Alt+F9 (Unpack),
  tick "Delete archive after unpacking", OK: expected every file extracted and the image deleted. If it is
  kept, record its size, the volume size an ISO tool shows and whether the bytes past the volume are zero, in a
  new backlog item.
- [ ] The same with a real `.cif` (Easy CD Creator / Roxio), `.c2d` (WinOnCD / Roxio), `.ncd` (NTI) and `.pdi`
  (Instant CD/DVD) image of a single-session data CD, each in turn: expected extracted and deleted (or recorded
  as above).
- [ ] The same with any of those formats holding a two-session data CD: expected the first session's files
  extracted and the image KEPT.

## Log

- 2026-10-31 — created (source leftover:357)
- 2026-10-31 — moved to Person steps position 51
