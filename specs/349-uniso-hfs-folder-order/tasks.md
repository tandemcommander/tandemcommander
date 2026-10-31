# Tasks: ISO plug-in - an HFS+ folder whose ID is lower than its parent's lists its contents in it

**Input**: Design documents from `specs/349-uniso-hfs-folder-order/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

Tests: the spec asks for unit checks of the rule (FR-007) and the probe rows (SC-001).

## Phase 1: Setup

- [ ] T001 Probe files in place and measured before: `specs/349-uniso-hfs-folder-order/probe/iso349_probe.ps1`, `mkimg349.sh`, `img349.py`, `result_before.txt` (5 / 3); fix-log `specs/349-uniso-hfs-folder-order/fix-log.md` started

## Phase 2: Foundational (the pure rule)

- [ ] T002 Add `CSalHfsFolderOrder` and `SAL_HFS_PENDING_OK / _LOOP / _NO_MEMORY` (Add, Seal, IsTaken, Take, Pending - data-model.md) to `src/common/salisonamefit.h`, with its header comment (feature 349)
- [ ] T003 Add `TestHfsFolderOrder349` to `src/saltests/saltests.cpp` and call it from the test list: in-order chain (nothing pending), moved chains (a into b into c: pending outermost first), taken parents stop the walk, unknown parent, self-parent and two-folder loops (LOOP, each record once), a loop reached from a descendant, duplicate IDs (first record), a deep reversed chain of 10,000 folders (no recursion), Take of a record not in the table, Add out of order refused; plus a simulation of the listing walk over the probe's catalogs (move / long / cycle) giving the expected paths and left-out sets
- [ ] T004 Build (`.\build.cmd`) and run saltests -> 0 failed; mutants (no pending walk / no loop stamp) fail - record in fix-log.md

## Phase 3: User Story 1 - the contents of a moved folder stay in it (P1)

**Independent test**: probe row H-MOVE.

- [ ] T005 [US1] Move the per-record body of `CHFS::ListDirectory` into a member `BOOL CHFS::ListRecord(int i, HFSPlusCatalogKey* pKey, const SalHfsCatalogKey& key, char* rootPath, CSalamanderDirectoryAbstract* dir, CPluginDataInterfaceAbstract*& pluginData, CSalLeftOutIds& leftOut)` (TRUE = go on, FALSE = the listing ends; `continue` -> `return TRUE`) in `src/plugins/uniso/hfs.cpp`, declared in `src/plugins/uniso/hfs.h`
- [ ] T006 [US1] First pass in `CHFS::ListDirectory` (`src/plugins/uniso/hfs.cpp`): every record classified `SAL_HFSREC_FOLDER` -> `order.Add(folderID, key parentID, i)`; `Seal`; out of memory -> `ListingLeftOut.SetIncomplete()` + `Error(IDS_INSUFFICIENT_MEMORY)`, return FALSE
- [ ] T007 [US1] In the loop: skip a record already taken; for a listable / not-handled record, take its pending folders first (`CHFS::TakePending`: each pending record fetched again, classified, `Take` then `ListRecord`); then `Take(i)` and the record itself; the comment "our parent must have been parsed already" replaced

## Phase 4: User Story 2 - a left-out folder takes its subtree (P2)

**Independent test**: probe row H-LONG.

- [ ] T008 [US2] Verify in `src/plugins/uniso/hfs.cpp` that a pending folder the listing rule refuses goes into `leftOutFolders` before its contents are taken (follows from T007: the folder is taken through `ListRecord`); nothing else of `ListRecord` changes (FR-006 - a folder whose name does not convert stays skipped as before)

## Phase 5: User Story 3 - a loop of parents (P3)

**Independent test**: probe row H-CYCLE.

- [ ] T009 [US3] `SAL_HFS_PENDING_LOOP` in `CHFS::TakePending` (`src/plugins/uniso/hfs.cpp`): every returned record taken, its folder ID added to `leftOutFolders` (out of memory -> incomplete + error, end), `ListingLeftOut.SetIncomplete()`, `TRACE_E`; the record itself is then skipped if it was in the loop, else `Under` skips it

## Phase 6: Polish & verification

- [ ] T010 `python tools/check_encoding.py --strict` -> TOTAL: 0
- [ ] T011 `.\build.cmd` -> BUILD SUCCEEDED; saltests 0 failed
- [ ] T012 Probe after: `result_after.txt` -> 8 / 0 (4 RUN rows PASS)
- [ ] T013 Regression probes 322, 329, 332, 333, 339 -> their recorded results (`probe/regress_<n>.txt`)
- [ ] T014 fix-log.md: before / after, commands, mutants, regressions

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 / T009 -> T010 .. T014. One file per phase
mostly; little parallelism (T010 with T011).

## Implementation strategy

MVP = US1 (T005-T007); US2 and US3 are small additions in the same function, verified by their rows.
