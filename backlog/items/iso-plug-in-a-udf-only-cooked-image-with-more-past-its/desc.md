---
title: ISO plug-in: a UDF-only cooked image with more past its volume is still deleted by Unpack
type: bug
status: new
severity: 5
area: archives
source: leftover:354
who: agent
created: 2026-10-31
updated: 2026-10-31
verified: -
effort: M
feature: -
related: [iso-plug-in-a-cooked-multi-session-image-lists-one-session]
depends-on: []
reason: -
---

# ISO plug-in: a UDF-only cooked image with more past its volume is still deleted by Unpack

## Problem

A cooked disc image (2048-byte sectors) whose sector 16 holds no ISO 9660 descriptor - a UDF-only image,
its volume recognition sequence (`BEA01`, `NSR02` / `NSR03`) starting at sector 16 - is listed by the
ISO plug-in from its UDF descriptors only. When such a file holds a later session (UDF multi-session, or
two UDF images joined) or other data past the UDF volume, a whole Unpack (Alt+F9) with "Delete archive
after unpacking" still succeeds and deletes the image with the data the listing does not cover. Feature
354 marks the listing incomplete for a cooked image with an ISO 9660 primary descriptor at sector 16 only:
it needs the volume's size, which a UDF-only image gives only through its UDF descriptors.

## Evidence

- Feature 354 (`specs/354-uniso-cooked-sessions/spec.md`, *Clarifications* and *Assumptions*; fix-log
  *Implementation*): `SalIsoCookedRestDecision` (`src/common/salisotrack.h`) returns
  `SAL_ISO_REST_KEEP_LISTING` when `iso9660` is false; `CISOImage::Open`, the plain branch's
  `cookedIso` block (`src/plugins/uniso/isoimage.cpp`) sets `iso9660` from `IsValidCDHeader` at sector 16.
- Not measured: no UDF-only image was made (no `mkudffs` in the WSL tools used by 354).

## Expected

A UDF-only cooked image whose file holds more than a few sectors past the UDF volume (its last sector,
from the anchor volume descriptor pointer / partition descriptor) and whose rest is not zero bytes only
marks the listing incomplete, by the same rule as feature 354 (`SAL_ISO_LATER_VOLUME_SECTOR`,
`SAL_ISO_ZERO_REST_SECTORS`); a plain one-volume UDF image (for example a Blu-ray image) unpacks and is
deleted as today - measured with a crafted image (`mkudffs`, or a UDF image joined with another) before
and after.

## Notes

- The end of a UDF volume: the anchor at sector 256 and at the last sector (or last - 256) of a closed
  disc; the partition's start + length; the reserve descriptor sequence. Which of them marks "the end"
  without false positives on real images is the item's first measurement.
- Related to `iso-plug-in-a-cooked-multi-session-image-lists-one-session` (feature 354, the ISO 9660 case).

## Log

- 2026-10-31 — created (source leftover:354)
