# Tasks: FTP panel refreshed after a change made under another name of its server

**Input**: `specs/410-ftp-alias-refresh/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)

## Phase 1: Setup

- [X] T001 Record the measurement at 2ce004b9 (probe rows, commands) in specs/410-ftp-alias-refresh/fix-log.md

## Phase 2: Foundational

- [X] T002 Write the pure rule SalFtpSameUser / SalFtpSamePortText / SalFtpRootMatchOf in src/common/salftproot.h (data-model.md)
- [X] T003 [P] Add saltests checks of the rule (same / other host, other user, anonymous = no user, other port, 21 = no port, case of user) in src/saltests/saltests.cpp
- [X] T004 Add FTPRootPathMatch (split both roots, password zeroed, returns the rule's result) and make FTPHasTheSameRootPath use it in src/plugins/ftp/ftputils.cpp and src/plugins/ftp/ftputils.h

## Phase 3: User Story 1 - the panel shows a change made through another name (P1)

**Independent test**: probe rows REFRESH-ALIAS (FAIL -> PASS), REFRESH-SAME, REFRESH-ELSE (PASS stays).

- [X] T005 [US1] In CPluginFSInterface::AcceptChangeOnPathNotification (src/plugins/ftp/fs3.cpp) refresh on SAL_FTP_ROOT_OTHER_HOST too (same path rule and timing); NextRefreshWontClearCache = TRUE only for the same root, FALSE for another host (FR-003)
- [X] T006 [US1] In the same method, for SAL_FTP_ROOT_OTHER_HOST drop the viewer files of the notified server path under this FS's own root, for ftp: and ftps: (FR-007), refusing (skipping) a name that does not fit

## Phase 4: User Story 2 - a folder entered later is listed again (P2)

**Independent test**: probe rows CACHE-ALIAS (FAIL -> PASS), CACHE-SAME (PASS stays).

- [X] T007 [US2] In CListingCache::AcceptChangeOnPathNotification (src/plugins/ftp/ctrlcon4.cpp) stop comparing the host: same user (SalFtpSameUser) and port drop the matching listings (FR-004)

## Phase 5: Polish & verification

- [X] T008 Add probe rows VIEW-ALIAS / VIEW-SAME (FR-007: a file viewed at 127.0.0.1, the panel elsewhere, a change via localhost, view again -> downloaded again) to specs/410-ftp-alias-refresh/probe/ftp410_probe.ps1, measure them on the old build
- [X] T009 Build (`build.cmd`), encoding guard, saltests; record in specs/410-ftp-alias-refresh/fix-log.md
- [X] T010 Run ftp410_probe.ps1 -> result_after.txt (all PASS) and 341's ftp341_probe.ps1 -> regress_341.txt (12 / 0); negative controls (each half reverted fails its rows)
- [X] T011 Records: fix-log.md before/after, FEATURE-HISTORY entry, CHANGELOG entry, closing report

## Dependencies

T002 -> T003, T004 -> T005, T006, T007 -> T009 -> T010 -> T011. T008 before T009 (its before-run uses the old build).

## Implementation strategy

US1 is the item's point (MVP); US2 is the same defect one step later; both small - one pass.
