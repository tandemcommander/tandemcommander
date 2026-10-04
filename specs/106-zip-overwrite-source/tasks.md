# Tasks: feature 106

- [X] T001 Research (research.md): every pack route that writes or deletes an output, measured on the build before with `probe/packself_probe.ps1`; preserve `Debug_x64_pre106`
- [X] T002 Spec (Clarifications), plan, tasks, checklist
- [X] T003 [US1][US2] S1 rule: `SalPackOutputIsSource`, `SalPackTargetInSelection` in `src/common/salsamefile.h`
- [X] T004 [US2] S2 core: `PackArchiveIsSelectedSource` + refusal in `CFilesWindow::Pack` (`fileswn7.cpp`)
- [X] T005 [US1][US3] S3 ZIP: listing first, `IsPackedSource` / `RefusePackedSource`, `TempNameOurs` (`add.cpp`, `add_del.{h,cpp}`), `IDS_PACKEDSOURCE` (`zip.rh2`, `lang/lang.rc2`)
- [X] T006 S4 saltests `TestPackSelf106`
- [X] T007 S5 translations of `IDS_PACKEDSOURCE` (8 languages, pinned)
- [X] T008 [US1][US2][US3] S6 probe on both builds (hidden desktop)
- [X] T009 Gates: Debug + full Release, saltests, strict encoding guard, regression probes 094 ZIP, 099 linkmove, 097 arcwork (subset), 103 samefile
- [X] T011 Review changes: SF-1 size filter removed, N2 check box not stored after a refused/failed Overwrite, N3 second pass never "ours", Romanian pin without comma-below letters; probe rows C-hardlink-stale, A-zip-noask-refused
- [X] T012 Re-run: Debug build, saltests, guard, probe on both builds, full Release build
- [X] T010 Records: fix-log, NEXT-WORK, CHANGELOG `[Unreleased]`; PRIVACY.md checked (no change); the CLAUDE.md entry proposed in the fix-log; no commit (the coordinator commits after an independent review)
