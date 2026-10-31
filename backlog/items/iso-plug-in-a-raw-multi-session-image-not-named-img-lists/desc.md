---
title: ISO plug-in: a raw multi-session image not named .img lists one session, then Unpack deletes it
type: bug
status: new
severity: 5
area: archives
source: review:354
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: a raw multi-session image not named .img lists one session, then Unpack deletes it

## Problem

A raw disc image (2352-byte sectors with the CD sync pattern, for example a `.bin` without its `.cue`, an
Alcohol 120% `.mdf`, or a raw dump named `.iso`) that holds a second session past the first is listed by
the ISO plug-in's plain detection: only the volume at its sector 16 - the first session. A whole Unpack
(Alt+F9) with "Delete archive after unpacking" then succeeds and deletes the image with the later
session's files. Feature 353 marks this only for an `.img` whose `.ccd` is missing; feature 354 only for
cooked (2048-byte) images.

## Evidence

- Review 1 of feature 354 (`specs/354-uniso-cooked-sessions/fix-log.md`, *Review*, SHOULD S1): the
  reviewer's seed (s1 + s2 of 334's `mkimg334.sh` written as raw Mode 1 sectors, named `two.iso`) on the
  354 build: a.txt extracted, the image deleted, b.txt lost.
- `src/plugins/uniso/isoimage.cpp`, `CISOImage::Open` plain branch: 353's block runs only when
  `CcdMissing` (set by `ReadSessionCCD`, reached from `ReadSessionInfo` for the `.img` extension only) and
  `rawStart`; 354's `cookedIso` block requires `!rawStart`. The plug-in reads no `.cue` / `.mds`, so every
  raw `.bin`, `.mdf` and `.iso` takes the plain branch unmarked.

## Expected

A raw image of the plain detection whose file holds more than 16 sectors past the listed volume (353's
`SalIsoNoCcdRestMarks`, perhaps with 354's zero-rest check) marks the listing incomplete whatever its
extension; a raw one-session image (within 16 sectors of its volume) unpacks and is deleted as today -
measured with the reviewer's seed (raw s1 + s2 named `.iso` / `.bin` / `.mdf`) before and after.

## Notes

- Measure first how a real `.bin` / `.mdf` of a one-session data CD ends (post-gap, run-out sectors past
  the volume): 353 found such tails mark raw `.img` dumps already (its *Limits*).
- `CheckForMDF` and the other plain checks may open some of these files at another layout; the rule reads
  the volume where the opened layout puts sector 16 (as 353).

## Log

- 2026-10-31 — created (source review:354)
- 2026-10-31 — related item iso-plug-in-a-cooked-multi-session-image-lists-one-session done in feature 354
