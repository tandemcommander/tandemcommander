# Tasks: feature 142 - PictView, Update Thumbnail and Exif information for any file name

## Phase 1: Setup

- [X] T001 Branch `142-pictview-thumb-unicode`; `specs/142-pictview-thumb-unicode/spec.md`, `plan.md`, `tasks.md`, `checklists/requirements.md`

## Phase 2: Foundational - "before"

- [X] T002 Cases with names outside the code page in `specs/132-pictview-thumbnail-verify/probe/thumb132_probe.ps1`; "before" in `specs/142-pictview-thumb-unicode/probe/before.txt`

## Phase 3: User Stories

- [X] T003 [US1] Wide exports `EXIFReplaceThumbnailW`, `EXIFGetInfoW` in `src/plugins/pictview/exif/exif.c`, `exif.def`, `exif.h`, wide file opening in `src/plugins/pictview/exif/libjpeg/jpeg-data.c`
- [X] T004 [US1] The plug-in uses the wide exports with a fallback: `src/plugins/pictview/thumbs.cpp`, `src/plugins/pictview/dialogs.cpp`
- [X] T005 [US2] The failure dialog with Skip / Skip all / Cancel in `src/plugins/pictview/thumbs.cpp`
- [X] T006 [US3] The read-only attribute is put back after an agreed replace in `src/plugins/pictview/thumbs.cpp`
- [X] T007 `PRIVACY.md` names the temporary file of Update Thumbnail

## Phase 4: Verify

- [X] T008 Build, the 132 probe (old and new cases), the 82 real files of 135 through the wide export
- [X] T009 Independent refute-first review; fixes
- [X] T010 `fix-log.md`, `CHANGELOG.md`, `specs/FEATURE-HISTORY.md`, `specs/NEXT-WORK.md`, `issues/PROGRESS.md`; local commit
