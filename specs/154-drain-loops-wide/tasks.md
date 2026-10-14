# Tasks: 154 - wide drain loops

- [x] T001 Probe `specs/154-drain-loops-wide/probe/drain_loop_probe.ps1`; the build before: susp-cyrillic FAIL
- [x] T002 [US1] Nine dispatching loops wide (`src/dialogs.cpp`, `src/dialogs6.cpp`, `src/mainwnd2.cpp`, `src/mainwnd3.cpp`, `src/pack3.cpp`, `src/regwork.cpp`, `src/zip.cpp`, `src/viewer2.cpp`)
- [x] T003 Review; the viewer change described as consistency only
- [x] T004 The probe made deterministic (the target thread held while posting); 7 of 7 before, 4 of 4 after
- [x] T005 Regression 093 cmdline, dialogs; the Find menu rows sampled and bisected (not 154)
- [x] T006 Records; commit
