---
description: "Tasks for feature 365 - NRG ETNF / ETN2 and CloneCD track tables"
---

# Tasks: The ISO plug-in reads NRG ETNF / ETN2 and CloneCD track tables with the right sector sizes, sessions and ends

**Input**: `specs/365-nrg-ccd-track-tables/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)

**Tests**: required by the spec (FR-010 `saltests`, SC-001..SC-004 probe and regressions).

## Phase 1: Setup

- [ ] T001 Copy the measurement assets into `specs/365-nrg-ccd-track-tables/probe/` (`iso365_probe.ps1`, `mkimg365.sh`, `img365.py`, `result_before.txt`) and record the before measurement in `specs/365-nrg-ccd-track-tables/fix-log.md`

## Phase 2: Foundational (pure rules)

- [ ] T002 [P] Add `SalNrgModeVerified`, `SalNrgEtnSectorSize`, `SalNrgEtnEntry` / `SalNrgEtnDecode`, `SalNrgEtnEnd`, `SalNrgEtnEntryCount`, `SalNrgEtn2ChunkPlausible` (+ `SAL_NRG_ETNF_ENTRY`, `SAL_NRG_ETN2_ENTRY`, `SAL_NRG_ETN_MAX_ENTRIES`) with a header comment section "feature 365" to `src/common/salnrgcdtext.h`
- [ ] T003 [P] Add `SalIsoCcdSectorCount` and `SalIsoCcdTocLayout` (+ `SalIsoCcdTocEntry`, `SalIsoCcdTocTrack`, `SAL_ISO_CCD_TOC_NONE / _OK / _INCONSISTENT`) to `src/common/salisotrack.h`
- [ ] T004 Add `TestNrgEtn365` (mode table incl. fallbacks, ETNF / ETN2 decoding of known bytes, end saturation, entry counts, 99-entry bound) and `TestIsoCcdToc365` (relative and absolute two-session tables give the same layout; a one-session table; a hole in the points, a missing lead-out, a negative PLBA, sessions going backwards, two disagreeing entries -> NONE; a lead-out before the last track and a decreasing PLBA -> INCONSISTENT with 0 sectors; `SalIsoCcdSectorCount`) to `src/saltests/saltests.cpp` and call them from the test list; build and run saltests; check a mutant of each rule fails

## Phase 3: User Story 1 - Nero ETNF / ETN2 (P1)

**Goal**: probe rows R-ETNF05, R-ETNF06, R-ETN200, R-ETN203, R-ETN206 pass; C-ETNF00, C-ETN2ONE still pass.

- [ ] T005 [US1] `readETNF` takes its sector size from `SalNrgEtnSectorSize(mode, false)` in `src/plugins/uniso/nrg.cpp`
- [ ] T006 [US1] Rewrite `readETN2` in `src/plugins/uniso/nrg.cpp`: chunk read only when `SalNrgChunkFits` and `SalNrgEtn2ChunkPlausible` hold (else skipped as `readCUEX`), one track per whole 32-byte entry (start, `SalNrgEtnEnd`, verified mode -> `SetTrackTypeMode` else Mode 1 / ISO 9660, `SalNrgEtnSectorSize(mode, true)`, header size, extent = sector field), the file position right after the chunk

## Phase 4: User Story 2 - CloneCD sessions by the table of contents (P2)

**Goal**: R-CCDABS passes, C-CCDREL still passes; 352's R-TWOSEC still kept.

- [ ] T007 [US2] In `CISOImage::ReadSessionCCD` (`src/plugins/uniso/img.cpp`) compute `SalIsoCcdTocLayout` after the tracks are built; when followed: the sessions are its runs (`AddSessionTracks`), each track gets `SectorSize` 0x930, header size, `ExtentOffset` = PLBA, `Start` / `End` from its first sector and count; INCONSISTENT marks `ListingLeftOut`; else the 41f18c08 path; 352's `SalIsoCcdLayoutTrusted` check after both

## Phase 5: User Story 3 - no wrapped ends (P3)

- [ ] T008 [US3] The 41f18c08 path of `ReadSessionCCD` (`src/plugins/uniso/img.cpp`) computes sector counts by `SalIsoCcdSectorCount` in signed arithmetic (a negative count: 0 and `ListingLeftOut.SetIncomplete()`)

## Phase 6: Polish & verification

- [ ] T009 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; `.\build.cmd` -> `BUILD SUCCEEDED`; saltests -> 0 failed
- [ ] T010 Run `specs/365-nrg-ccd-track-tables/probe/iso365_probe.ps1` on the hidden desktop -> 18 / 0 (`probe/result_after.txt`)
- [ ] T011 Regressions on the hidden desktop: 352 (R-ABS changes by design, others PASS), 351, 334, 335, 353 probes -> `probe/regress_<NNN>.txt`, compared with their recorded results
- [ ] T012 Update `specs/365-nrg-ccd-track-tables/fix-log.md` (after, checks, mutants, regressions)

## Dependencies

T001 -> T002 / T003 (parallel) -> T004 -> T005 -> T006 (US1); T007 -> T008 (US2 / US3, same function); T009 after all code; T010 - T012 after T009.

## Implementation strategy

MVP = US1 (the wrong-content ETN2 case). US2 and US3 share `ReadSessionCCD` and follow. Every row is
verified by the probe; the rules by saltests with mutants.
