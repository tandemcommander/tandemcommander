# Tasks: feature 133 - SFTP checked against a server

## Phase 1: Setup

- [X] T001 Branch `133-sftp-server-verify`; `specs/133-sftp-server-verify/spec.md`, `plan.md`, `research.md`, `checklists/requirements.md`; test container `tandem-sftp` running

## Phase 2: Foundational - the probe

- [X] T002 Server fixture script `specs/133-sftp-server-verify/probe/fixture133.sh` (read-only directory, unreadable file, deep link, tree beyond 4,095 bytes, a directory of 30 files)
- [X] T003 Probe `specs/133-sftp-server-verify/probe/sftp133_probe.ps1`: connect by a typed address, password and host-key dialogs, rows, server state through `docker exec`

## Phase 3: User Story 1 - 131's SFTP changes seen against the server (P1)

- [X] T004 [US1] Run rows R1-R4, P1, P4, P5 (R5, P2, P3 if drivable) on `build\tandemcommander\Debug_x64_v019` and on the current build; results in `specs/133-sftp-server-verify/probe/`
- [X] T005 [US1] Fix what the rows show in the code 131 touched (`src/plugins/sftp/`); other findings to `specs/NEXT-WORK.md`

## Phase 4: User Story 2 - a listing that ends early is an error (P1)

- [X] T006 [US2] Debug-only seam `TC_SFTP_PROBE_LIST_FAIL` in `src/plugins/sftp/session.cpp` with the old logic; rows LIST-COPY, LIST-MOVE, LIST-PANEL measured ("before")
- [X] T007 [US2] Pure classification of a `readdir` result in `src/plugins/sftp/sftputils.h`, `sftputils.cpp`; checks in `src/plugins/sftp/test/harness.cpp`
- [X] T008 [US2] `CSFTPSession::ListDir` in `src/plugins/sftp/session.cpp` fails unless the end was reached; callers in `src/plugins/sftp/operats.cpp`, `fs.cpp` reviewed; rows LIST-* again; `DeleteRecursive` removes a directory only when its items are gone; `SFTPShowPathError`; `ParseUserPart`

## Phase 5: Verify

- [X] T009 Independent refute-first review; fixes
- [X] T010 `build.cmd full`, `build.cmd full release`, `saltests`, SFTP harness, `tools/check_encoding.py`; regression probes 130, 131
- [X] T011 `fix-log.md`, `quickstart.md`, `CHANGELOG.md`, `specs/FEATURE-HISTORY.md`, `specs/NEXT-WORK.md`, `issues/PROGRESS.md`; local commit
