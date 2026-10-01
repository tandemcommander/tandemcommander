# Tasks: Plug-in interface 107

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [contracts/plugin-api-v107.md](contracts/plugin-api-v107.md)

## Phase 1: Setup

- [ ] T001 Baseline: full Debug build of the branch base, saltests count, 080 probe `rm_probe.ps1` against the Debug build with no viewer open (agrees) and with a Code Viewer window open (declines) — recorded in specs/088-plugin-interface-107/fix-log.md
- [ ] T002 Probe scaffolding in specs/088-plugin-interface-107/probe/: a driver that starts the Debug build on a prepared folder, opens a window of each viewer, and runs the Restart Manager sequence (reusing specs/080-restart-manager-upgrade/probe/*.ps1); registry backup/restore of `HKCU\Software\Tandem Commander`

## Phase 2: Foundational — the interface, documented first (S1)

- [ ] T003 Contract contracts/plugin-api-v107.md final; history entry and `LAST_VERSION_OF_SALAMANDER 107` + `REQUIRE_LAST_VERSION_OF_SALAMANDER` in src/plugins/shared/spl_vers.h
- [ ] T004 Header: `IsUnattendedClose`, `SetWindowClosesUnattended` appended with full comments in src/plugins/shared/spl_gen.h; `SAL_MAX_PATH_UTF8` in src/plugins/shared/spl_base.h with `#ifndef` (and the same guard in src/common/salpath.h); corrected buffer comments (contract B2) in spl_gen.h and src/consts.h
- [ ] T005 Core overrides in src/plugins.h and src/zip.cpp (`IsUnattendedClose` → `UnattendedClose`; `SetWindowClosesUnattended` → window property)
- [ ] T006 Rule D8: `ClosesUnattended` in `CSalCloseAppWindow`, `SalCloseAppWindowIsForeign` in src/common/salcloseapp.{h,cpp}; enumeration reads the property in src/mainwnd3.cpp
- [ ] T007 Tests: extend `TestCloseApp080` (declared window passes; declared but invisible/tool unchanged; undeclared still declines; a declared window plus an undeclared dialog declines) in src/saltests/saltests.cpp
- [ ] T008 Build Debug, saltests; independent review; commit `[088] S1 …`

## Phase 3: User Story 1 — update with viewer windows open (P1) (S2)

- [ ] T009 [US1] Code Viewer: declare the viewer window when created, silent close in `Release` during an unattended close (src/plugins/codeview/)
- [ ] T010 [P] [US1] Markdown Viewer: same (src/plugins/mdview/)
- [ ] T011 [P] [US1] PictView: same (src/plugins/pictview/)
- [ ] T012 [P] [US1] Database Viewer: same (src/plugins/dbviewer/)
- [ ] T013 [US1] FTP: no question during an unattended close, return FALSE when operations exist (src/plugins/ftp/ftp.cpp)
- [ ] T014 [US1] Probes: (a) each viewer alone and all four together → agree, process ends, nothing shown; (b) viewer with its own dialog open → declines; (c) File Comparator window → declines; (d) normal exit with a viewer open → the plug-in's question appears (unchanged); (e) the 080 regression set (busy states decline, plain agree, restart). Record in fix-log.md
- [ ] T015 [US1] Independent review; commit `[088] S2 …`

## Phase 4: User Story 2 — long names to viewers (P1) (S3)

- [ ] T016 [US2] B3 guard: pure rule `SalViewerNameFitsPlugin(builtForVersion, nameLen)` in a new src/common/salplugver.h (header-only), used in src/zip.cpp `CSalamanderGeneral::Get{Next,Previous}FileNameForViewer`; unit test in src/saltests/saltests.cpp
- [ ] T017 [P] [US2] PictView buffers (src/plugins/pictview/pictview.cpp, render1.cpp)
- [ ] T018 [P] [US2] Database Viewer buffers (src/plugins/dbviewer/dbviewer.cpp)
- [ ] T019 [P] [US2] mmviewer, demoview, demoplug buffers incl. `SalSplitGeneralPath` callers (src/plugins/mmviewer, demoview, demoplug)
- [ ] T020 [US2] Examine `CheckAndCreateDirectory` `firstCreatedDir` and in-tree callers; fix or record
- [ ] T021 [US2] Long-path probe: folder with a 300+ character path, two pictures and two `.dbf`; next/previous in PictView and Database Viewer of the Debug build; record
- [ ] T022 [US2] Independent review; commit `[088] S3 …`

## Phase 5: User Story 3 and polish (S4)

- [ ] T023 [US3] Manual: correct the "close viewer windows before updating" sentence in help/; architecture/06-plugin-architecture.md gains interfaces 105–107; constitution's stale "interface version 105" line left to the maintainer (governance document) — recorded
- [ ] T024 Gates: full Debug + `build.cmd full release`, saltests, encoding guard, runtime closure, a plug-in binary built before this feature loads in the new Debug build (SC-005), interface diff is additions only (SC-006)
- [ ] T025 Records: CHANGELOG *Unreleased*, specs/NEXT-WORK.md item 4, specs/080-restart-manager-upgrade/REMAINING-WORK.md P2, CLAUDE.md, PRIVACY.md check (no change expected), fix-log.md, quickstart.md
- [ ] T026 Final independent review; commit `[088] Records …`

## Dependencies

S1 blocks S2 and S3. S2 and S3 touch different files except pictview and
dbviewer (T011/T017, T012/T018) — S2 first. T010–T012 parallel after T009
sets the pattern.
