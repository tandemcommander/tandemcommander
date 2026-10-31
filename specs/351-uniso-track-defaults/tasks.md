# Tasks: Every track of a disc image starts with defined values

**Input**: Design documents from `specs/351-uniso-track-defaults/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

Tests: requested by the spec (FR-005 `saltests`; SC-001..SC-004 probe rows).

## Phase 1: Setup

- [X] T001 Start `specs/351-uniso-track-defaults/fix-log.md` with the measurement of step 3 (Release 0.2.0 23 / 7, Debug 10 / 0; `probe/result_before_release.txt`, `probe/result_before_debug.txt`)

## Phase 2: Foundational

- [X] T002 Add `SalIsoCcdTrackKind(int ccdMode)` (0 -> `SAL_ISO_TRACK_AUDIO`, 1 / 2 -> `SAL_ISO_TRACK_DATA`, else `SAL_ISO_TRACK_UNKNOWN`) to `src/common/salisotrack.h`
- [X] T003 Add `TestIsoCcdTrackKind_351` (modes 0, 1, 2, 3, -1, 255, INT_MIN, INT_MAX) to `src/saltests/saltests.cpp` and call it from the test list; run a mutant of the rule (every mode data) once and record that the checks fail

## Phase 3: User Story 1 - A CloneCD data image opens every time (P1)

**Independent test**: probe rows C-M1, C-M2, C-M1M1 on Debug and on a Release build of the fixed plug-in (3 repeats).

- [X] T004 [US1] Set every field in `CISOImage::Track::Track()` in `src/plugins/uniso/isoimage.cpp` (`SectorSize`, `SectorHeaderSize`, `Start`, `End`, `ExtentOffset` 0, `Mode = mNone`, `FSType = fsUnknown`)
- [X] T005 [US1] Map the CCD track mode through `SalIsoCcdTrackKind` in `CISOImage::ReadSessionCCD` in `src/plugins/uniso/img.cpp` (data -> `mMode1` / `mMode2` + `fsISO9660`; audio -> `mNone` + `fsAudio`; unknown -> constructor defaults)
- [X] T006 [US1] Build Debug (`.\build.cmd`), run `saltests`, run `probe/iso351_probe.ps1` on Debug -> `probe/result_after_debug.txt`
- [X] T007 [US1] Build `src/plugins/uniso/vcxproj/uniso.vcxproj` Release x64 with `OPENSAL_BUILD_DIR=%TEMP%\tc351-rel\`, copy the 0.2.0 Release tree to `%TEMP%\tc351-reltree` with the new `uniso.spl`, run the probe there with `-Repeat 3` -> `probe/result_after_release.txt`
- [X] T008 [US1] Debug mutant (T005's data mapping removed): probe C-* rows must FAIL -> `probe/result_mutant_no_ccd_data.txt`; restore `src/plugins/uniso/img.cpp`, rebuild

## Phase 4: User Story 2 - An undescribed Nero track is unknown (P2)

**Independent test**: row N-UNDESC passes on Debug and Release (covered by T006 / T007).

- [X] T009 [US2] Confirm by reading `src/plugins/uniso/nrg.cpp` (`readCUEX`, `readDAOX`) and `CISOImage::Open` / `ListTracks` in `src/plugins/uniso/isoimage.cpp` that an undescribed CUEX track keeps `fsUnknown` / zero bounds and marks the listing; record in `fix-log.md`

## Phase 5: User Story 3 - Images that opened before open as before (P1)

- [X] T010 [P] [US3] Regression probes on Debug: `specs/334-uniso-session-missing/probe/iso334_probe.ps1`, `specs/335-uniso-raw-track-lost/probe/iso335_probe.ps1`, `specs/350-nrg-cuex-bounds/probe/nrg350_probe.ps1` -> `probe/regress_334.txt`, `regress_335.txt`, `regress_350.txt`; compare with their recorded results (334 23 / 1 - S-RAW, 335's intended change; 335 28 / 4 - its Form 2 rows changed by 336; 350 20 / 0)

## Phase 6: Polish

- [X] T011 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; clang-format only the changed lines
- [X] T012 Complete `specs/351-uniso-track-defaults/fix-log.md` (before / after, mutant, regressions)

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 / T008 (sequential: same build tree) -> T009 -> T010 -> T011 -> T012.
Parallel: T010's three probes may not run at once (one program instance) - [P] only against reading tasks.

## Implementation strategy

MVP = US1 (T002-T007): the shipped defect. US2 needs no code beyond T004. US3 is regression evidence.
