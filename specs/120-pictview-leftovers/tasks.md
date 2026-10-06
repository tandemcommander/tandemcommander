# Tasks: feature 120

- [X] T001 Research (research.md): consumers of the engine's rows (code reading); harness on the build before (git HEAD) - pipette, histogram, turn + background; GIF encoder measurement (scratch); preserve `Debug_x64_pre120`
- [X] T002 Spec (Clarifications), plan, tasks, checklist
- [X] T003 [US1] `src/common/salpvpixel.h`; `PixelAccess.cpp` on it; `WicGetRowsSize`
- [X] T004 [US1] pipette glue: mirror mapping, 64-bit mapping, status bar (`render1.cpp`, `statsbar.cpp`)
- [X] T005 [US2] Rename onto a shown target: release/retake of the target's windows, `sfaReplaced` (`render1.cpp`, `renderer.h`)
- [X] T006 [US3] rotation kept across a new background color (`wicengine.cpp`)
- [X] T007 GIF comment decision recorded (`wicengine.cpp` comment)
- [X] T008 saltests `TestPvPixel120` (14,655 -> 17,423)
- [X] T009 Harness `probe/pixharness/` on both builds: new 0 mismatches, old 2,295
- [X] T010 Probe `probe/pv120_probe.ps1` (+ `mkfix120.py`, `ref120.py`) written; parse + C# compile + the bar reader checked on a synthetic capture
- [X] T011 Gates: Debug build, full Release build, saltests, strict encoding guard, clang-format of the touched code
- [X] T012 Records: fix-log, NEXT-WORK, CHANGELOG `[Unreleased]`; CLAUDE.md entry proposed in the fix-log; no commit
- [ ] T013 GUI runs (owed): pv120 probe on `Debug_x64_120` and `Debug_x64_pre120`; regressions 111 shown_probe and 105 saveas_probe on `Debug_x64_120`; pipette rows on the visible desktop with the maintainer's agreement
- [ ] T014 Independent review
