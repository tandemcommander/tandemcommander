# Tasks: 165

- [X] T001 [US1] Probe `specs/165-zip-entry-count/probe/zip_count_probe.ps1` + `zipcount.py`
- [X] T002 [US1] Before (the build at 164): DEL-2K PASS (control); DEL-70K 30,535, DEL-140K 61,071, PACK-70K 4,464, ADD-66K 464 - FAIL
- [X] T003 [US1] `src/common/salzipcount.h`; saltests `TestZipCount165`
- [X] T004 [US1] `src/plugins/zip/typecons.h`, `common.cpp`, `add.cpp`, `del.cpp`
- [X] T005 Independent review: CRITICAL (SFX of exactly 65,535) and two SHOULD-FIX taken
- [X] T006 [US1] After: every row PASS, PACK-70K-RE (the program reads its own zip64 record)
- [X] T007 Regressions 113, 110, 119 (Pack, SFX, multi-volume; 106 superseded), 164
- [X] T008 Records: fix-log, FEATURE-HISTORY, NEXT-WORK, CHANGELOG
