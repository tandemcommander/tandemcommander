# Tasks: PictView - the Exif dialog and Exif auto-rotation with the built-in engine

**Input**: `specs/267-pictview-exif-rotate/` - plan.md, spec.md, research.md, quickstart.md
**Tests**: the pure rule gets `saltests` checks (FR-006, standing rule); the behaviour is proved
by the hidden-desktop probe `probe/pv267_probe.ps1`.

## Phase 1: Setup

- [X] T001 Measure before: run `probe/pv267_probe.ps1` on the build of `main` and keep the result in specs/267-pictview-exif-rotate/probe/result_before.txt; record the real-set facts (`probe/real267.py`, `probe/real267_wic.ps1`) in specs/267-pictview-exif-rotate/probe/real_own.txt and real_wic.txt (done during measuring; check the files are there)

## Phase 2: Foundational (blocks both stories)

- [X] T002 Engine reports the Exif block: add `BOOL HasExif` to `CWicImage`, set it in `WicOpenImageEx` for `PVF_JPG` with a decoder (frame 0 metadata query reader, `GetMetadataByName(L"/app1/ifd")` succeeds), and make `FillInfo` report `PVFF_EXIF` when set, in src/plugins/pictview/wicengine.cpp
- [X] T003 Keep Update Thumbnail's decision feature 132's own: the JFXX question asks `!ThumbFileHasExif(path)` alone (comment: the engine flag must not skip the file check) in src/plugins/pictview/thumbs.cpp

## Phase 3: User Story 1 - A photo is shown the right way up (P1)

**Independent test**: probe rows o1..o8, o6-nodims, o6-moddims, noexif, xmp, uni, off and the
real-* rows (ROT) pass.

- [X] T004 [P] [US1] Pure rule `SalExifOrientTurn(int orient)` -> `CSalExifTurn { int Quarter (0, +1 clockwise, -1 counter-clockwise); bool MirrorHor; bool MirrorVert; }` (turn first, then mirrors; values outside 1..8 = nothing), header-only, in src/common/salexiforient.h
- [X] T005 [P] [US1] `TestExifOrient267` in src/saltests/saltests.cpp: the table of research R4 for 0..9 and -1, 255; and for every value the composition of the result applied to a 3 x 2 grid equals the standard's mapping (tag value -> where stored row 0 / column 0 belong); add the header to src/vcxproj/saltests/saltests.vcxproj and call the test from main
- [X] T006 [US1] Auto-rotation in WM_PAINT: gate `FileName != NULL && pvii.Format == PVF_JPG && (pvii.Flags & PVFF_EXIF) && G.AutoRotate`; orientation from `WicGetExifOrientation(PVHandle)`; turn by `SalExifOrientTurn`; when anything is to be done read the image without painting (as before) and post the turn command first, then the mirrors (both mirrors without a turn = `CMD_ROTATE180`); no EXIF.DLL, no recorded-size rule, in src/plugins/pictview/render1.cpp

## Phase 4: User Story 2 - The Exif command shows the photo's tags (P2)

**Independent test**: probe rows (EXIF) - the Exif dialog opens with the tags (Orientation among
them) exactly for files with an Exif block.

- [X] T007 [US2] Check that the handler `CMD_IMG_EXIF` (src/plugins/pictview/render1.cpp) and the enabler `vweImgExifAvailable` (src/plugins/pictview/pictview.cpp) need no change once the engine reports `PVFF_EXIF` (they read the flag; the dialog reads the file through `EXIFGetInfoW`); record in fix-log.md

## Phase 5: Polish & verification

- [X] T008 Encoding guard `python tools/check_encoding.py --strict`, `build.cmd`, `saltests.exe`; record numbers in specs/267-pictview-exif-rotate/fix-log.md
- [X] T009 Probe after: `probe/pv267_probe.ps1` with `-RealRoot` on the hidden desktop -> specs/267-pictview-exif-rotate/probe/result_after.txt, every row PASS; the probe has a row `tif6` (a TIFF with Orientation 6: as stored, no Exif dialog - FR-009); the clipboard / scanner case is recorded as reviewed by code (no decoder, no file name)
- [X] T010 Regressions: `specs/120-pictview-leftovers/probe/pv120_probe.ps1` and `specs/132-pictview-thumbnail-verify/probe/thumb132_probe.ps1` on the new build -> results in specs/267-pictview-exif-rotate/probe/, no new FAIL
- [X] T011 Negative control: the probe's rows fail when the rule is broken on purpose (e.g. the old table for 4/5/7) - recorded in fix-log.md, the change reverted
- [X] T012 Owed to a person (NOT DRIVEN): the menu items (File, context menu) enabled / grayed - recorded in fix-log.md

## Dependencies

T002 blocks T006 and T007 (the flag opens the gates). T004 -> T005, T006. T003 is independent.
US1 and US2 share only T002. T008-T012 after T006/T007.

## Parallel opportunities

T003, T004 and T005 touch different files and can be written in parallel with T002.

## Implementation strategy

MVP = Phase 2 + US1 (the turn is the visible gain); US2 is open as soon as T002 is in.
