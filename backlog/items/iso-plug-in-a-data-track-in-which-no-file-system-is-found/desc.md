---
title: ISO plug-in: a data track in which no file system is found lists nothing and is not marked
type: bug
status: new
severity: 7
area: archives
source: measure:334
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: ?
feature: -
related: [iso-plug-in-apfs-original-hfs-and-hfsx-parts-of-a-hybrid-are]
depends-on: []
reason: -
---

# ISO plug-in: a data track in which no file system is found lists nothing and is not marked

## Problem

A disc image with a track table (NRG, CCD/IMG, ...) whose data track shows no file system the ISO
plug-in knows (its volume descriptors at sector 16 destroyed or missing, but the track lies within the
image) is taken as a raw data track: it opens, lists nothing, and does not mark the listing. In a
multi-session image (default "Session NN" folders) Unpack (Alt+F9) with "Delete archive after
unpacking" then extracts the other sessions and deletes the image - the files of that session are
lost. Feature 334 marks such a track only when it lies past the end of the image (nothing of it can be
read); a readable raw data track is left unmarked on purpose, because Video CDs / Super Video CDs carry
legitimate raw (MPEG) data tracks the plug-in never lists, and marking them would make every such
image's whole unpack fail. Tracks of a type the track table does not name (`fsUnknown`) are skipped the
same way.

## Evidence

- `src/plugins/uniso/isoimage.cpp` `CISOImage::Open` at the head of branch `334-uniso-session-missing`:
  `DetectTrackFS` returning `ERR_CONTINUE` -> `FSType = fsData`; feature 334 sets `OutsideImage` only
  when sector 16 is past the image file's end. `src/plugins/uniso/rawfs.cpp` `CRawFS::Open` /
  `ListDirectory` return TRUE and list nothing.
- `CISOImage::ListImage`: `case fsUnknown: // nothing we can do about it`.
- Feature 334's probe `specs/334-uniso-session-missing/probe/iso334_probe.ps1` row M-PAST (a track past
  the end, now kept); a track with destroyed descriptors inside the image was not tried (not verified,
  traced by reading).
- Same family of limits: 330 (a UDF part with a destroyed anchor), 333 (a destroyed HFS+ signature).

## Expected

A raw data track whose content is lost to a whole unpack keeps the image when that can be told apart
from a legitimate raw track (e.g. by the track mode: Video CD MPEG tracks are Mode 2 Form 2, a damaged
ISO 9660 session is Mode 1 / Mode 2 Form 1 - not verified), or the maintainer decides it stays a limit.

## Notes

- A trade-off: marking every raw data track keeps every Video CD after "Delete archive after unpacking"
  (its whole unpack fails although nothing of it was listable before either). If no reliable
  distinction exists, this becomes a decision for the maintainer (as the related APFS item).

## Log

- 2026-10-24 — created (source measure:334)
