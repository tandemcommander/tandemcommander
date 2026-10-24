---
description: "Tasks of feature 340 - NRG session counts bounded by the track table"
---

# Tasks: An NRG image whose session counts do not fit its tracks is listed within its tracks and kept

**Input**: `specs/340-nrg-session-count/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)

**Tests**: requested by the spec (FR-006 pure rule with saltests checks; SC-001 probe rows).

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [ ] T001 Copy the measurement probe into `specs/340-nrg-session-count/probe/` (`iso340_probe.ps1`, `img340.py`, `result_before.txt`) and record the before run in `specs/340-nrg-session-count/fix-log.md`

## Phase 2: Foundational (the pure rule)

- [ ] T002 Add `SalIsoSessionTracks(int first, unsigned int declared, int trackCount, bool& fits)` (research R3/R4, data-model) with its comment to `src/common/salisotrack.h`, and name feature 340 in the header's top comment
- [ ] T003 Add `TestIsoSessionTracks_340` to `src/saltests/saltests.cpp` (fitting counts, zero, count above the tracks left, 1000, 0xFFFFFFFF, 0x80000000, start at / past the end, negative start, empty table, the probe's seven count lists walked as `ListTracks` walks them) and call it after `TestHfsFileContent339()`

## Phase 3: User Story 1 - damaged counts never read past the table (Priority: P1)

**Goal**: S-OVER, S-OVER1000, S-EXTRA, S-NEG, S-NEGEND pass (extracted within the tracks, image kept, no window).

**Independent Test**: `iso340_probe.ps1 -Only S-OVER,S-OVER1000,S-EXTRA,S-NEG,S-NEGEND` on the hidden desktop.

- [ ] T004 [US1] In `CISOImage::ListTracks` (`src/plugins/uniso/isoimage.cpp`) take each session's track count from `SalIsoSessionTracks(firstSessionTrack, (unsigned int)Session[session], Tracks.Count, fits)`; when `!fits` write a `TRACE_I` and call `ListingLeftOut.SetIncomplete()`; keep the rest of the loop and the 334 leftover loop unchanged
- [ ] T005 [US1] Build (`.\build.cmd`), run saltests, run the probe -> `specs/340-nrg-session-count/probe/result_after.txt`; record in `fix-log.md`

## Phase 4: User Story 2 - fitting counts unchanged (Priority: P2)

**Goal**: F-FIT, F-ZERO pass; 334's and 335's probes as before.

**Independent Test**: rows F-FIT, F-ZERO; `iso334_probe.ps1`, `iso335_probe.ps1`.

- [ ] T006 [US2] Run 334's and 335's probes on the fixed build -> `specs/340-nrg-session-count/probe/regress_334.txt`, `regress_335.txt` (334: 23 / 1 with S-RAW the known FAIL; 335: 32 / 0); record in `fix-log.md`

## Phase 5: Polish

- [ ] T007 [P] Negative control: build with the rule's bound removed (return `declared` unclamped) in a scratch copy of the header, run saltests -> checks fail; restore and hash-compare; record in `fix-log.md`
- [ ] T008 [P] `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; clang-format the changed lines only (`--lines`, 334's trap)
- [ ] T009 Inbox item (measure:340) for `CISOImage::DumpInfo` (`src/plugins/uniso/viewer.cpp`) reading `Session[session]` past the session table when the counts add up to fewer tracks than the image holds (research R5)

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006; T007, T008 after T004; T009 any time.

## Implementation Strategy

MVP = US1 (T002-T005); US2 is the regression check of the same change.
