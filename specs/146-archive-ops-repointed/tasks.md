# Tasks: no archive operation through a name that leads elsewhere than when it was listed

- [x] T001 109 probe: op `delete`, case `resubst-delete`; measured on the build before (`probe/result_pre146.txt`)
- [x] T002 [US1] `src/fileswnd.h`, `src/fileswn1.cpp`: `ShowsArchiveThatMoved`, `RefuseOperationOnMovedArchive`
- [x] T003 [US1] `src/fileswn7.cpp` `UnpackZIPArchive`: refuse at the start
- [x] T004 [US2] `src/fileswn8.cpp` (pack into an archive), `src/fileswna.cpp` (paste / drop), `src/salshlib.cpp` (paste of copied archive items)
- [x] T005 Build, `saltests`, `check_encoding.py`; the case on the build (`probe/result_case.txt`)
- [x] T006 Whole 109 probe, 108 (both), 112
- [x] T007 Refute-first review; fix findings
- [x] T008 Records (FEATURE-HISTORY, NEXT-WORK 2b, CHANGELOG 0.1.11); commit
