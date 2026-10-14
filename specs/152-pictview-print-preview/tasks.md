# Tasks: 152 - PictView's print preview

- [x] T001 Cause by reading (`print.cpp CreatePreview`, `wicengine.cpp WicSaveImage`)
- [x] T002 `WM_PRINTCLIENT` in `CPreviewWnd`; the control build `Debug_x64_pre152`
- [x] T003 [US1] Probe `specs/152-pictview-print-preview/probe/print_preview_probe.ps1` + `mkfix152.py`; control: every PREVIEW row FAIL
- [x] T004 [US1] `CreatePreview` drawn through the engine's stretch (`print.cpp`), `DisplayStretchX/Y` (`dialogs.h`, `render1.cpp`), cache key `bSelection`
- [x] T005 [US1] Negative control without the stretch given back: VIEWER rows FAIL (after the check was tightened)
- [x] T006 Review; the live stretch after `Execute()`, comments
- [x] T007 Regression: 120 `tgt-shown-print`, `bk-rot`
- [x] T008 Records (NEXT-WORK, FEATURE-HISTORY, CHANGELOG); commit
