---
title: Keep Video CD images after a whole unpack until their video extracts whole?
type: decision
status: new
severity: 7
area: archives
source: review:336
who: person
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: S
feature: -
related: [iso-plug-in-video-cd-mpeg-files-in-form-2-sectors-may]
depends-on: []
reason: -
---

# Keep Video CD images after a whole unpack until their video extracts whole?

## Problem

A whole unpack (Alt+F9) of a real Video CD / SVCD image extracts its video files cut - only the first
2048 of each Form 2 sector's 2324 user bytes - with no message, and with "Delete archive after
unpacking" the image is then deleted: the cut-off bytes exist nowhere else. Feature 336 keeps the image
when a Form 2 stream track has no file starting in it, but a stream that `AVSEQnn.DAT` / `AVSEQnn.MPG`
starts in is still taken as extracted (the item 336 implemented wants real Video CDs deleted as before).
The real fix is backlog item `iso-plug-in-video-cd-mpeg-files-in-form-2-sectors-may` (read Form 2 files
with 2324 bytes a sector); this question is only about what happens until then.

## Evidence

- Review 1 of feature 336 (`specs/336-uniso-form2-uncovered/fix-log.md`, *Review*): reviewer 3 of 335's
  real vcdimager 2.0.1 images (`%TEMP%\rev335c\imgs`, made by
  `specs/335-uniso-raw-track-lost/probe/review3/gen335c.py`), probe `rev335c_probe.ps1 -Only
  R-VCD-CCD,R-SVCD-CCD,R-VCD-NRG` on the 336 build: `MPEGAV/AVSEQ01.DAT` (608,256 bytes) equals the first
  2048 bytes of each 2324-byte Form 2 payload; the source `v.mpg` (515,928 bytes, 222 packs) lies whole
  in the payloads, the extracted file misses 276 bytes of every pack (61,272 bytes); the SVCD's
  `AVSEQ01.MPG` misses 39,468 bytes; NRG the same as CCD; the image deleted in all three
  (`specs/336-uniso-form2-uncovered/probe/result_realvcd_review1.txt` - that probe checks sizes only).
- `src/plugins/uniso/rawfs.cpp` `CRawFS::ReadBlockPhys` -> `CISOImage::ReadBlock` (one `SectorUserSize`,
  2048, a track) at the 336 branch; `CISOImage::MarkUncoveredStreams` (feature 336) does not mark a
  covered stream.

## Expected

The maintainer chooses the interim behaviour; the agent implements it (or nothing, if A).

## Question

Until Video CD video files extract whole, should a whole unpack of a Video CD / SVCD image keep the image
(fail closed), or delete it as it does now?

## Options

- **A — keep as now.** Real Video CDs unpack whole and are deleted; the video files are cut (about 12 %
  of every MPEG pack lost) and the image with the full streams is gone. Nothing to implement; raise the
  severity of `iso-plug-in-video-cd-mpeg-files-in-form-2-sectors-may` (measured, data loss with "Delete
  archive after unpacking") and fix it soon.
- **B — fail closed until the fix.** Every Form 2 stream track marks the listing (feature 336's
  `Form2Stream` alone, without the coverage test): a whole unpack of any Video CD / SVCD fails at the end
  and keeps the image even with "Delete archive after unpacking"; the extracted files are the same (still
  cut). Small change (one line plus tests, 335 / 336 probe rows turn); undone by the real fix.
- **C — fix the cut first** (the related item) and leave this decision unneeded.

## Recommendation

C if it can be scheduled next; otherwise B - the standing rule "a safe to delete? check fails closed"
favours keeping the image while the extraction is known to lose bytes. Severity 7: data loss in a
narrow scenario (Video CD images with "Delete archive after unpacking").

## Log

- 2026-10-24 — created (source review:336)
