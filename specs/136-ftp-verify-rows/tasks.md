# Tasks: feature 136 - FTP rows that 134 did not run

## Phase 1: Setup

- [X] T001 Branch `136-ftp-verify-rows`; `specs/136-ftp-verify-rows/spec.md`, `plan.md`, `tasks.md`, `checklists/requirements.md`

## Phase 2: User Story 1 - the rows

- [X] T002 [US1] Server accounts in `specs/134-ftp-mixed-templates/probe/ftp134_server.py`
- [X] T003 [US1] Rows BMK, PWD, LOGINU8, LOGINCP, SAVELOG in `specs/134-ftp-mixed-templates/probe/ftp134_probe.ps1`
- [X] T004 [US1] Runs on `build\tandemcommander\Debug_x64_v019` and on the current build, Czech and English; results in `specs/136-ftp-verify-rows/probe/`

## Phase 3: User Story 2 - fixes

- [X] T005 [US2] (nothing to fix) Fix what the rows show in `src/plugins/ftp/`; rows again

## Phase 4: Records

- [X] T006 `fix-log.md`, `specs/134-ftp-mixed-templates/quickstart.md` (rows no longer owed), `specs/FEATURE-HISTORY.md`, `specs/NEXT-WORK.md`, `issues/PROGRESS.md`; local commit
