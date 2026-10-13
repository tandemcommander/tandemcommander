# Tasks: feature 135 - Update Thumbnail on real camera files

## Phase 1: Setup

- [X] T001 Branch `135-pictview-real-photos`; `specs/135-pictview-real-photos/spec.md`, `plan.md`, `tasks.md`, `checklists/requirements.md`

## Phase 2: Foundational - measure

- [X] T002 Sample set (public collection, outside the repository) and `specs/135-pictview-real-photos/probe/exif_real_measure.py`
- [X] T003 Measurement on the build of 132 / 134: `specs/135-pictview-real-photos/probe/real_result_before.txt`; `research.md` with the findings and the decision

## Phase 3: User Story 1 - the Exif block is kept (P1)

- [X] T004 [US1] Library / `src/plugins/pictview/exif/exif.c` change by the decision of research R2
- [X] T005 [US1] The rule compares the Exif block: `src/common/saljpegkeep.h`, checks in `src/saltests/saltests.cpp`; `src/plugins/pictview/thumbs.cpp` if the call changes

## Phase 4: Verify

- [X] T006 Measurement again (`probe/real_result.txt`); probes of 132 (`thumb132_probe.ps1` fixed + oldlib, `exifdll_measure.py`)
- [X] T007 Independent refute-first review; fixes
- [X] T008 `build.cmd full`, `build.cmd full release`, `saltests`, `tools/check_encoding.py`
- [X] T009 `fix-log.md`, `CHANGELOG.md`, `specs/FEATURE-HISTORY.md`, `specs/NEXT-WORK.md`, `issues/PROGRESS.md`; local commit
