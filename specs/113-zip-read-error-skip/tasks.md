# Tasks: feature 113

- [X] T001 Research (research.md): the route, both modes, every "not stored" path on the build before by code reading; the 7-Zip update path; the probe's lock premise measured without the GUI; preserve `Debug_x64_pre113`
- [X] T002 Spec (Clarifications), plan, tasks, checklist
- [X] T003 S1 `src/common/salzipmember.h` (`SalZipMemberSpan`, `SalZipCentralRecordLen`, `SalZipRelocateCentralRecord`)
- [X] T004 [US1] S2 temporary copy: `CReplacedMember` / `Replacements` (`add_del.h`), recorded in `MatchFiles`, `RestoreReplaced` called from both Skip paths of `PackFiles` (`add.cpp`)
- [X] T005 [US2] S3 in-place: `PackNormal` order, `DeleteReplacedAfterPack`, `DeleteFiles(dataEnd)` + `DeleteAfterPack`, `UpdateAddedOffsets`, `Recover(withAdded)` (`add.cpp`, `del.cpp`, `add_del.cpp`)
- [X] T006 [US3] S4 AES error kept; progress after Skip without the freed `SourFile`; `NewCentrDir` double free; `DelFiles.Add` checked
- [X] T007 [US4] S5 7-Zip: `CUpdateInfo::Replaces` (`structs.h`, `7zclient.cpp`), `GetStream` (`update.cpp`)
- [X] T008 S6 saltests `TestZipMember113`; `salzipmember.h` listed in `saltests.vcxproj`
- [X] T009 S7 probe written: `probe/zipskip_probe.ps1`, `probe/zipskip.py` (helper self-tested: make / read, a corrupted byte detected, 7z read)
- [X] T010 [US1]-[US5] Probe on `Debug_x64_113` (37 / 0 / 0) and `Debug_x64_pre113` (11 / 26 / 0, the predicted rows) - hidden desktop, 2026-10-06
- [X] T011 Regressions on `Debug_x64_113`: 110 zipname 42 / 0, 106 packself 70 / 0 / 4, 094 ZIP passwords 56 / 1 (X1) - as before
- [X] T012 Gates: Debug + full Release builds, saltests 14,286 / 0, strict guard 0, BOM / CRLF of touched sources
- [X] T014 Code-only review (ACCEPT pending GUI): S1 zip64 block first + `UpdateCentrDir` by id (`SalZipCentralRecordOffsetPos`), saltests; S2 guard in `DeleteFiles`; N1 offsets only after a successful move; N3 default initializer; N2 / N4 recorded; Debug + full Release rebuilt, saltests 14,301 / 0, guard 0
- [X] T015 Re-check (ACCEPT): R1 bound by the next member on disk (`SalZipNextMemberOffset`), N-a length < 46 refused, N-b marker without value never adjusted; saltests 14,323 / 0; Debug + full Release rebuilt
- [X] T016 Re-check 2 (ACCEPT): NIT 1 the bound fails closed (unknown -> format error), saltests 14,327 / 0; NIT 2 (n x d directory walks) recorded; Debug + full Release rebuilt
- [X] T013 Records: fix-log (with the proposed CLAUDE.md entry), CHANGELOG `[Unreleased]`, NEXT-WORK (item 5 entry 2 note - fixed, GUI runs pending); no commit
