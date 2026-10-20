---
title: PictView: no Exif command and no automatic turn for TIFF and camera raw files
type: improvement
status: open
severity: 2
area: pictview
source: leftover:267
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: M
feature: -
related: [pictview-update-thumbnail-142-leftovers]
depends-on: []
reason: -
---

# PictView: no Exif command and no automatic turn for TIFF and camera raw files

## Problem

Since feature 267 PictView offers its Exif information command and turns a picture by its Exif
orientation only for JPEG files. A TIFF file with an orientation tag (and camera raw files that the
system decoder opens) is shown as stored and the Exif command stays unavailable, although the old
engine handled TIFF (the Exif window reads a TIFF's tags by itself, `CExifDialog` "fake APP1"
branch, and the old auto-rotation had a TIFF branch on engine flags the WIC engine never sets).
267 left other formats alone on purpose (the item asked for JPEG).

## Evidence

- Feature 267 (`specs/267-pictview-exif-rotate/spec.md` Clarifications, FR-009; fix-log
  section 6): probe row `tif6` of `probe/pv267_probe.ps1` - a TIFF with Orientation 6 is shown
  64 x 48 (as stored) and gives no Exif dialog, before and after 267 (Pillow itself turns that
  TIFF on load).
- At commit b3af924f: `src/plugins/pictview/wicengine.cpp` `WicOpenImageEx` sets `HasExif` only
  for `PVF_JPG` (`JpegFrameHasExif`, query `/app1/ifd`); `src/plugins/pictview/render1.cpp`
  WM_PAINT auto-rotation gate `pvii.Format == PVF_JPG`; `dialogs.cpp` `CExifDialog::DialogProc`
  reads the first 60000 bytes of a TIFF as an Exif block (Olympus ORF header fix-up).
- The WIC orientation query `WicGetExifOrientation` already tries `/ifd/{ushort=274}` (the
  TIFF-family root) after the JPEG path.

## Expected

A TIFF (and a raw file the system decoder opens) with an Exif / TIFF orientation tag is shown
turned as the tag says with auto-rotation on, and its Exif command is available when it has an
Exif sub-IFD; a probe row like `tif6` shows it; JPEG behaviour unchanged.

## Approach

Measure first what WIC's TIFF decoder does with tag 274 (it may already apply it for some
formats - then turning again would be wrong), and which raw formats this machine's decoders open.
Decide "has Exif" for TIFF by `/ifd/exif` (an Exif sub-IFD) rather than any IFD0.

## Notes

Low importance: TIFF files with a non-default orientation are rare outside camera raw files.
Related to `pictview-update-thumbnail-142-leftovers` only as another PictView Exif leftover.

## Log

- 2026-10-20 — created (source leftover:267)
- 2026-10-20 — moved to Next position 76
