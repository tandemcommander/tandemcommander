# Tasks: 164

- [X] T001 [US1] Probe `specs/164-zip-delete-cost/probe/zip_delete_cost_probe.ps1` + `bigzip.py`
- [X] T002 [US1] Before (the build at 163): 2,000 0.5 s, 10,000 2.6 s, 30,000 21.9 s - quadratic
- [X] T003 [US1] `src/common/salzipdelete.h`
- [X] T004 [US1] `src/plugins/zip/del.cpp` `DeleteFiles` fast path
- [X] T005 [US1] saltests `TestZipDelete164` in `src/saltests/saltests.cpp`; mutation control fails it
- [X] T006 [US1] After: every size at the probe's 0.5 s floor, 100,000 / 50,000 1.0 s; archives clean
- [X] T007 Regression probes 113, 110, 097; independent review
- [X] T008 Records: fix-log, FEATURE-HISTORY, NEXT-WORK item 15, CHANGELOG
