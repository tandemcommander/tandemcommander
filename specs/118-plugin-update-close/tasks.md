# Tasks: feature 118 - plug-in windows and an installer's close request

- [x] T001 Research: the core's decision and act (080/088), the four plug-ins' windows, close paths
      and `Release()`; other enabled plug-ins (`research.md` R1-R6)
- [x] T002 Spec, clarifications (decisions per plug-in), plan
- [x] T003 Copy `Debug_x64` to `Debug_x64_pre118` (without `Intermediate`) before the first build
- [x] T004 File Comparator: declare the comparator window (`mainwnd.cpp` `WM_CREATE`); count open
      Compare Files dialogs (`dialogs.cpp`, `CompareDialogsOpen`); `Release()` unattended: refuse
      with a dialog open, else 5 s close and thread wait (FR-001, FR-005, FR-006)
- [x] T005 File Comparator: a result after a close request posts `CM_EXIT` and shows no box; no box
      for a dropped worker's result; `CancelWorker` initialised (FR-007)
- [x] T006 Disk Map: declare map, Log and tooltip windows through a helper that checks the core's
      interface (FR-002, FR-009); `Release()` unattended 5 s; thread records freed after the threads
      ended (FR-008)
- [x] T007 Checksum: `HoldsWork` / `UpdateClosesUnattended` / `WindowsHoldingWork`; Verify declared,
      Calculate declared only while it holds nothing unsaved; a save counts only when completely
      written; `Release()` unattended: refuse with work, else 5 s (FR-003, FR-005, FR-006)
- [x] T008 Batch Renamer: `Release()` unattended refuses while a window is open (FR-004, FR-006)
- [x] T009 Debug build, `saltests` 14,576 / 0, encoding guard strict `TOTAL: 0`
- [x] T010 Full Release build
- [x] T011 Hostile re-read of the diff (fix-log "Review")
- [x] T012 Probe `probe/update_close_probe.ps1` (20 rows, `-Expect fixed|before`), written and
      parse-checked, NOT run
- [x] T013 Records: fix-log, CHANGELOG, NEXT-WORK item 4, architecture/06
- [x] T015 Code review round (ACCEPT pending GUI): S1 a failed re-save over a saved list left
      the window declared; S2 per-type saved state (declared only when every calculated type is
      saved); `CDiskMap::Abort` use-after-free fixed (`AbortAndSelfDelete`); probe P1 (`GetWindow`
      on the wrong type), P2 (one folder per Calculate row), C5/C6 rows, M1/M2 scan state read
      from the map's menu, B1 checks the renamer window itself; rebuilt, gates repeated
- [x] T014 GUI runs on `Debug_x64_118` (58 / 0 / 0) and `Debug_x64_pre118` (67 / 0 / 0), hidden
      desktop, registry 1AB614304771DBE0 before and after each; probe-only fixes (fix-log "GUI
      results")
- [ ] T016 OWED TO A PERSON: a real installer update over an installed version with these plug-in windows open, and Disk Map's file tooltip shown during the request (no real mouse in the probe) (`quickstart.md` "Owed to a person")
