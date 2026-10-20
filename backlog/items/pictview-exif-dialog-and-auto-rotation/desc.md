---
title: PictView: the Exif dialog and auto-rotation never work with the built-in engine
type: feature
status: in-progress
severity: 3
area: pictview
source: leftover:132
who: agent
created: 2026-10-13
updated: 2026-10-20
verified: 2026-10-20 b6b60a51
effort: L
feature: 267
related: [pictview-update-thumbnail-142-leftovers]
depends-on: []
reason: -
---

# PictView: the Exif dialog and auto-rotation never work with the built-in engine

## Problem

The viewer's Exif dialog and Exif auto-rotation are dead for the same reason Regenerate thumbnail was before feature 132: the built-in engine never reports `PVFF_EXIF`, and both are gated on it. Switching them on is a feature of its own.

## Evidence

Migrated from specs/NEXT-WORK.md §A item 7 (L256) (at 7993914c). specs/132-pictview-thumbnail-verify/fix-log.md ("The viewer's Exif dialog and Exif auto-rotation are dead for the reason the command was"). At 7993914c: `src/plugins/pictview/render1.cpp` ~1691 (auto-rotation: `(pvii.Flags & PVFF_EXIF) && G.AutoRotate`), ~4474 (Exif dialog), `pictview.cpp` ~2369 (`vweImgExifAvailable`); 132 worked around it for the thumbnail with `ThumbFileHasExif` (`thumbs.cpp` ~83, ~510).

## Expected

For a JPEG with an Exif block the Exif command is enabled and shows the tags, and with auto-rotation on a picture is turned by its orientation tag.

## Approach

Either make the engine report `PVFF_EXIF` or gate both on a file check like 132's `ThumbFileHasExif`; measure with real camera files (135's set) and with files without Exif.

## Log

- 2026-10-17 — migrated from specs/NEXT-WORK.md §A (code work) (feature 242)
- 2026-10-20 — verified at b6b60a51: reproduced at b6b60a51: hidden-desktop probe pv267, 21 FAIL - no Exif dialog for files with Exif, orientations 2-8 not turned; wicengine FillInfo sets Flags 0
- 2026-10-20 — run started, feature 267
