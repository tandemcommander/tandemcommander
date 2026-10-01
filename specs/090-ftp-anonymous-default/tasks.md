# Tasks: FTP anonymous placeholder

- [X] T001 [US1] Create src/common/salftpanon.h: `SAL_FTP_ANONYMOUS_DEFAULT`, `SAL_FTP_ANONYMOUS_OLD_DEFAULT`, `SalFtpAnonymousOnLoad(stored)`
- [X] T002 [US1] Tests `TestFtpAnon090` in src/saltests/saltests.cpp
- [X] T003 [US1] Default in `CConfiguration::CConfiguration` (src/plugins/ftp/ftp3.cpp) and the rule in `LoadConfiguration` (src/plugins/ftp/ftp.cpp)
- [X] T004 [US1] PRIVACY.md (two sentences + validity paragraph), CHANGELOG.md *Unreleased*
- [X] T005 Gates: Debug + Release builds, saltests, encoding guard, `grep someserver` finds only the old-placeholder constant and the records
- [X] T006 Independent review; fixes
- [X] T007 Records: specs/NEXT-WORK.md item 7, CLAUDE.md, specs/090-ftp-anonymous-default/fix-log.md, quickstart.md; commit
