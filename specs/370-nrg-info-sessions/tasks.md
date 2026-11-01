# Tasks: The image information of an NRG image stays within its session table

**Input**: Design documents from `specs/370-nrg-info-sessions/` (plan.md, spec.md, research.md, data-model.md, quickstart.md)
**Tests**: saltests rows and the GUI probe are part of the project's working method (CLAUDE.md *Measure first*).

## Phase 1: Setup

- [ ] T001 Start `specs/370-nrg-info-sessions/fix-log.md` with the measurement at 2c1c1279 (probe `probe/result_before.txt`, PASS 6 / FAIL 10) and the readers of `Session` enumerated (research R1)

## Phase 2: Foundational

- [ ] T002 Add `IDS_INFO_NO_SESSION 1157` to `src/plugins/uniso/uniso.rh2` and its English text `"\nTracks not in any session\n"` to `src/plugins/uniso/lang/lang.rc2` after `IDS_INFO_TRACK_TYPE_SIZE_LABEL`

## Phase 3: User Story 1 - tracks no session covers (P1) MVP

**Goal**: the dump never reads past the session table; uncovered tracks under the new line.
**Independent test**: probe rows S-SHORT, S-NONE, S-EXTRA3 PASS.

- [ ] T003 [US1] Rewrite `CISOImage::DumpInfo` in `src/plugins/uniso/viewer.cpp` to walk the sessions: for each `s < Session.Count` print `IDS_INFO_SESSION_NUM`, `n = SalIsoSessionTracks(first, (unsigned int)Session[s], Tracks.Count, fits)` with `IDS_INFO_CNT_TRACKS`, then tracks `first .. first + n - 1`; `first += n`; then, when `first < Tracks.Count`, print `IDS_INFO_NO_SESSION` and the remaining tracks (one helper prints a track as before); include `salisotrack.h` if not already reachable
- [ ] T004 [P] [US1] Add `TestIsoSessionDump_370` to `src/saltests/saltests.cpp` (walk via `Iso340Walk`: counts {} / {1} / {1,1} over 2 or 3 tracks leave the expected tracks without a session; never an index outside the tables) and call it from the test list; add a feature 370 line to the header comment of `src/common/salisotrack.h`

## Phase 4: User Story 2 - counts read unsigned (P2)

**Goal**: counts of 0, above the tracks left and >= 2^31 give each session the tracks of feature 340's rule.
**Independent test**: probe rows S-NEG, S-NEGEND, S-OVER, F-ZERO PASS.

- [ ] T005 [US2] Covered by T003's walk; add saltests rows for counts {0xFFFFFFFF, 2}, {1, 0xFFFFFFFF}, {1, 2}, {0, 2} to `TestIsoSessionDump_370` in `src/saltests/saltests.cpp` with the session sizes the dump prints

## Phase 5: User Story 3 - fitting counts unchanged (P1)

**Independent test**: probe row F-FIT PASS; feature 340's probe 14 / 14 PASS.

- [ ] T006 [US3] Run the probe after the fix (`probe/result_after.txt`, 16 / 16 PASS) and feature 340's probe as a regression (`probe/regress_340.txt`)

## Phase 6: Polish & cross-cutting

- [ ] T007 Two-stage `.slt` refresh of module `uniso` (stop-rules 2.13): export, dry run, merge with `--formality prefer_more`, read back, pins, `slt --verify`; record in `fix-log.md` *Translations*
- [ ] T008 Checks: `python tools/check_encoding.py --strict` (TOTAL: 0), `.\build.cmd full` (BUILD SUCCEEDED), `saltests` (0 failed); record in `specs/370-nrg-info-sessions/fix-log.md`
- [ ] T009 Negative control: the probe on a build without the T003 change fails S-SHORT / S-NONE / S-EXTRA3 (the before run, `probe/result_before.txt`); saltests rows fail against the old walk logic (recorded in `fix-log.md`)

## Dependencies

T001 -> T002 -> T003 -> (T004, T005) -> T006 -> T007 -> T008; T009 uses the before result.
US1, US2 share T003 (one function); US3 is a check of the same change.

## Parallel opportunities

T004 / T005 (saltests) in parallel with T006's probe run once T003 builds.

## Implementation strategy

MVP = T002 + T003 (US1); US2 is the same walk; finish with translations and checks.
