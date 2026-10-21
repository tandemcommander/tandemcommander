# Tasks: FTP - a PWD reply or a created folder path that does not fit is never cut and used

**Input**: `specs/277-ftp-pwd-path-cut/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: requested by the spec (FR-009: saltests; SC-001..SC-004: the probe).

## Phase 1: Setup

- [ ] T001 Probe and server option in place: `specs/277-ftp-pwd-path-cut/probe/ftp277_probe.ps1`, PWDMAP option of `specs/215-ftp-long-name-command/probe/ftpmini.py`, before result `specs/277-ftp-pwd-path-cut/probe/result_before.txt` (measured on 65c337dc)

## Phase 2: Foundational

- [ ] T002 Create the pure rule `SalFtpPathFromPwdReply` in `src/common/salftppwd.h` (UTF-8 BOM, SPDX header, plan *Design* 1)
- [ ] T003 Add `TestFtpPwdReply277` to `src/saltests/saltests.cpp` (include the header; RFC / VxWorks / AIX forms; `""` escapes; 299 / 300 / 301 bytes in a 301-byte buffer; unclosed quote; reply bounded by its size; short reply) and call it from `main`

## Phase 3: User Story 1 - a working path that does not fit is refused (P1)

**Independent test**: probe rows AIX, CP, R301 - never "ANCESTOR", a working-path error.

- [ ] T004 [US1] `src/plugins/ftp/ftputils.cpp`: `FTPGetDirectoryFromReply` on `SalFtpPathFromPwdReply`; `FTPDecodeServerReplyPathInPlace` returns BOOL (fails when the UTF-8 form does not fit or on low memory); include `../../common/salftppwd.h`
- [ ] T005 [US1] Check the four callers keep their failure handling (ctrlcon3.cpp, ctrlcon5.cpp, operats7.cpp, operatsa.cpp) - no change expected; record in `specs/277-ftp-pwd-path-cut/fix-log.md`

## Phase 4: User Story 2 - exactly 300 bytes accepted (P2)

**Independent test**: probe row R300 = "DEEP300"; saltests 300-byte checks.

- [ ] T006 [US2] Covered by T002 (the copy loop checks room only for a byte to store); confirm with the saltests checks of T003 and the probe row R300

## Phase 5: User Story 3 - no other place acts on a cut name or path (P3)

- [ ] T007 [P] [US3] `src/plugins/ftp/ftputils.cpp` + `ftputils.h`: `FTPCompleteAbsolutePath` returns FALSE with the path unchanged when the completed path does not fit
- [ ] T008 [US3] `src/plugins/ftp/operats9.cpp` `CUploadListingsOnServer::ReportCreateDirs`: heap buffers, `unknownResult` for a name of `FTP_MAX_PATH` bytes or more, low memory -> invalidate the workPath listing
- [ ] T009 [P] [US3] `src/plugins/ftp/ftputils.cpp` + `ftputils.h`: `BOOL FTPAS400CutFileNamePart(char* mbrName, int mbrNameSize, const char* name)` never cuts
- [ ] T010 [US3] Callers of T009: `src/plugins/ftp/fs4.cpp` (buffer `3 * MAX_PATH`, FALSE -> `IDS_TOOLONGPATH`, stop) and `src/plugins/ftp/operats6.cpp` (buffer `3 * MAX_PATH`, FALSE -> no item, the explore's error path)
- [ ] T011 [P] [US3] `src/plugins/ftp/operats9.cpp` `CFTPOpenedFile::IsSameFile`: `SalNameOrderEqualCI` for case-insensitive servers (include `../../common/salnameorder.h`)
- [ ] T012 [P] [US3] `src/plugins/ftp/fs5.cpp`: the link size only when the whole source path fits `linkName`

## Phase 6: Polish & verification

- [ ] T013 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [ ] T014 `build.cmd` -> `BUILD SUCCEEDED`; `saltests.exe` -> 0 failed
- [ ] T015 Probe after: `specs/277-ftp-pwd-path-cut/probe/result_after.txt` - every row PASS
- [ ] T016 Regression probes 215 and 233 (`specs/277-ftp-pwd-path-cut/probe/regress_215.txt`, `regress_233.txt`) give their recorded results
- [ ] T017 `specs/277-ftp-pwd-path-cut/fix-log.md`: before / after, commands, results

## Dependencies

T001 done before code. T002 -> T003, T004 -> T005, T006. T007 -> T008. T009 -> T010. T011, T012
independent. T013-T017 after all code.

## Parallel examples

T007, T009, T011, T012 touch different functions (T007 / T009 the same file - sequential edits).

## Implementation strategy

MVP = US1 (T002-T005, the data-loss case); US2 comes with it; US3 small independent fixes.
