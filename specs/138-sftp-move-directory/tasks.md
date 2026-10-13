# Tasks: feature 138 - SFTP, move of a directory

## Phase 1: Setup

- [X] T001 Branch `138-sftp-move-directory`; `specs/138-sftp-move-directory/spec.md`, `plan.md`, `tasks.md`, `checklists/requirements.md`

## Phase 2: Foundational - rows and "before"

- [X] T002 Rows MTREE, MKEEP, MSKIP and the new expectation of M1 in `specs/133-sftp-server-verify/probe/sftp133_probe.ps1`; trees in `fixture133.sh`
- [X] T003 Run on the build of 137 ("before"): `specs/138-sftp-move-directory/probe/move_before.txt`

## Phase 3: User Stories 1 and 2

- [X] T004 [US2] `SftpMoveMayRemove` in `src/plugins/sftp/sftputils.h`, `sftputils.cpp`; checks in `src/plugins/sftp/test/harness.cpp`
- [X] T005 [US1] [US2] `src/plugins/sftp/operats.cpp`: `DownloadOneFile` checks the close; `RemoveMovedFile`; `DownloadDir` / `DownloadRecursive` / `SFTPDownloadFromPanel` remove what was moved

## Phase 4: Verify

- [X] T006 Build; the SFTP probe; harness
- [X] T007 Independent refute-first review; fixes
- [X] T008 `fix-log.md`, `CHANGELOG.md`, `specs/FEATURE-HISTORY.md`, `specs/NEXT-WORK.md`, `issues/PROGRESS.md`; local commit
