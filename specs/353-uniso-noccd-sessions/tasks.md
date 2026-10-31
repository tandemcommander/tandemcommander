# Tasks: A CloneCD image without its .ccd is kept when it holds more than its listing shows

**Input**: `specs/353-uniso-noccd-sessions/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: requested by the spec (FR-007, SC-001..SC-004): `saltests` group + hidden-desktop probe.

## Phase 1: Setup

- [X] T001 Record the before measurement (probe 10 / 2, R-NOCCD2 and R-REST17 deleted) in specs/353-uniso-noccd-sessions/fix-log.md and keep specs/353-uniso-noccd-sessions/probe/result_before_debug.txt

## Phase 2: Foundational (the pure rule)

- [X] T002 Add `SAL_ISO_LATER_VOLUME_SECTOR` (16), `SalIsoPvdVolumeSectors` and `SalIsoNoCcdRestMarks` with a feature-353 header note in src/common/salisotrack.h
- [X] T003 Add `TestIsoNoCcdRest_353` (valid / invalid descriptors, both-endian mismatch, block size, short buffer; not raw; unknown volume; rest 0 / 2 / 16 / 17 / two sessions; partial sector; file shorter than the volume; data offset; sector size 0) and call it after `TestIsoCcdBounds_352` in src/saltests/saltests.cpp
- [X] T004 Build and run saltests; run a mutant of the rule (no mark past the volume) and record that checks fail, in specs/353-uniso-noccd-sessions/fix-log.md

## Phase 3: User Story 1 - a multi-session image without its .ccd is kept (P1)

**Independent test**: probe rows R-NOCCD2, R-REST17 - a.txt extracted, the image kept.

- [X] T005 [US1] Add `BOOL CcdMissing` (documented) to `CISOImage` in src/plugins/uniso/isoimage.h and initialise it in the constructor in src/plugins/uniso/isoimage.cpp
- [X] T006 [US1] In src/plugins/uniso/img.cpp: `CCD::Missing` set by `processCCDFile` when the `.ccd` cannot be opened; `ReadSessionCCD` copies it to `CcdMissing`
- [X] T007 [US1] In src/plugins/uniso/isoimage.cpp: `ReadSessionInfo` resets `CcdMissing`; `Open`'s plain branch records `raw` right after `DetectSectorType` and, when `CcdMissing` and the image opened, reads the descriptor at `GetSectorOffset(16)` and marks `ListingLeftOut` by `SalIsoNoCcdRestMarks`
- [X] T008 [US1] Build Debug, run specs/353-uniso-noccd-sessions/probe/iso353_probe.ps1 on the hidden desktop -> result_after_debug.txt (R-NOCCD2, R-REST17 PASS)

## Phase 4: User Story 2 - one-session and plain images unchanged (P2)

**Independent test**: probe rows C-NOCCD, C-REST2, C-REST16, C-COOKED - deleted.

- [X] T009 [US2] Check the same probe run's control rows (12 / 0) and run the regressions specs/352-uniso-ccd-session-bounds/probe/iso352_probe.ps1 (22 / 0) and specs/351-uniso-track-defaults/probe/iso351_probe.ps1 (10 / 0), results into specs/353-uniso-noccd-sessions/probe/
- [X] T010 [US2] Negative control: the plug-in without the Open change (mutant) on the probe -> R-NOCCD2 / R-REST17 FAIL, recorded in specs/353-uniso-noccd-sessions/fix-log.md

## Phase 5: Polish

- [X] T011 `python tools/check_encoding.py --strict` -> TOTAL: 0; `git diff main...HEAD --stat` shows no `.rc` / `.rc2` / `.rh` change (FR-005); clang-format only the changed lines of src/common/salisotrack.h, src/saltests/saltests.cpp, src/plugins/uniso/*.cpp
- [X] T012 Update fix-log.md (after measurements, checks) in specs/353-uniso-noccd-sessions/fix-log.md

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005..T007 -> T008 -> T009, T010 -> T011 -> T012. US2 checks run on
the US1 build. No parallel tasks: every task depends on the previous build.

## Implementation strategy

MVP = Phase 2 + US1 (the data-loss case); US2 proves the unchanged cases.
