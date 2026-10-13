# Tasks: feature 137 - a name is not cut at a byte position

## Phase 1: Setup

- [X] T001 Branch `137-names-cut-at-byte`; `specs/137-names-cut-at-byte/spec.md`, `plan.md`, `tasks.md`, `checklists/requirements.md`

## Phase 2: Foundational - measure

- [X] T002 Rows QRLONG and QR250 in `specs/133-sftp-server-verify/probe/sftp133_probe.ps1` (+ state in `fixture133.sh`); row AUTOREN in `specs/134-ftp-mixed-templates/probe/ftp134_probe.ps1`
- [X] T003 Runs on `build\tandemcommander\Debug_x64_v019`; results in `specs/137-names-cut-at-byte/probe/`

## Phase 3: User Story 1 - Quick Rename refuses (P1)

- [X] T004 [US1] `src/fileswn5.cpp`: the plug-in branch of Quick Rename refuses a name of `MAX_PATH` bytes or more

## Phase 4: User Story 2 - the FTP cut (P2)

- [X] T005 [US2] `SplU8WholePrefixLen` in `src/plugins/shared/splunicode.h`; checks in `src/saltests/saltests.cpp`
- [X] T006 [US2] `src/plugins/ftp/operats5.cpp`: the automatic rename cuts at a whole character

## Phase 5: Verify

- [X] T007 Build; rows on the new build; regressions 133, 134 / 136
- [X] T008 Independent refute-first review; fixes
- [X] T009 `fix-log.md`, `CHANGELOG.md`, `specs/FEATURE-HISTORY.md`, `specs/NEXT-WORK.md`, `issues/PROGRESS.md`; local commit
