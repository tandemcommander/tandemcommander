# Tasks: feature 107

- [X] T001 Preserve the pre-change build (`Debug_x64_pre107`, without `Intermediate`); `.specify/feature.json`
- [X] T002 Research: Windows' answers for folder aliases (scratch P/Invoke probe), the core's by-name checks, every route that builds a folder copy/move script (`research.md`)
- [X] T003 Measurement probe `probe/folderalias_probe.ps1` on `Debug_x64_pre107` (`probe/folderalias_result_pre107.txt`)
- [X] T004 Spec, plan, tasks, checklist; decisions in spec.md Clarifications
- [X] T005 [US1][US2][US3][US4] S1 rules: `src/common/salsamefile.h`; facade in `salfileio.{h,cpp}`
- [X] T006 [US1][US2][US3] S2 script build: `fileswn6.cpp DirTargetIsSource107`, `CDirTargetChain107`, resets in `BuildScriptMain`, `BuildScriptMain2`, `MoveFiles`
- [X] T007 [US1] S3 worker: `DoCreateDir` refusal before "Confirm Directory Overwrite"
- [X] T008 [US4] S3 worker: `DoCopyFile` same-entry answer for a hard-linked source
- [X] T009 S4 saltests `TestFolderAlias107`
- [X] T010 [US1-US5] S5 probe on this build (`-Expect107`) and on `Debug_x64_pre107`
- [X] T011 Regression: 103 samefile (`-Expect103`), 099 linkmove, 098 fix_probe, 106 packself (`probe/regress_*_107.txt`)
- [X] T012 Gates: Debug + full Release build, saltests, strict encoding guard
- [X] T013 Hostile re-read of the diff; records (fix-log, CHANGELOG, NEXT-WORK; the CLAUDE.md entry proposed in the fix-log); no commit (the maintainer commits after an independent review)
