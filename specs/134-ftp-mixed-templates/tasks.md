# Tasks: feature 134 - FTP client, mixed texts

## Phase 1: Setup

- [X] T001 Branch `134-ftp-mixed-templates`; `specs/134-ftp-mixed-templates/spec.md`, `plan.md`, `research.md`, `checklists/requirements.md`, `agent-brief.md`

## Phase 2: Foundational - shared pieces and the measurement

- [X] T002 `LoadStrU8` in `src/plugins/ftp/ftp.h`, `ftp.cpp`; `FTPTextToU8`, `FTPGetErrorTextU8` in `src/plugins/ftp/ftputils.h`
- [X] T003 Core: `GetCommonFSOperSourceDescr` gives UTF-8 (`src/zip.cpp`); its user in `src/plugins/undelete/dialogs.cpp` checked
- [X] T004 Test server `specs/134-ftp-mixed-templates/probe/ftp134_server.py`
- [X] T005 Probe `specs/134-ftp-mixed-templates/probe/ftp134_probe.ps1`; "before" results in Czech and English

## Phase 3: User Stories 1, 2, 4 - messages, windows, code-page-only sinks (parallel by file group)

- [X] T006 [P] [US1] [US2] [US4] Package A: `src/plugins/ftp/ctrlcon*.cpp`, `sockets.cpp`, `ssl.cpp`, `datacon*.cpp` - record `specs/134-ftp-mixed-templates/parts/A.md`
- [X] T007 [P] [US1] [US4] Package B: `src/plugins/ftp/fs*.cpp`, `ftp*.cpp`, `parser*.cpp` - record `parts/B.md`
- [X] T008 [P] [US1] [US4] Package C: `src/plugins/ftp/dialogs*.cpp` - record `parts/C.md`
- [X] T009 [P] [US2] Package D: `src/plugins/ftp/operats*.cpp` - record `parts/D.md`

## Phase 4: User Story 3 - the log (inside the packages; the sink in package A)

- [X] T010 [US3] Log sink normalises every message, Logs window, save and copy as UTF-8 (`src/plugins/ftp/ctrlcon2.cpp`, `dialogs2.cpp`); composed log messages use UTF-8 templates (all packages)

## Phase 5: Verify

- [X] T011 `build.cmd full`, compile fixes, `saltests`, `tools/check_encoding.py`
- [X] T012 Probe "after" in Czech and English; the server's byte log compared with "before"
- [X] T013 Independent refute-first reviews; fixes
- [X] T014 `build.cmd full release`; regression probes 116, 127, 130, 131
- [X] T015 `fix-log.md`, `quickstart.md`, `CHANGELOG.md` (a new unreleased section), `specs/FEATURE-HISTORY.md`, `specs/NEXT-WORK.md`, `issues/PROGRESS.md`; local commit
