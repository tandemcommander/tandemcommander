---
title: Check feature 356 with real UDF-only disc images (Blu-ray, DVD, packet-written CD-R)
type: person-step
status: new
severity: 3
area: archives
source: leftover:356
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

# Check feature 356 with real UDF-only disc images (Blu-ray, DVD, packet-written CD-R)

## Problem

Feature 356 marks the listing of a cooked UDF-only disc image (no ISO 9660 descriptor at sector 16)
incomplete when the file does not end with the volume's own closing anchor (or, for a VAT volume, its VAT)
and holds more than 16 sectors past the volume's descriptors that are not zero bytes or the volume's own
anchors - a whole unpack with "Delete archive after unpacking" then keeps the image. It was measured with
images written by Windows' IMAPI2FS and by mkudffs (both real tools) and composed ones; no real Blu-ray
image, UDF-only DVD image or dump of a packet-written CD-R / DVD-R existed on the machine. Where such a
real image puts its last anchor (every measured one at its last sector) was not seen.

## Evidence

- `specs/356-uniso-udf-rest/fix-log.md` (*Where a UDF volume ends*, *Probes*, *Review*); probe
  `specs/356-uniso-udf-rest/probe/iso356_probe.ps1`; a quick check of any image without the program:
  `python -I specs/356-uniso-udf-rest/probe/rule356.py <image>` (KEEP = deleted after a whole unpack,
  MARK = kept).
- `src/common/salisotrack.h` (`SalIsoUdfRestDecision`, `SalIsoUdfClosesFile`),
  `src/plugins/uniso/isoimage.cpp` (`CISOImage::UdfRestMarks`).

## Expected

A real one-volume UDF-only image (a Blu-ray `.iso`, a UDF-only DVD image, a closed packet-written disc)
unpacks whole and is deleted with "Delete archive after unpacking"; the same image with another image
appended (`copy /b a.iso + b.iso c.iso`) is kept.

## Steps

- [ ] With a build carrying feature 356, run `python -I specs/356-uniso-udf-rest/probe/rule356.py` on a
  real UDF-only image (a Blu-ray movie or data disc `.iso`; check first that it is UDF only:
  `python -I specs/356-uniso-udf-rest/probe/udfmeasure.py <image>` prints `sector16: b'\x00BEA01'`, not
  `b'\x01CD001'`): expected KEEP
  ("closed at end"). If it prints MARK, record the line and the image's size in a new backlog item.
- [ ] Copy that image into an empty folder, select it, Alt+F9 (Unpack), tick "Delete archive after
  unpacking", OK: expected every file extracted and the image deleted. (A UDF 2.50 image that does not
  list at all is the known item `iso-plug-in-a-udf-2-50-image-written-by-windows-imapi2fs`.)
- [ ] Join two UDF-only images in a command prompt (`copy /b first.iso + second.iso joined.iso`) and
  unpack `joined.iso` the same way: expected the first image's files extracted and `joined.iso` KEPT.

## Log

- 2026-10-31 — created (source leftover:356)
