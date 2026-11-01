---
title: ISO plug-in: listing a disc image reads every sector of examined Form 2 files
type: improvement
status: open
severity: 3
area: archives
source: review:367
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: listing a disc image reads every sector of examined Form 2 files

## Problem

Feature 367 examines, at every listing of a disc image, each ISO 9660 file stored in Form 2 sectors that has no
XA Form 2 attribute (in a Form 2 stream track, with the XA Form 2 bit - also mixed Form 1 + Form 2 - or with a
Form 2 first sector): it reads the stored sector of every sector the file's record spans, to decide its listed
size. There is no cap and no cancel (the spec's clarification chose "no limit" so that long files are not left
cut). The cost is paid again at every listing (opening the image, refreshing the panel), and:

- interleaved game discs (PlayStation-like movie / audio files with the XA Form 2 bit) have those files read in
  full at each listing - possibly hundreds of MB;
- several directory records pointing at one large extent (a crafted or damaged image) multiply the reads.

Nothing is lost; the listing may be slow. Not measured.

## Evidence

- Review 1 of feature 367 (`specs/367-uniso-form2-unmarked/fix-log.md`, *Review*, NOTE 1).
- `src/plugins/uniso/isoimage.cpp` `CISOImage::ExamineFileSectors` (branch `367-uniso-form2-unmarked`): one
  24-byte read of the first sector for any file on a track that stores Form 2 data, then, for an examined file,
  every stored sector 64 at a time; called from `CISO9660::AddFileDir` (`src/plugins/uniso/iso9660.cpp`) for every
  file record of `ListDirectoryRe` at every listing.
- `specs/367-uniso-form2-unmarked/spec.md` *Clarifications* (no limit) and SC-005 (only files not examined are
  cheap).

## Expected

Measure first: list an image with a large examined file (e.g. a real interleaved game disc dump, or a Video CD
image whose AVSEQ records lack the XA record) and time the listing against main. If it is noticeably slow:
remember each examined (extent, length) result for the image's lifetime (a duplicated record costs nothing
more; a re-listing of the same open image reuses it), or decide lazily - without ever listing a size the unpack
does not write, and without letting a stream count as extracted before its sectors were examined (the rules of
features 337 and 367 stay).

## Notes

- Severity 3: performance only; no data at risk (unsure -> the lower value).
- Related to the item 367 implemented (`iso-plug-in-a-video-file-in-form-2-sectors-without-an-xa`), which is
  removed when 367 closes.

## Log

- 2026-11-01 — created (source review:367)
- 2026-11-01 — set title=ISO plug-in: listing a disc image reads every sector of examined Form 2 files
- 2026-11-01 — related item iso-plug-in-a-video-file-in-form-2-sectors-without-an-xa done in feature 367
- 2026-11-01 — moved to Next position 86
