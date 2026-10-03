# Tasks: feature 103

- [X] T001 Research (research.md): every delete/overwrite site, Windows' answers, identity, local reproduction on the build before 103 (WebDAV folding server)
- [X] T002 Spec, plan, tasks; preserve the pre-change build (`Debug_x64_pre103`), remove `Debug_x64_pre101`
- [X] T003 [US1][US2] S1 rule: `src/common/salsamefile.h`, facade in `salfileio.{h,cpp}`
- [X] T004 [US1] S2 core rename/move: `DoMoveFile`, `RenameFileInternal`
- [X] T005 [US2] S2 core copy: `DoCopyFile` refusal (also every move between two roots)
- [X] T006 [US1] S3 plug-ins: Renamer `CRenamerDialog::MoveFile`, PictView `RenameFileInternal`
- [X] T007 S4 saltests `TestSameFile103`
- [X] T008 [US1][US2][US3] S5 probe `probe/samefile_probe.ps1` + `probe/davnorm.py`; both builds
- [X] T009 Independent review; fixes
- [X] T010 Gates: Debug + Release, saltests, guard, regression probes 092/095/096/098/099/101
- [X] T011 Records (fix-log, NEXT-WORK, CHANGELOG; the CLAUDE.md entry is proposed in the fix-log for the maintainer); no commit (maintainer away)
