# Tasks: feature 139 - SFTP, nothing replaced without a question

## Phase 1: Setup

- [X] T001 Branch `139-sftp-no-silent-overwrite`; `specs/139-sftp-no-silent-overwrite/spec.md`, `plan.md`, `tasks.md`, `checklists/requirements.md`

## Phase 2: Foundational - seam, rows, "before"

- [X] T002 Debug seam `TC_SFTP_PROBE_XFER_FAIL` in `src/plugins/sftp/operats.cpp` (with the old logic)
- [X] T003 Rows UPASK, UPFAIL, UPNEWFAIL, DLFAIL, RENEXIST in `specs/133-sftp-server-verify/probe/sftp133_probe.ps1`, `fixture133.sh`; "before" in `specs/139-sftp-no-silent-overwrite/probe/before.txt`

## Phase 3: User Stories

- [X] T004 [US3] `CSFTPSession::Rename(from, to, replace)` in `src/plugins/sftp/session.cpp`, `session.h`; `QuickRename` in `src/plugins/sftp/fs.cpp` refuses an existing target
- [X] T005 [US1] [US2] `SftpTempName` in `src/plugins/sftp/sftputils.h/.cpp` (+ `test/harness.cpp`); upload asks and goes through a temporary name in `src/plugins/sftp/operats.cpp`
- [X] T006 [US2] Download over an existing local file through a temporary file and `SalReplaceWithTempW` in `src/plugins/sftp/operats.cpp`

- [X] T006b [US4] [US5] Upload restructured in `src/plugins/sftp/operats.cpp`: tri-state results, per-item removal of local sources, `DeleteLocalTree` removed, link folders skipped aloud, cloud folders traversed, per-level buffers on the heap; rows UPMOVE, UPMKDIR in the probe
- [X] T006c [US2] Identity of written files through `src/common/salsamefile.h` in `src/plugins/sftp/operats.cpp`

## Phase 4: Verify

- [X] T007 Build, harness, the SFTP probe
- [X] T008 Independent refute-first review; fixes
- [X] T009 `fix-log.md`, `CHANGELOG.md`, `specs/FEATURE-HISTORY.md`, `specs/NEXT-WORK.md`, `issues/PROGRESS.md`; local commit
