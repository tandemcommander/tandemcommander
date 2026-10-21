# Tasks: Adding into a ZIP that holds names differing only in case replaces only the named member

**Input**: `specs/290-zip-add-case-twins/` (spec.md, plan.md, research.md, data-model.md,
contracts/zip-add-case-twins.md, quickstart.md)
**Tests**: unit checks (saltests) and the hidden-desktop probe are part of the item's *Approach*.

## Phase 1: Setup

- [X] T001 Probe `specs/290-zip-add-case-twins/probe/zip290_probe.ps1` and its before-run `probe/result_before.txt` in the feature folder (measured at 1e402ea2: 6 FAIL / 12 PASS), recorded in `specs/290-zip-add-case-twins/fix-log.md`

## Phase 2: Foundational (the rules)

- [X] T002 [P] Add `SalPathsHaveCaseTwins(paths, count, lowMemory)` (every whole-part prefix of every path, 252's `HaveTwinsInPlace`) to `src/common/salcasetwins.h` per contract point 1
- [X] T003 [P] Add the `nameIgnoreCase` parameter (default TRUE) to `SalZipMemberIs` and `SalZipMemberIsOrIsIn` in `src/common/salzipname.h` per contract point 2
- [X] T004 Add `TestPathTwins290` to `src/saltests/saltests.cpp`: the item's cases (D\x.txt + d\y.txt, A.txt + a.txt), no twins (Docs\f.txt + z.txt, D\x.txt + D\y.txt, a folder entry D\ with D\x.txt), a file and a folder differing in case, duplicates, edges (NULL, 0, 1), lengths, legacy-fold pair, low-memory flag cleared; a randomized cross-check against `SalDirTreeHasCaseTwins` on the tree the same paths build; `SalZipMemberIs` / `SalZipMemberIsOrIsIn` with `nameIgnoreCase` FALSE

## Phase 3: User Story 1 - adding into a twin ZIP replaces only the exact name (P1)

**Independent test**: probe rows ZIP-ADDDIR, ZIP-ADDFILE, ZIP-ADDFOLDER, ZIP-NEWNAME, UNIX-ADDFILE, UNIX-ADDFOLDER pass.

- [X] T005 [US1] In `src/plugins/zip/add.cpp` `CZipPack::MatchFiles`: collect every member name (`ProcessName`) in the pre-pass over `NewCentrDir`, call `SalPathsHaveCaseTwins`; low memory -> IDS_LOWMEM before any question; twins -> `pathFlag = 0` and `nameIgnoreCase` FALSE in both `SalZipMemberIs` and `SalZipMemberIsOrIsIn` calls; `Unix` unchanged
- [X] T006 [US1] Build (`.\build.cmd`), saltests, encoding guard; confirm by reading that the new collection works on `NewCentrDir` in memory and adds no read of the archive file (FR-004 / SC-003); record in `specs/290-zip-add-case-twins/fix-log.md`
- [X] T007 [US1] Run the probe (after) on the hidden desktop -> `specs/290-zip-add-case-twins/probe/result_after.txt`, every row PASS
- [X] T008 [US1] Negative control: force the twin switch off in `src/plugins/zip/add.cpp`, rebuild, run the probe -> the six twin rows FAIL (`probe/result_negctl_no_twin_switch.txt`); restore, rebuild

## Phase 4: User Story 2 - ordinary ZIPs as before (P1)

**Independent test**: ZIP-CONTROL, UNIX-CONTROL, UNIX-ADDDIR pass before and after; 110's and 271's probes stay green.

- [X] T009 [US2] Regression probes on the final build: `specs/110-zip-plugin-name-matching/probe/zipname_probe.ps1` -> `specs/290-zip-add-case-twins/probe/regress_zipname110_290.txt`; `specs/271-zip-case-twins/probe/zip271_probe.ps1` -> `probe/regress_zip271_290.txt`

## Phase 5: Polish

- [X] T010 Fix-log *Work*, *Checks*, *Measured (after)* complete in `specs/290-zip-add-case-twins/fix-log.md` (registry restore hashes of every probe run)

## Dependencies

T001 -> T002, T003 (parallel) -> T004 -> T005 -> T006 -> T007 -> T008 -> T009 -> T010.

## Implementation strategy

One increment: the rule (T002-T004) and its single consumer (T005); the probe proves both stories at
once.
