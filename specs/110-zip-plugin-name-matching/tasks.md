# Tasks: feature 110

- [X] T001 Research (research.md): every member-name comparison of the ZIP plug-in found and classified; the old comparison's collision set (`probe/zip_collision_set.py`); every route measured on the build before with `probe/zipname_probe.ps1` (+ `zipfix.py`); preserve `Debug_x64_pre110`
- [X] T002 Spec (Clarifications), plan, tasks, contract, checklist
- [X] T003 [US1][US2][US3] S1 rule: `src/common/salzipname.h` (`SalZipNameEqual`, `SalZipNamePrefix`, `SalZipMemberIs`, `SalZipMemberIsOrIsIn`)
- [X] T004 [US1][US2][US3] S2 ZIP update matching: `add.cpp CZipPack::MatchFiles` (both comparisons, the Move folder test, the Unix spelling copy with a growing buffer)
- [X] T005 [US4] S2 ZIP delete: `del.cpp CountFilesInRoot` uses the selection's folder test
- [X] T006 S3 saltests `TestZipName110`; `salzipname.h` listed in `saltests.vcxproj`
- [X] T007 [US1]-[US5] S4 probe on both builds (hidden desktop): `probe/zipname_result.txt`, `probe/zipname_result_pre110.txt`
- [X] T008 Gates: Debug + full Release, saltests, strict encoding guard, sources' BOM/CRLF; regression probes 108 namecoll, 106 packself, 094 ZIP passwords, 096 archedit
- [X] T009 Records: fix-log, NEXT-WORK (item 5 entry 2), CHANGELOG `[Unreleased]` (and 108's ZIP caveat), the CLAUDE.md entry proposed in the fix-log; no commit (the coordinator commits after an independent review)
- [X] T010 Review (ACCEPT): SF1 fixed in `add.cpp` / `add_del.h` (`CAddInfo::Replaced`: after a *Yes*, a *Skip* keeps only that member), probe rows `r_*` on both builds; SF2 wording corrected (salzipname.h, spec, contract, CHANGELOG) + saltests digraph pairs; NIT recorded; probe `-Scratch` parameter
- [X] T011 Re-run: Debug build, saltests 14,140, guard, probe 42/0 (pre-110 review rows), regressions 108 + 106, full Release build
