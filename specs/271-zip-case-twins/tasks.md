# Tasks: A ZIP that holds names differing only in case is case-sensitive

**Input**: `specs/271-zip-case-twins/` (spec.md, plan.md, research.md, data-model.md,
contracts/zip-case-sensitivity.md, quickstart.md)
**Tests**: the hidden-desktop probe `probe/zip271_probe.ps1` (written and run before the change at
671ae06b: 6 FAIL / 10 PASS); the twin rule's unit checks exist (252).

## Phase 1: Setup

- [X] T001 Start `specs/271-zip-case-twins/fix-log.md` with the measurement before (probe
  `probe/result_before.txt`, 6 FAIL) and the consumers of `CZipCommon::Unix` (research R3)

## Phase 2: Foundational

- [X] T002 Add `BOOL CaseSensitive` to `CZipList` (initialised FALSE in its constructor) in
  `src/plugins/zip/list.h`
- [X] T003 Add `BOOL CaseSensitive` to `CPluginDataInterface` (constructor argument, default FALSE)
  in `src/plugins/zip/zipdll.h`

## Phase 3: User Story 1 + 2 - the listing is case-sensitive with twins (P1)

**Goal**: a twin ZIP lists twins and folders D / d apart (FR-001, FR-002, FR-003).
**Independent test**: probe rows ZIP-HIDE, ZIP-GLOBAL, ZIP-TREE, ZIP-CONTROL.

- [X] T004 [US1] In `CZipList::List` (`src/plugins/zip/list.cpp`): include
  `../../common/salcasetwins.h`; `dir->SetFlags(SALDIRFLAG_CASESENSITIVE)` before the first entry
  (after `START_LIST`); after the loop `CaseSensitive = Unix || SalDirTreeHasCaseTwins(dir)` and
  `dir->SetFlags(0)` when not; keep the Unix restart path unchanged
- [X] T005 [US1] In `CPluginInterfaceForArchiver::ListArchive` (`src/plugins/zip/main.cpp`): create
  the plug-in data with `list.CaseSensitive`

## Phase 4: User Story 2 - operations follow the listing (P1)

**Goal**: copying / deleting / viewing one twin or one twin folder never reaches the other (FR-004).
**Independent test**: probe rows ZIP-ONE, ZIP-DEL, UNIX-ONE, UNIX-DEL.

- [X] T006 [US2] In `src/plugins/zip/main.cpp` `UnpackArchive`, `UnpackOneFile`,
  `DeleteFromArchive`: when `pluginData` is set and its `CaseSensitive` is TRUE, set the operation
  object's `Unix = TRUE` before it enumerates the selection
- [X] T007 [US2] In `CZipUnpack::UnpackOneFile` (`src/plugins/zip/extract.cpp`): OR the entry's
  `CZIPFileData::Unix` into `Unix` instead of overwriting it

## Phase 5: User Story 3 - ordinary ZIPs unchanged (P1)

- [X] T008 [US3] Confirm by the probe's ZIP-CONTROL row and by reading that a ZIP without twins and
  Unix entries ends with flags 0 and `CaseSensitive` FALSE (operations unchanged), and that no new
  restart of the listing (second read of the central directory) was added (SC-003)

## Phase 6: Polish

- [X] T009 `python tools/check_encoding.py --strict` -> TOTAL 0; `.\build.cmd` -> BUILD SUCCEEDED;
  saltests -> 0 failed
- [X] T010 Run the probe after (`probe/result_after.txt`): 16 / 0 expected
- [X] T011 Negative control: T006 disabled -> ZIP-ONE / ZIP-DEL / UNIX-* fail; restore, rebuild,
  re-run after (`probe/result_negctl_no_listing_switch.txt`)
- [X] T012 Check adding into a twin ZIP (spec Assumptions) by reading `src/plugins/zip/add.cpp`
  `CZipPack::MatchFiles`; a defect -> backlog Inbox item (measure:271)
- [X] T013 Add ZIP to the person step `backlog/items/paste-of-a-case-twin-from-an-archive-and-sftp-twins-by-hand/desc.md`
  (clipboard Paste of a twin, not drivable here) via `BL log` / editor
- [X] T014 Record checks and results in `specs/271-zip-case-twins/fix-log.md`

## Dependencies

T001 -> T002, T003 -> T004 -> T005 -> T006, T007 -> T008 -> T009 -> T010 -> T011; T012, T013 any time
after T001; T014 last. T002 / T003 [different files] could run in parallel.

## Implementation strategy

One build: US1 and US2 ship together - US1 alone would make deleting one of the folders D / d of a
Windows-made ZIP delete both (research R2), so it is not a viable increment on its own.
