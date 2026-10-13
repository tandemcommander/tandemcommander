# Tasks: feature 131 - defect batch

## Phase 1: Setup

- [X] T001 Branch `131-plugin-defect-batch`, `specs/131-plugin-defect-batch/spec.md`, `agent-brief.md`

## Phase 2: User Stories 1-4 - measure, fix, record (parallel by directory)

- [X] T002 [P] [US1] [US4] `src/plugins/pictview` (thumbnail paths, WIC path, `InitEXIF`), `src/plugins/diskmap` (`CZStringBuffer`, directory line), `src/plugins/peviewer` (`%ls`); records `items/pictview.md`, `diskmap.md`, `peviewer.md`
- [X] T003 [P] [US1] [US3] `src/plugins/sftp` (path joins refuse, error reasons, literals); record `items/sftp.md`; unit harness `src/plugins/sftp/test/harness.cpp`
- [X] T004 [P] [US2] [US3] `src/plugins/ftp` (format strings, Logs combo, Quick Rename), `src/plugins/filecomp/dialogs4.cpp`, `src/plugins/regedt` (`regedt.cpp`, `finddlg.cpp`, `fs3.cpp`); records
- [X] T005 [P] [US2] [US3] [US4] `src/plugins/zip` (favourites, `.set`), `src/plugins/7zip` (`FStreams.cpp`, path line), `src/plugins/undelete` (virtual names), `src/plugins/renamer` (`FileError`, histories); records
- [X] T006 [US4] Core `src/salamdr3.cpp`, `src/plugins3.cpp`; translations `translations/spanish/7zip.slt`, `translations/ui-overrides.json`

## Phase 3: Verify

- [X] T007 Debug build (`build.cmd full`), saltests, `tools/check_encoding.py`, SFTP harness
- [X] T008 Probe `probe/batch131_probe.ps1` on the new build and on 0.1.9; probe of 130 in Spanish
- [X] T009 Three independent refute-first reviews; fixes: `src/plugins/zip/dialogs2.cpp` (name comparison), `src/plugins/sftp/fs.cpp`, `sftputils.cpp`, `src/salamdr3.cpp` (third template site), seven `translations/*/sftp.slt`
- [X] T010 Release build, regression probes 113, 127, 129, 130
- [X] T011 `fix-log.md`, `CHANGELOG.md`, `specs/FEATURE-HISTORY.md`, `specs/NEXT-WORK.md`, `issues/PROGRESS.md`
