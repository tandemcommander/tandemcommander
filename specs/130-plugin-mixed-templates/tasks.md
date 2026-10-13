# Tasks: feature 130 - plug-in messages with names and error texts

## Phase 1: Setup

- [X] T001 Branch `130-plugin-mixed-templates`, `specs/130-plugin-mixed-templates/spec.md`, `agent-brief.md`
- [X] T002 Inventory with `specs/127-mixed-template-texts/probe/scan_mixed.py --plugins` (400 compositions, 131 with a name or error text)

## Phase 2: Foundational

- [X] T003 Shared helper `src/plugins/shared/splloadstru8.h` (`SplLoadStrU8`, `SplLegacyToU8Alloc`, `SplLegacyToU8`)
- [X] T004 Unit checks `TestPluginLoadStr130` in `src/saltests/saltests.cpp`

## Phase 3: User Story 1 and 2 - names and Windows reasons in plug-in messages (P1, P2)

- [X] T005 [P] [US1] Triage + fix `src/plugins/7zip`, `checksum`, `tar`, `uncab`, `uniso`, `undelete`; records `triage/*.md`
- [X] T006 [P] [US1] Triage + fix `src/plugins/zip`; record `triage/zip.md`
- [X] T007 [P] [US1] Triage + fix `src/plugins/sftp`, `renamer`, `filecomp`, `dbviewer`; records
- [X] T008 [P] [US1] Triage + fix `src/plugins/pictview`, `codeview`, `mdview`, `peviewer`, `diskmap`, `folders`, `portables`, `regedt`; records
- [X] T009 [P] [US1] FTP: facts and plan only, `triage/ftp.md` (no source change)
- [X] T010 [US1] Core: the plug-in progress dialog's title wide, a cut line at a whole character (`src/zip.cpp`); ZIP `OpenProgressDialogU8` simplified, UnCAB titles (`src/plugins/uncab/uncab.cpp`)
- [X] T011 [US1] Probe `probe/plugmix_probe.ps1`; measure on 0.1.9 (Czech, Slovak, English)
- [X] T012 [US1] Debug build, probe on the new build

## Phase 4: Polish

- [X] T013 Independent refute-first review (two reviewers), fixes (`src/plugins/sftp/operats.cpp`, `session.cpp`, `logs.cpp`, `src/zip.cpp`), corrected records
- [X] T014 Release build, saltests, `tools/check_encoding.py`, final probe runs, regression probes
- [X] T015 `fix-log.md`, `CHANGELOG.md`, `specs/FEATURE-HISTORY.md`, `specs/NEXT-WORK.md` (FTP as the next step; defects found on the way), `issues/issue_7_report.md`, `issues/PROGRESS.md`
