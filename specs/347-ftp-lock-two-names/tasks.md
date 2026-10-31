# Tasks: FTP opened-file lock across two names of one server

**Input**: `specs/347-ftp-lock-two-names/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: GUI probe (hidden desktop) - written and run on `main` before the change (T001-T002).

## Phase 1: Setup / measurement

- [ ] T001 Write the probe `specs/347-ftp-lock-two-names/probe/ftp347_probe.ps1` and server `specs/347-ftp-lock-two-names/probe/ftpmini_hold.py` (rows ALIAS-LOCK, SAME-LOCK, OTHER-USER)
- [ ] T002 Run the probe on `main` 794b3207 -> `probe/result_main.txt` (ALIAS-LOCK FAIL expected), record in `fix-log.md`

## Phase 2: User Story 1 - two uploads of one file under two names (P1)

**Goal**: the second upload's item is refused "in use" while the first stores the file.
**Independent test**: probe row ALIAS-LOCK PASS.

- [ ] T003 [US1] `src/plugins/ftp/operats9.cpp` `CFTPOpenedFile::IsSameFile`: drop the host comparison; comment (feature 347, 341's rule, the cost)
- [ ] T004 [US1] `src/plugins/ftp/operats.h`: the `IsSameFile` / `Host` comments say the host is stored, not compared
- [ ] T005 [US1] Build Debug x64 (`.\build.cmd`), encoding guard (`python tools/check_encoding.py --strict`)
- [ ] T006 [US1] Run the probe on the branch -> `probe/result_after.txt` (ALIAS-LOCK PASS, SAME-LOCK PASS)

## Phase 3: User Story 2 - other access types (P2)

- [ ] T007 [US2] Re-read every `FTPOpenedFiles.OpenFile` caller (`operatsb.cpp`, `operats8.cpp`, `operats4.cpp`, `ctrlcon5.cpp`) and confirm each passes user / port as before and keeps its refusal answer; record in `fix-log.md`

## Phase 4: Polish / regressions

- [ ] T008 Regressions: `ftp341_probe.ps1` and `ftp345_probe.ps1` on the branch -> `probe/regress_341.txt`, `probe/regress_345.txt`
- [ ] T009 Negative control: the probe's ALIAS-LOCK fails on the old code (`result_main.txt`) - recorded
- [ ] T010 `fix-log.md` before / after, Inbox item for another user / port (OTHER-USER)

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006; T007 after T003; T008 after T005; T010 last.
