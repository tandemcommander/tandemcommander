# Tasks: 7zip plug-in follow-ups

## Phase 1: Setup

- [X] T001 Baseline: saltests count, engine probe of 087 on the Debug engine; record in specs/089-7zip-followups/fix-log.md

## Phase 2: User Story 1 — one RAR association (P1)

- [X] T002 [US1] `CArchiverConfig::NeverBrowses(int)` in src/pack.h, src/pack3.cpp
- [X] T003 [US1] Extension-list helpers `SalExtListContains`, `SalExtListRemove` in new src/common/salarcassoc.h + tests in src/saltests/saltests.cpp
- [X] T004 [US1] Rule C1 in `CSalamanderConnect::AddPanelArchiver` (src/plugins1.cpp)
- [X] T005 [US1] 7zip plug-in: `CURRENT_CONFIG_VERSION` 5, registration per C2 (src/plugins/7zip/7zip.cpp)
- [X] T006 [US1] Registry probe specs/089-7zip-followups/probe/assoc_probe.ps1: three stored configurations end with identical `rar` and `7z` records; a second start changes nothing; the registry is restored

## Phase 3: User Story 2 — surrogate names (P2)

- [X] T007 [US2] WTF-8 fallback in src/plugins/shared/splunicode.h (contract C3)
- [X] T008 [US2] Parity and round-trip tests against the core converters in src/saltests/saltests.cpp
- [X] T009 [US2] 7zip plug-in converters on the shared ones (src/plugins/7zip/structs.h)

## Phase 4: User Story 3 — cleaned names when updating (P3)

- [X] T010 [US3] Cleaned names in `GetArchiveItemList` (src/plugins/7zip/7zclient.cpp)

## Phase 5: Polish

- [X] T011 Gates: Debug + Release builds (every plug-in uses splunicode.h), saltests, encoding guard, 087 engine probe, 088 probes (regression)
- [X] T012 Independent review; fixes
- [X] T013 Records: CHANGELOG, NEXT-WORK, CLAUDE.md, note in 087 contract P8, fix-log, quickstart; commit

## Dependencies

US1, US2 and US3 are independent; US2 and US3 both touch the 7zip plug-in
(structs.h / 7zclient.cpp, different files).
