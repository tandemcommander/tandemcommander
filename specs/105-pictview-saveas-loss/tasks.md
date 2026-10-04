# Tasks: feature 105

- [X] T001 Research (research.md): the defect measured on the build before (every save fails; "replace?" Yes deletes first), every PictView write route, what the Windows encoders write, ReplaceFileW/MoveFileExW behaviour; preserve `Debug_x64_pre105`
- [X] T002 Spec (Clarifications), plan, tasks, checklist
- [X] T003 [US1] S1 rule: `src/common/salsafereplace.h`
- [X] T004 [US2] S2 engine: encoder table, `PVIsOutCombSupported`, `WicEncodeImageToFile`, `WicDetachSource` (`wicengine.{h,cpp}`)
- [X] T005 [US1][US2][US3] S3 Save As: `saveas.cpp`, `renderer.h`; menu item (`pictview.cpp`)
- [X] T006 [US1] S4 the other routes: `thumbs.cpp` Regenerate thumbnail, `render1.cpp` Rename overwrite
- [X] T007 S5 saltests `TestSafeReplace105`
- [X] T008 [US1][US2][US3] S6 probe `probe/saveas_probe.ps1` on both builds (hidden desktop)
- [X] T009 Gates: Debug + Release, saltests, strict encoding guard, regression probes 104 (PictView), 088 viewers, 103 samefile
- [X] T010 Records: fix-log, NEXT-WORK, CHANGELOG `[Unreleased]`; PRIVACY.md checked; the CLAUDE.md entry proposed in the fix-log; no commit (the coordinator commits after an independent review)
