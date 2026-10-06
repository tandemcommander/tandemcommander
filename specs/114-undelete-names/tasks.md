# Tasks: feature 114

- [X] T001 Research (research.md): the FAT rule and every site that applied it, the short / long name route, the volume layer (live and dead routes), the sweep; preserve `Debug_x64_pre114`
- [X] T002 Spec (Clarifications), plan, tasks, checklist
- [X] T003 S1 `src/common/salfatname.h`, `src/common/salvolpaths.h`
- [X] T004 [US1][US2] S2 FAT parser (`fat.h`, `fat.cpp`, `library/undelete.h` flag)
- [X] T005 [US1][US3] S3 `fs2.cpp` listing / path / restore, `undelete.h`
- [X] T006 [US1] S4 `miscstr.cpp` WTF-8, UTF-8 error texts, `AddNumberSuffix`
- [X] T007 [US4] S5 volume layer (`os.h`, `os.cpp`, `fs2.cpp`, `dialogs.cpp`, `restore.cpp`)
- [X] T008 [US5] S6 sweep fixes (`ntfs.h`, `exfat.h`, `fs2.cpp`, `dialogs.{h,cpp}`, `os.h`)
- [X] T009 S7 saltests `TestUndeleteNames114`; headers listed in `saltests.vcxproj`
- [X] T010 S8 probe written: `probe/make_images.py` (self-test, 7-Zip lists the FAT image), `probe/undelnames_probe.ps1` (parses; refuses while a tandemcommander.exe runs - checked)
- [X] T011 Gates: Debug + full Release builds, saltests 14,375 / 0, strict guard 0, BOM / CRLF of touched sources
- [X] T012 Hostile re-read of the diff (fix-log)
- [X] T013 Records: fix-log (with the proposed CLAUDE.md entry), CHANGELOG `[Unreleased]`, NEXT-WORK (the 104 entry - fixed, GUI runs pending); no commit
- [X] T017 Code-only review (ACCEPT pending GUI): SF1 the dropped-character / hash-form rule of Windows short names (`salfatname.h`, saltests, `make_images.py`, research), NIT 2 case bits A-Z only, NIT 3 recorded, `CVolume::Open` fallback bounded, `.bak` verified; Debug + full Release rebuilt, saltests 14,383 / 0, guard 0
- [X] T014 [US1]-[US3][US5] Probe on `Debug_x64_114` (30 / 0 / 4 ND) and `Debug_x64_pre114` (`-Expect before` 27 / 1 - the dup END control) on the hidden desktop, 2026-10-06 (fix-log "GUI results"; the probe's name map made case-sensitive after the first pair of runs)
- [X] T015 Regression on `Debug_x64_114`: 104 `plugnames_probe.ps1 -Only und-image` 3 / 0
- [ ] T016 [US4] Mount folder outside ASCII (person, admin) - PENDING (`quickstart.md` "By hand")
