---
title: ISO plug-in: a cooked multi-session image lists one session, then Unpack deletes it
type: bug
status: in-progress
severity: 7
area: archives
source: review:353
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: 2026-10-31 64e207ca
effort: S
feature: 354
related: [iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables]
depends-on: []
reason: -
---

# ISO plug-in: a cooked multi-session image lists one session, then Unpack deletes it

## Problem

A disc image of 2048-byte sectors (a "cooked" `.iso` or `.img`, for example a `dd` copy of a
multi-session disc) that holds a second session after the first is detected as a plain image: the ISO
plug-in lists only the file system whose volume descriptor is at sector 16 - the first session. A whole
Unpack (Alt+F9) with "Delete archive after unpacking" then succeeds and deletes the image, and the later
session's files are lost. Feature 353 marks this for raw (2352-byte) `.img` files whose `.ccd` is missing;
cooked images were left unchanged on purpose (353's FR-003: a 2048-byte `.img` is a plain disk image).

## Evidence

- Review 1 of feature 353 (`specs/353-uniso-noccd-sessions/fix-log.md`, *Review*): rows X-COOKED2IMG and
  X-COOKED2ISO of the reviewer's probe - feature 334's `s1.iso` + `s2.iso` (session 2 addressed after
  session 1) joined into one file named `.img` / `.iso`: a.txt extracted, the image deleted, b.txt lost,
  at the 353 branch.
- The plain detection: `CISOImage::Open`, the branch without a track table (`DetectSectorType`,
  `CheckForISO`, ...), `src/plugins/uniso/isoimage.cpp`; 353's rule `SalIsoNoCcdRestMarks`
  (`src/common/salisotrack.h`) applies only to a raw start and a missing `.ccd`.

## Expected

A cooked image whose file holds room for a later volume past the listed volume (more than 16 sectors -
353's `SAL_ISO_LATER_VOLUME_SECTOR`) marks the listing incomplete, so a whole unpack fails and the image
is kept; a plain one-volume `.iso` / `.img` (file size equal to the volume, or a few sectors more) unpacks
and is deleted as today.

## Notes

- Not every cooked image with a tail is multi-session: ISO files padded by authoring tools, hybrid images
  with a partition table, or UDF volumes larger than the ISO 9660 bridge's size may have more sectors than
  the ISO 9660 volume - measure how common that is before choosing the rule (a kept image loses nothing,
  but every `.iso` kept after a whole unpack would be a visible change).
- Related to `iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables` (reading the sessions).

## Log

- 2026-10-31 — created (source review:353)
- 2026-10-31 — auto-triage: severity 5 -> 7: a user can lose data in a narrow scenario (a multi-session cooked image unpacked whole with Delete archive after unpacking loses the later session), band 7-8, as the raw-image item of 353
- 2026-10-31 — moved to Next position 1
- 2026-10-31 — verified at 64e207ca: reproduced at 64e207ca: iso354_probe R-TWOISO / R-TWOIMG (s1+s2 cooked, joined) - a.txt extracted, image deleted, b.txt lost
- 2026-10-31 — run started, feature 354
