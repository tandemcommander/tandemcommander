# Tasks: feature 117

- [X] T001 Research (research.md): what coreutils 8.32, 7-Zip 22.01 and Windows PowerShell 5.1 write (Total Commander from its HISTORY.TXT); what the plug-in read (code reading); `FindFirstFileW` / `GetFileAttributesExW` on `\\?\` paths with `.`, `..`, wildcards; strict code-page conversion on 1250/1251/1252/852/932; which list variants coreutils and 7-Zip read back; preserve `Debug_x64_pre117`
- [X] T002 Spec (Clarifications), plan, tasks, checklist
- [X] T003 S1 `src/common/salcsumlist.h` (detection, exact decoding, name rule, GNU unescape, path building)
- [X] T004 [US1][US2] S2 `dialogs.cpp` `LoadFile` decodes; `LoadSourceFile` path + usable-name rule + `GetFileAttributesExW`; `SetDispInfoText` WTF-8 + U+FFFD
- [X] T005 [US3] S2 `.` / `..` / `//` / absolute names (`SalCslBuildPath`); GNU escape in `AnalyzeSourceFile` and `CGenericHashAlgo::ParseDigest` (`wrappers.cpp`)
- [X] T006 [US4] S2 `SaveHashes`: md5/sha* LF without a comment line, SFV unchanged (binary mode)
- [X] T007 S3 saltests `TestChecksumList117` (14,441 -> 14,528 / 0; 14,576 after T014)
- [X] T008 S4 probe written: `probe/make_lists117.py`, `probe/csumlist_probe.ps1` (parses, pure ASCII); offline model `probe/m117_model.cpp` + `build_model.cmd` + `run_model.py` (48 rows, 0 mismatches)
- [X] T009 Gates: Debug + full Release builds (0 warnings), saltests 14,528 / 0, strict guard 0, BOM / CRLF, clang-format of the new header
- [X] T010 Hostile re-read of the diff (fix-log)
- [X] T011 Records: fix-log (with the proposed CLAUDE.md entry), CHANGELOG `[Unreleased]`, NEXT-WORK (item fixed by 117 - GUI runs pending); PRIVACY.md decision; no commit
- [X] T014 Code-only review REJECT fixed: B1 (absolute names only on the list's own drive / share - no connection to a server a list names), S1 (trailing / line-end NULs ignored, BOM-less UTF-16 needs parity dominance), N1 (`:` streams), N2 (device-safety note), N3 (unknown GNU escape), N4/N5 recorded; probe lists `absolute`, `nul_tail1`, `nul_tail11`; Debug + full Release, saltests 14,576 / 0, guard 0, model 58 / 0
- [ ] T012 [US1]-[US4] Probe on `Debug_x64_117` and `Debug_x64_pre117` (hidden desktop) - PENDING (`quickstart.md`)
- [X] T013 Regression scope: only the Checksum plug-in, a new header and saltests changed (no shared plug-in code, no core) - no other feature's probe is affected
