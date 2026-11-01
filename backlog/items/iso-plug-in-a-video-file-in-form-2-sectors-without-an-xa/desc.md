---
title: ISO plug-in: a video file in Form 2 sectors without an XA Form 2 attribute extracts cut
type: bug
status: open
severity: 7
area: archives
source: review:366
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: 2026-11-01 56a44fba
effort: M
feature: -
related: [keep-video-cd-images-after-a-whole-unpack-until-their-video]
depends-on: []
reason: -
---

# ISO plug-in: a video file in Form 2 sectors without an XA Form 2 attribute extracts cut

## Problem

Feature 366 reads a file 2324 bytes a sector only when its ISO 9660 record carries a CD-XA attribute that
says Form 2 (and not Form 1) and its first sector is a Form 2 sector. A file stored in Form 2 sectors that
does not meet this - no XA record (a plain ISO 9660 directory pointing into a Video CD's stream, 335's
X-VCDFILE), mixed attributes 0x3D55 (Form 1 + Form 2, as interleaved game streams), or a Form 1 first sector
followed by Form 2 sectors - is still read 2048 bytes a sector: 276 bytes of each sector are lost without a
message. Feature 337's coverage counts such a file's sectors as extracted, so the gap check never reads their
2324-byte data, and a whole Unpack with "Delete archive after unpacking" deletes the image afterwards - the
only copy of the full stream.

## Evidence

- Review 1 of feature 366 (`specs/366-uniso-form2-files/fix-log.md`, *Review*, SHOULD-1):
  `src/plugins/uniso/isoimage.cpp` `CISOImage::NoteListedFileStarts` at branch `366-uniso-form2-files` - a
  file without `CFilePos::Form2` adds the span `SalIsoFileSectorSpan(..., 2048)` in a `Form2Stream` track.
- Probe `specs/366-uniso-form2-files/probe/iso366_probe.ps1` (images `img366.py` from real vcdimager 2.0.1
  output): rows C-NOXA (AVSEQ01's XA signature destroyed), C-MIXED (attributes 0x3D55), C-F1SUB (AVSEQ02's first
  sector Form 1) - the file extracts as 608,256 bytes (61,272 bytes lost) and the image is deleted
  (`probe/result_after_review1.txt`); `main` does the same (`probe/result_negative_main.txt`).
- Review 2 of feature 335 (X-VCDFILE): a crafted CloneCD image whose `a.txt` record (no XA) points into Form 2
  sectors.

## Expected

Such a file is either read whole (2324 bytes of each Form 2 sector, decided per sector by its subheader, with
a listed size that matches), or - when that cannot be decided at listing - its stream sectors do not count as
extracted: a file in a `Form2Stream` track that is not read as Form 2 adds no span, the gap check reads those
sectors, finds data, and the listing is marked (a whole Unpack fails, the image is kept). Files of a plain data
disc, the Form 1 files of a Video CD and 366's Form 2 files unchanged.

## Notes

- Reviewer's suggestion: in `NoteListedFileStarts`, a non-Form-2 file in a stream track adds no span.
- The decision item `keep-video-cd-images-after-a-whole-unpack-until-their-video` asks the maintainer for the
  interim behaviour of exactly these images (feature 366 made its option C true for files with an XA Form 2
  attribute); after 366 its scope is only the files this item names. Decide it before implementing the
  fail-closed variant.
- Mixed files with per-sector forms need a size that is known only after reading every subheader of the file.

## Log

- 2026-11-01 — created (source review:366)
- 2026-11-01 — auto-triage: severity 5 -> 7: data loss in a narrow scenario - 276 bytes of each Form 2 sector lost and the image deleted by a whole Unpack with Delete archive after unpacking (images without an XA Form 2 attribute)
- 2026-11-01 — moved to Next position 1
- 2026-11-01 — verified at 56a44fba: reproduced at 56a44fba: iso366_probe rows C-MIXED, C-NOXA, C-F1SUB extract the video file as 608,256 bytes (2048-byte read), image deleted
