# Tasks: feature 115

- [X] T001 Research (research.md): the Restore Encrypted Files walk (every append, every buffer, the panel path, links), `RemoveDuplicateFiles` (structure layout, where duplicates come from), the name identity sites, the sweep; EFS availability read-only; preserve `Debug_x64_pre115`
- [X] T002 Spec (Clarifications), plan, tasks, checklist
- [X] T003 S1 `src/common/salnameorder.h`
- [X] T004 [US3] S2 name identity (`miscstr.{h,cpp}`, `fs2.cpp`, `fat.h`)
- [X] T005 [US2] S3 duplicates (`fat.h`)
- [X] T006 [US1] S4 the walk (`restore.cpp`)
- [X] T007 [US4] S5 sweep (`fs2.cpp`, `dialogs.cpp`)
- [X] T008 S6 saltests `TestUndeleteLeftovers115`; header listed in `saltests.vcxproj`
- [X] T009 S7 probe written: `probe/make_images115.py` (self-test; 7-Zip lists the FAT image), `probe/undelleft_probe.ps1` (parses)
- [X] T010 Gates: Debug + full Release builds, saltests 14,401 / 0, strict guard 0, BOM / CRLF of touched sources
- [X] T011 Hostile re-read of the diff (fix-log)
- [X] T012 Records: fix-log (with the proposed CLAUDE.md entry), CHANGELOG `[Unreleased]`, NEXT-WORK (the 114 "found" entries - fixed, GUI runs pending); no commit
- [X] T015 Code-only review (ACCEPT pending GUI): SF1 folder identity (salsamefile.h + final path), SF2 exact-name-first lookup, NITs (core comment, GetPanelPath message, unreachable branch noted), named-stream-only base never deleted; Debug + full Release rebuilt, saltests 14,401 / 0, guard 0
- [ ] T013 [US1]-[US4] Probe on `Debug_x64_115` and `Debug_x64_pre115` (hidden desktop) - PENDING (GUI runs after 18:00, `quickstart.md`)
- [ ] T014 Regression on `Debug_x64_115`: 114 `undelnames_probe.ps1` - PENDING
