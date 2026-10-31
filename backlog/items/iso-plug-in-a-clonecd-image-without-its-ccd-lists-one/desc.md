---
title: ISO plug-in: a CloneCD image without its .ccd lists one session, then Unpack deletes it
type: bug
status: open
severity: 7
area: archives
source: measure:352
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: S
feature: -
related: [iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables]
depends-on: []
reason: -
---

# ISO plug-in: a CloneCD image without its .ccd lists one session, then Unpack deletes it

## Problem

When a CloneCD image (`.img`) has no `.ccd` beside it (lost, renamed, not copied), the ISO plug-in
shows "Missing .CCD file. Displayed image could be incomplete." and detects the image as a plain one
(`DetectSectorType`, `CheckForISO`, ...), which lists only the file system at sector 16 of the image -
the first session of a multi-session dump. A whole unpack (Alt+F9) with "Delete archive after
unpacking" then succeeds and deletes the image, losing the later sessions' files. Feature 352 marks
the listing incomplete when a `.ccd` exists but is refused (the image is kept); a missing `.ccd` was
left unchanged on purpose (FR-006: an `.img` without `.ccd` is often a plain disk image).

## Evidence

- `src/plugins/uniso/img.cpp` at the 352 branch: `processCCDFile` returns FALSE when `_wfopen` fails
  (after `Warning(IDS_CCD_MISSING)`) without setting `CCD::Refused`; `ReadSessionCCD` then returns
  FALSE and `CISOImage::Open` (`src/plugins/uniso/isoimage.cpp`) falls back to the plain detection.
- Feature 352's probe row C-NOCCD (`specs/352-uniso-ccd-session-bounds/probe/iso352_probe.ps1`): a
  one-session raw image without `.ccd` - the box, a.txt extracted, the image deleted (correct for
  one session).
- Not measured: a two-session raw image (img352.py kind `ccd_m1m1` without its `.ccd`) - by reading
  it lists only session 1 and is deleted.

## Expected

An `.img` without its `.ccd` whose raw data holds more than the plain detection lists (for example
a second volume descriptor area after the first session's end) marks the listing incomplete, so a
whole unpack fails and the image is kept; a plain single-volume `.img` (disk image, one session)
unpacks and is deleted as today.

## Notes

- Severity 5: data loss needs a lost `.ccd` and a multi-session dump, after a visible warning.
- How to tell "more than listed" cheaply is open (scan for a later sync + volume descriptor, or
  compare the listed volume's size with the file size) - may belong with
  `iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables`.

## Log

- 2026-10-31 — created (source measure:352)
- 2026-10-31 — auto-triage: severity 5 -> 7: a user can lose data in a narrow scenario (lost .ccd + multi-session dump, image deleted by a whole unpack)
- 2026-10-31 — moved to Next position 1
