# Tasks: feature 111

- [X] T001 Research (research.md): the defects measured on the build before (probe on `Debug_x64_pre111`), what the WIC decoders report, what the encoders write for comments and what Windows reads back, the wallpaper path (code only - never driven); preserve `Debug_x64_pre111`
- [X] T002 Spec (Clarifications), plan, tasks, checklist
- [X] T003 [US1][US2] S1 engine: `WicReattachSource`, `WicDetachSource` remembers the frames (`wicengine.{h,cpp}`)
- [X] T004 [US3] S1 engine: `WicGetSourceFormat`, alpha use at decode; `src/common/salpvsource.h`
- [X] T005 [US1][US2] S2 release/retake across the viewer windows; Rename, Delete (`render1.cpp`, `renderer.h`, `pictview.{h,cpp}`)
- [X] T006 [US2][US3] S3 Save As: `EncodeReplaceSafe`, retake instead of reload, source format for the question / list / default depth; title, Image Information (`saveas.cpp`, `render1.cpp`)
- [X] T007 [US4] S4 wallpaper with the dry-run seam (`render2.cpp`); `PRIVACY.md`
- [X] T008 Comments: TIFF XMP `dc:description`, JPEG COM without the NUL (`wicengine.cpp`)
- [X] T009 S5 saltests `TestPvSource111`
- [X] T010 [US1-US4] S5 probe `probe/shown_probe.ps1` on both builds (hidden desktop); the real wallpaper checked before/after
- [X] T011 Gates: Debug + Release, saltests, strict encoding guard, regression probes 105, 103, 104 (PictView), 088 (PictView)
- [X] T012 Records: fix-log, NEXT-WORK, CHANGELOG `[Unreleased]`, PRIVACY.md; the CLAUDE.md entry proposed in the fix-log; no commit (the coordinator commits after an independent review)
- [X] T013 Independent review REJECT (B1 window that moved on, S1 busy image, S2 wallpaper backup, S3 multi-page title, NITs): fixed; probe rows r-nav-del, r-nav-ren, r-multi, r-print, r-busy, hl-del, info-cmyk, wp-restore with no backup; probe on both builds, regressions 105 + 103, Release build
- [X] T014 Re-review REJECT (take-back without operation id): code fixed, builds and saltests green; T015 code-only re-check ACCEPT; GUI re-run done 2026-10-05 evening (fix-log T015): probe 85 / 0 / 2 incl. r-cross on `Debug_x64_111`, 50 / 29 / 7 on `Debug_x64_pre111`, regressions 105 56 / 0 / 4 (0 lost) and 103 62 / 0
