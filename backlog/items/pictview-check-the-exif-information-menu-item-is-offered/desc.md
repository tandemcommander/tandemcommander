---
title: PictView: check the Exif information menu item is offered only for photos with Exif
type: person-step
status: new
severity: 2
area: pictview
source: leftover:267
who: person
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# PictView: check the Exif information menu item is offered only for photos with Exif

## Problem

Feature 267 made PictView's File > Exif information command work with the built-in engine: the
command (File menu and the viewer's context menu; it has no toolbar button) is enabled exactly for
a JPEG with an Exif block. The hidden-desktop probe drives the command itself (the Exif window
opens with the tags exactly for the files with Exif) but cannot read whether the custom menu shows
the item enabled or grayed.

## Evidence

Feature 267: `specs/267-pictview-exif-rotate/fix-log.md` section "Not driven - owed to a person";
`specs/267-pictview-exif-rotate/quickstart.md` step 5. The enabler is
`src/plugins/pictview/pictview.cpp` `vweImgExifAvailable` (reads `PVFF_EXIF`, the flag the
command handler reads).

## Expected

The menu item is enabled for a photo with Exif and grayed for a picture without; both steps below
pass on a build that carries feature 267.

## Steps

- [ ] Open a phone or camera photo (a JPEG with Exif) in PictView (F3): File > Exif information is
      enabled, and choosing it opens the Exif window listing the photo's tags (camera, date,
      Orientation, ...). The same item in the viewer's right-click menu is enabled too.
- [ ] Open a JPEG without Exif (for example one saved by Paint, or a PNG): File > Exif information
      is grayed in the File menu and in the right-click menu.
- [ ] Open a photo taken with the camera held upright: it is shown the right way up (PictView's
      configuration: "Autorotate EXIF JPEG images" on, the default).

## Log

- 2026-10-20 — created (source leftover:267)
