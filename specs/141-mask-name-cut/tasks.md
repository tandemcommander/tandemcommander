# Tasks: feature 141 - a name built from a mask is never cut

## Phase 1: Setup

- [X] T001 Branch `141-mask-name-cut`; `specs/141-mask-name-cut/spec.md`, `plan.md`, `tasks.md`, `checklists/requirements.md`

## Phase 2: Foundational - probe, "before"

- [X] T002 `specs/141-mask-name-cut/probe/maskname_probe.ps1` (rows CP250, MV250, QR250, QR256); "before" on the 0.1.9 build in `specs/141-mask-name-cut/probe/before.txt`

## Phase 3: User Stories

- [X] T003 [US1] The pure rule in `src/common/salmaskname.h` + checks in `src/saltests/saltests.cpp`; `MaskNameChecked` in `src/masks.cpp`, `src/masks.h`
- [X] T004 [US1] `RenameFileInternal` in `src/fileswn5.cpp`; the Copy / Move script builder in `src/fileswn6.cpp` (two sites)
- [X] T005 [US1] Plug-in callers of `MaskName`: `src/plugins/ftp/fs4.cpp`, `fs5.cpp`, `src/plugins/pictview/render1.cpp`
- [X] T006 [US2] FTP upload autorename in `src/plugins/ftp/ftputils.cpp` cuts at a whole character; checks

## Phase 4: Verify

- [X] T007 Build, `saltests`, `check_encoding.py`, the probe, the FTP probe
- [X] T008 Independent refute-first review; fixes
- [X] T009 `fix-log.md`, `CHANGELOG.md`, `specs/FEATURE-HISTORY.md`, `specs/NEXT-WORK.md`, `issues/PROGRESS.md`; local commit
