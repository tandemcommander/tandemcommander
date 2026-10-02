# Tasks: ZIP and SFTP password forms (feature 094)

## Phase 1 - Setup

- [X] T001 Measurement: research.md, probes (zipkey.py, measure_7zip.py, zip_gui_probe.ps1, sftp_gui_probe.ps1, sshlog_server.py) and their result files
- [X] T002 Spec, plan, contract, tasks; preserve the pre-change Debug build (build\tandemcommander\Debug_x64_pre094); commit

## Phase 2 - User Stories 1 and 2: ZIP (S1)

- [ ] T003 [US1] src/common/salzippwd.h: representability, the four forms, the pack form, the ordered distinct candidate list; saltests
- [ ] T004 [US1] src/plugins/zip/dialogs.cpp: wide read of the password fields (pack options, prompt), full length
- [ ] T005 [US1] src/plugins/zip/add.cpp (+ callers): pack form per contract Z3; AES limit on the form
- [ ] T006 [US2] src/plugins/zip/extract.cpp, crypt.cpp: candidates per contract Z4 for AES and classic; restart of an item after a checksum failure; remember only what verified
- [ ] T007 src/plugins/zip: no password in call-stack text; wipes (contract Z5); the self-extractor stub builds and is unchanged
- [ ] T008 [US1] [US2] Probes: fixtures in every form x both methods; pack rows; wrong-password rows; new and previous build; hidden desktop
- [ ] T009 Independent review; fixes; commit `[094] S1 ...`

## Phase 3 - User Story 3: SFTP (S2)

- [ ] T010 [US3] src/plugins/sftp/dialogs.cpp: secret reads cannot fall back (contract S1)
- [ ] T011 [US3] Probe with the logging server: 256 x two-byte and 256 x Cyrillic secrets arrive as UTF-8; existing rows unchanged
- [ ] T012 Independent review; fixes; commit `[094] S2 ...`

## Phase 4 - Polish (S3)

- [ ] T013 Gates: Debug + full Release builds, saltests, strict guard, 093 pwd/dialog probes as regression
- [ ] T014 Records: CHANGELOG, specs/NEXT-WORK.md, CLAUDE.md, PRIVACY.md, quickstart.md, fix-log.md
- [ ] T015 Commit
