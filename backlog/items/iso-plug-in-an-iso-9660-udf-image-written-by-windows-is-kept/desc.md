---
title: ISO plug-in: an ISO 9660 + UDF image written by Windows is kept after a whole unpack
type: bug
status: new
severity: 4
area: archives
source: measure:378
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: S
feature: -
related: [check-feature-356-with-real-udf-only-disc-images-blu-ray-dvd]
depends-on: []
reason: -
---

# ISO plug-in: an ISO 9660 + UDF image written by Windows is kept after a whole unpack

## Problem

A well-formed disc image with both ISO 9660 and UDF written by Windows' own image writer IMAPI2FS
(`FileSystemsToCreate = 5`, UDF 2.01) unpacks whole - both parts' folders `ISO (<label>)` and
`UDF (<label>)` are extracted, no window is shown - but with "Delete archive after unpacking" the image is
**kept**, silently: its listing is marked incomplete. Its ISO 9660 primary volume descriptor gives a volume
of 297 sectors, the file holds 576 (the UDF part's sectors lie past the ISO 9660 volume), and the rest rule
for data past a volume takes them as unread data. Nothing is lost (it fails closed), but the option does not
work for such images and nothing tells the user why.

## Evidence

- Measured by feature 378 (`specs/378-uniso-udf-partition-maps/fix-log.md`, *Measurement at HEAD*): probe
  `specs/378-uniso-udf-partition-maps/probe/iso378_probe.ps1`, row `C-B201` - HEAD 514396d3 and the
  feature's build alike: `ISO (UDF356)/A.TXT`, `UDF (UDF356)/a.txt`, no window, image kept. Seed by
  `specs/356-uniso-udf-rest/probe/imapiudf356.ps1 -FileSystems 5 -Revision 0x201` (1179648 bytes = 576
  sectors; PVD volume space size at sector 16 byte 80 = 297).
- The mark comes from `CISOImage` opening the track (`src/plugins/uniso/isoimage.cpp` at 514396d3, the
  "a cooked image of ... bytes past a volume of ... sectors" branch, rules in `src/common/salisotrack.h`,
  features 353 - 355); feature 356's UDF-only rule (`UdfRestMarks`) runs only without an ISO 9660
  descriptor (`!iso9660`). Which branch marks it was not traced in a debugger (not verified).

## Expected

An ISO 9660 + UDF image whose bytes past the ISO 9660 volume are the UDF volume's own sectors (up to its
closing anchor / the end of the UDF volume) unpacks whole and is deleted with "Delete archive after
unpacking"; an image with foreign data appended past both volumes is still kept.

## Notes

- Related to `check-feature-356-with-real-udf-only-disc-images-blu-ray-dvd` (356's rule for UDF-only
  images); this is the bridge case, which that rule does not reach.
- Severity 4: the option fails closed (no data lost), a workaround exists (delete by hand).

## Log

- 2026-11-01 — created (source measure:378)
