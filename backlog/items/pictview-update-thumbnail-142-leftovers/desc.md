---
title: PictView Update Thumbnail: file time, hard links, per-file box, orientation
type: improvement
status: open
severity: 3
area: pictview
source: leftover:142
who: agent
created: 2026-10-14
updated: 2026-10-17
verified: -
effort: M
feature: -
related: [pictview-own-photos-pipette-histogram-print]
depends-on: []
reason: -
---

# PictView Update Thumbnail: file time, hard links, per-file box, orientation

## Problem

Feature 142 left these open around PictView's Update Thumbnail: (1) the update changes the picture's modification time (the creation time stays) - keeping it would be a decision, since a sync tool would then miss the change; (2) the update splits the picture from its other hard links (they keep the old content; ReplaceFileW), and when the read-only attribute was cleared for the replace the old content loses it; (3) a failed save of the thumbnail image (PVSaveImage) is still an OK-only box per file (IDS_SAVEERROR, thumbs.cpp near the end of the loop) - the 'one box per file' pattern 142 converted elsewhere to Skip / Skip all / Cancel (ThumbWriteFailed); (4) EXIFGetOrientationInfo has no wide twin (its caller is render1.cpp), so the orientation of a picture whose name is outside the code page is read through the code-page export.

## Evidence

Migrated from specs/NEXT-WORK.md header, 'Before 0.1.10 - steps owed to a person' point 1, 'Left by 142' (at 7993914c). Detail: specs/142-pictview-thumb-unicode/impl-notes.md section 5 (a) modification time, (b) hard links, (c) missing messages (~lines 100-111) and section 6 'Not done' (~line 117, EXIFGetOrientationInfo). Code: src/plugins/pictview thumbs.cpp (IDS_SAVEERROR box), render1.cpp (EXIFGetOrientationInfo caller), exif/exif.def (exports with fixed ordinals since 142).

## Expected

A failed thumbnail save offers Skip / Skip all / Cancel like ThumbWriteFailed; EXIFGetOrientationInfo has a wide twin appended (ordinals of the old exports unchanged, as 142 measured with dumpbin) and render1.cpp uses it; the maintainer's decision on modification time and hard links is recorded and implemented or written down as the intended behaviour.

## Approach

Measure first that each point still holds at HEAD. Points (1) and (2) need a maintainer decision before code (keep the time? replace in place for hard-linked files?) - ask, do not decide. EXIF.DLL exports: append only, keep the written-out ordinals @1-@8.

## Notes

Of the same 'Left by 142' sentence, the Exif information window opened only for PVFF_EXIF, which the built-in engine never sets, is the item `pictview-exif-dialog-and-auto-rotation`; the refused file's "Disk full?" text is part of this item (below). 142's impl-notes also record that pvii.Width == 0 would divide by zero and that GetErrorText(tmpErr) with error 0 would read 'completed successfully' - not in NEXT-WORK; check them while here. Unsure whether later features (after 142) touched any of these; a verify settles it.

Also here (NEXT-WORK §A item 7): a refused Update Thumbnail says "Disk full?". Since feature 132 Update Thumbnail refuses a file it could not rewrite without loss (e.g. 8 fill bytes, a big Exif block), but the refusal shows the write-failure text "Unable to create a file with the new thumbnail. Disk full? The old file '%s' remains unmodified." - the user is told about a full disk that is not the reason. A sentence of its own needs a new string. Evidence: Migrated from specs/NEXT-WORK.md §A item 7 (L258) (at 7993914c). String `IDS_REGENERATE_THUMB_WRITEFILE` in `src/plugins/pictview/lang/lang.rc2` ~661; the "skip all" exists since feature 142 (`ThumbWriteFailed`). specs/132-pictview-thumbnail-verify/fix-log.md (probe rows "8 fill bytes, big Exif: unchanged + message"). Expected: A refused file gets a message that says it was left unchanged because the thumbnail could not be replaced safely; a real write failure keeps the existing text; the "skip all" still works.

## Log

- 2026-10-15 — NEXT-WORK corrected: the "skip all" is there since feature 142 (ThumbWriteFailed)
- 2026-10-17 — migrated from specs/NEXT-WORK.md header and §B (person steps) (feature 242)
- 2026-10-17 — migration review N3: cross-references to final slugs, merge remark reworded
