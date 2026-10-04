# Tasks: feature 108

- [X] T001 Preserve the pre-change build (`Debug_x64_pre108`); `.specify/feature.json`
- [X] T002 Research: the route F4 -> `ExecuteFromArchive` -> disk cache -> `CFileTimeStamps::AddFile` -> `CheckAndPackAndClear` -> packer; the collision set of this code page (`research.md`)
- [X] T003 Measurement probe `probe/namecoll_probe.ps1` + `probe/arcfix.py` on `Debug_x64_pre108` (`probe/namecoll_result_pre108.txt`)
- [X] T004 Spec, plan, tasks, checklist; decisions in spec.md Clarifications
- [X] T005 [US1][US2] S1 rule `src/common/salarcedit.h`
- [X] T006 [US1] S2 `salamdr3.cpp` `AddFile` + `CheckAndPackAndClear` grouping
- [X] T007 [US2] S2 `fileswn6.cpp` `GetZIPPathAsStored108` in `ExecuteFromArchive`
- [X] T008 S3 saltests `TestArchiveEdit108`
- [X] T009 [US1-US4] S4 probe on this build and on `Debug_x64_pre108`
- [X] T010 Regression: 096 archedit, 097 arcwork subset, 092 focus, 106 packself (`probe/regress_*_108.txt`)
- [X] T011 Gates: Debug + full Release build, saltests, strict encoding guard
- [X] T012 Hostile re-read of the diff; records (fix-log, CHANGELOG, NEXT-WORK; the CLAUDE.md entry proposed in the fix-log); no commit (the maintainer commits after an independent review)
