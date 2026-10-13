# Tasks: feature 132 - PictView's Update Thumbnail keeps the picture

## Phase 1: Setup

- [X] T001 Branch `132-pictview-thumbnail-verify`, `specs/132-pictview-thumbnail-verify/spec.md`, `plan.md`, `research.md`

## Phase 2: Foundational - measure first

- [X] T002 Library measurement `specs/132-pictview-thumbnail-verify/probe/exifdll_measure.py` on the EXIF.DLL of 0.1.9 (`probe/exifdll_result_before_v019.txt`)
- [X] T003 Probe `specs/132-pictview-thumbnail-verify/probe/thumb132_probe.ps1`; first run in the program (finding: the command is dead, research R2)

## Phase 3: User Story 3 - a file that cannot be updated safely is left alone (P1)

- [X] T004 [US3] The rule `src/common/saljpegkeep.h` (`SalJpegRewriteKeepsFile`) with checks in `src/saltests/saltests.cpp` (`TestJpegKeep132`), `src/vcxproj/saltests/saltests.vcxproj`
- [X] T005 [US3] `src/plugins/pictview/thumbs.cpp`: `ThumbNewFileKeepsOriginal` before the replace
- [X] T006 [US3] `src/plugins/pictview/exif/libjpeg/jpeg-data.c`, `jpeg-data.h`: incomplete data and oversized blocks fail the save

## Phase 4: User Story 2 - nothing but the thumbnail changes (P1)

- [X] T007 [US2] `src/plugins/pictview/exif/libjpeg/jpeg-data.c`: an APP1 that is not Exif is kept; the end marker by both bytes

## Phase 5: User Story 1 - the command works (P1)

- [X] T008 [US1] `src/plugins/pictview/wicengine.cpp`: `WicSaveJpegThumbnail`
- [X] T009 [US1] `src/plugins/pictview/thumbs.cpp`: `ThumbFileHasExif` (`SalJpegHasExif` in `src/common/saljpegkeep.h`, checks in `src/saltests/saltests.cpp`)

## Phase 6: Verify

- [X] T010 Probe in the modes fixed, oldlib and before (0.1.9); `probe/check_outputs.py` on the kept files; library measurement on the new build (`probe/exifdll_result.txt`)
- [X] T011 Independent refute-first review; fixes
- [X] T012 `build.cmd full`, `build.cmd full release`, `saltests`, `tools/check_encoding.py`; regression probes 105, 111, 120, 130
- [X] T013 `fix-log.md`, `quickstart.md`, `CHANGELOG.md`, `specs/FEATURE-HISTORY.md`, `specs/NEXT-WORK.md`, `issues/PROGRESS.md`; local commit
