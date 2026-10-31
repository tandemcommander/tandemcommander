# Tasks: FTP opened-file lock across two users or ports of one server

**Input**: Design documents from `specs/348-ftp-lock-user-port/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: the hidden-desktop probe `probe/ftp348_probe.ps1` (measure first - written and run
before the change).

## Phase 1: Setup

- [ ] T001 Probe and server for the feature: `specs/348-ftp-lock-user-port/probe/ftp348_probe.ps1` (rows OTHER-USER, OTHER-PORT, ALL-OTHER, ALIAS-LOCK, SAME-LOCK) and `specs/348-ftp-lock-user-port/probe/ftpmini_hold2.py` (one server, one folder, two ports)
- [ ] T002 Measurement before on the build of `main` 4e2c8835 -> `specs/348-ftp-lock-user-port/probe/result_main.txt` (expected PASS 7 / FAIL 3), recorded in `specs/348-ftp-lock-user-port/fix-log.md`

## Phase 2: Foundational

- [ ] T003 Enumerate every `FTPOpenedFiles.OpenFile` caller in `src/plugins/ftp/` (Grep), note what user / host / port each passes and its refusal answer, in `specs/348-ftp-lock-user-port/fix-log.md`

## Phase 3: User Story 1 + 2 - two users or ports of one server (P1)

**Goal**: a second conflicting access to a file of the same server path and name is refused on any connection.
**Independent Test**: probe rows OTHER-USER, OTHER-PORT, ALL-OTHER PASS.

- [ ] T004 [US1] Drop the user and port terms from `CFTPOpenedFile::IsSameFile` in `src/plugins/ftp/operats9.cpp` (parameters stay; comment names 345's / 347's rule and the cost)
- [ ] T005 [P] [US1] Update the `CFTPOpenedFile` field and `IsSameFile` comments in `src/plugins/ftp/operats.h` (user / host / port kept for diagnostics, identity = path + name)
- [ ] T006 [US1] Build (`.\build.cmd`) and encoding guard (`python tools/check_encoding.py --strict`), results in `specs/348-ftp-lock-user-port/fix-log.md`
- [ ] T007 [US2] Measurement after: `ftp348_probe.ps1` -> `specs/348-ftp-lock-user-port/probe/result_after.txt` (expected PASS 10 / FAIL 0)

## Phase 4: User Story 3 - other kinds of access (P2)

- [ ] T008 [US3] By reading: `IsInConflictWith` unchanged, each caller of T003 keeps its refusal answer and cannot conflict with itself (one connection = one user and port), recorded in `specs/348-ftp-lock-user-port/fix-log.md`

## Phase 5: Polish

- [ ] T009 [P] Regressions: 341's `ftp341_probe.ps1`, 345's `ftp345_probe.ps1`, 347's `ftp347_probe.ps1` on the change's build -> `specs/348-ftp-lock-user-port/probe/regress_341.txt`, `regress_345.txt`, `regress_347.txt`
- [ ] T010 Fix-log complete (before / after, commands, results) in `specs/348-ftp-lock-user-port/fix-log.md`

## Dependencies

T001 -> T002 -> T003 -> T004/T005 -> T006 -> T007, T008, T009 -> T010. US1 and US2 share one
change (T004); US3 is checked by reading on the same change.

## Parallel opportunities

T005 alongside T004 (other file); T009's three probes run one after another (one program
instance at a time), but alongside T008.

## Implementation strategy

MVP = Phase 3 (the one-function change and its probe rows); everything else is verification.
