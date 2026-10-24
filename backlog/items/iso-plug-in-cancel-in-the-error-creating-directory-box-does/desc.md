---
title: ISO plug-in: Cancel in the Error Creating Directory box does not stop a whole unpack
type: bug
status: open
severity: 3
area: archives
source: review:338
who: agent
created: 2026-10-24
updated: 2026-10-24
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# ISO plug-in: Cancel in the Error Creating Directory box does not stop a whole unpack

## Problem

When a folder of a disc image cannot be created during Unpack (Alt+F9) - e.g. the target holds a file of
that name - the core's "Error Creating Directory" box offers only Retry / Cancel. Cancel there does not stop
the unpack: the plug-in goes on with the folder's files (each meets its own error box) and the rest of the
image. Since feature 338 the unpack then fails and the image is kept, but the user's Cancel is ignored.

## Evidence

- Review 1 of feature 338 (`specs/338-uniso-skip-fails-unpack/fix-log.md`, section *Review*, NOTE) and
  probe `specs/338-uniso-skip-fails-unpack/probe/iso338_probe.ps1` row D-SKIP (the box is closed, the next
  box for z.txt follows).
- At c99f39e5 `src/plugins/uniso/isoimage.cpp` `CISOImage::UnpackDir`: `CheckAndCreateDirectory` FALSE ->
  `UNPACK_ERROR`, never `UNPACK_CANCEL` (the core's call does not say whether Cancel was pressed).

## Expected

Cancel in that box stops the whole unpack (as Cancel in the plug-in's own boxes does); Retry and the other
answers as now. Measured first with D-SKIP answered Cancel.

## Notes

- Not verified whether `CheckAndCreateDirectory` can report Cancel to a plug-in at all; the plug-in may need
  its own `SafeFileCreate(..., isDir TRUE, ...)` call (which reports Skip / Cancel) instead.

## Log

- 2026-10-24 — created (source review:338)
- 2026-10-24 — moved to Next position 79
