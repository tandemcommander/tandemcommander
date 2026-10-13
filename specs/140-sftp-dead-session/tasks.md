# Tasks: feature 140 - SFTP dead session, special files, refused attribute changes

## Phase 1: Setup

- [X] T001 Branch `140-sftp-dead-session`; `specs/140-sftp-dead-session/spec.md`, `plan.md`, `tasks.md`, `checklists/requirements.md`

## Phase 2: Foundational - rows, "before"

- [X] T002 Rows DEADCOPY, DEADDEL, DEADMOVE, SPZERO, SPFIFO in `specs/133-sftp-server-verify/probe/sftp133_probe.ps1`, `fixture133.sh`; "before" (SPZERO) in `specs/140-sftp-dead-session/probe/before.txt`

## Phase 3: User Stories

- [X] T003 [US1] `SftpRcIsDeadTransport` in `src/plugins/sftp/sftputils.h/.cpp` (+ `test/harness.cpp`); the gate and `NoteTransportError` in every request of `src/plugins/sftp/session.cpp`; the debug seam `TC_SFTP_PROBE_TIMEOUT_AT`
- [X] T004 [US1] `SessionLost` / `ReportSessionLost` in every loop of `src/plugins/sftp/operats.cpp` (download, upload, delete, attributes, owner)
- [X] T005 [US2] `SftpDownloadKind` in `src/plugins/sftp/sftputils.h/.cpp` (+ harness); `DownloadOneFile` in `src/plugins/sftp/operats.cpp` refuses special files
- [X] T006 [US3] Refused attribute / owner / time changes counted and reported once in `src/plugins/sftp/operats.cpp`

## Phase 4: Verify

- [X] T007 Build, harness, the SFTP probe
- [X] T008 Independent refute-first review; fixes
- [X] T009 `fix-log.md`, `CHANGELOG.md`, `specs/FEATURE-HISTORY.md`, `specs/NEXT-WORK.md`, `issues/PROGRESS.md`; local commit
