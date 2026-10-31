# Tasks: A cooked disc image is kept when it holds more than its listing shows

**Input**: Design documents from `specs/354-uniso-cooked-sessions/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: requested by the project's working method (a pure rule with `saltests` checks; a GUI probe).

## Phase 1: Setup

- [ ] T001 Start `specs/354-uniso-cooked-sessions/fix-log.md` with the measurement before (probe 20 / 8 in `specs/354-uniso-cooked-sessions/probe/result_before_debug.txt`, the tail measurement of `probe/measure_tails.sh` / `probe/measure2.sh`)

## Phase 2: Foundational (the pure rule)

- [ ] T002 Add `SAL_ISO_ZERO_REST_SECTORS` (512), the result constants `SAL_ISO_REST_KEEP_LISTING` / `SAL_ISO_REST_MARK` / `SAL_ISO_REST_CHECK`, `SalIsoCookedRestDecision(iso9660, volumeKnown, volumeSectors, fileSize, checkFrom, checkBytes)` and `SalIsoBytesAllZero(data, len)` to `src/common/salisotrack.h` (data-model.md)
- [ ] T003 Add `TestIsoCookedRest_354` to `src/saltests/saltests.cpp` (not ISO 9660 / rest 0, 16, 17 sectors / partial sector / 512 and 513 sectors / volume unknown / file shorter than the volume / negative size / huge volume size without overflow / checkFrom and checkBytes values / all-zero helper) and call it next to `TestIsoNoCcdRest_353`; run a mutant (always KEEP_LISTING) to see the group fail

## Phase 3: User Story 1 - a cooked multi-session image is not deleted (P1)

**Goal**: rows R-TWOISO, R-TWOIMG, R-REST17, R-XESP keep the image.
**Independent Test**: `iso354_probe.ps1 -Only R-TWOISO,R-TWOIMG,R-REST17,R-XESP`.

- [ ] T004 [US1] In `CISOImage::Open`'s plain branch (`src/plugins/uniso/isoimage.cpp`) remember `cookedIso` when `CheckForISO` succeeds with `rawStart` false (2048-byte layout at offset 0)
- [ ] T005 [US1] After `DetectTrackFS` in the same branch: for `cookedIso`, read the descriptor at sector 16 (`IsValidCDHeader` -> `iso9660`, `SalIsoPvdVolumeSectors`), call `SalIsoCookedRestDecision` with `track->End`; MARK -> `ListingLeftOut.SetIncomplete()`; CHECK -> read `checkBytes` from `checkFrom` in 64 KiB pieces (heap buffer; an allocation failure or a short read marks), mark unless all zero; TRACE_I the decision

## Phase 4: User Story 2 - a plain one-volume image still unpacks and is deleted (P2)

**Independent Test**: rows C-PLAIN, C-REST16, C-ZERO168, C-ZERO512, C-XDEV1, C-XMS.

- [ ] T006 [US2] Confirm by the probe that the zero-rest and at-most-16 cases are not marked (no code beyond T002 / T005; a failure here is fixed in those)

## Phase 5: User Story 3 - a rest that cannot be checked keeps the image (P3)

**Independent Test**: rows R-ZERO513, R-ZEROLATE, R-SHORT, R-BIGPVD.

- [ ] T007 [US3] Confirm by the probe that the over-cap, late non-zero byte, short-file and too-big-size cases are marked

## Phase 6: Polish & verification

- [ ] T008 Encoding guard `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; `.\build.cmd` -> `BUILD SUCCEEDED`; `saltests` -> 0 failed
- [ ] T009 Run `iso354_probe.ps1` (after: 28 / 0) and a mutant plug-in (the rule never marking) on the hidden desktop; save results in `specs/354-uniso-cooked-sessions/probe/`
- [ ] T010 Regression probes: `specs/353-uniso-noccd-sessions/probe/iso353_probe.ps1`, `specs/352-uniso-ccd-session-bounds/probe/iso352_probe.ps1`, `specs/334-uniso-session-missing/probe/iso334_probe.ps1`; results in `specs/354-uniso-cooked-sessions/probe/regress_*.txt`
- [ ] T011 Update `specs/354-uniso-cooked-sessions/fix-log.md` (after, mutants, regressions) and add the Inbox item for UDF-only cooked images (limit)

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006, T007 -> T008 -> T009 -> T010 -> T011. US2 and US3 depend on
US1's code (one rule serves all three stories).

## Parallel execution

T006 and T007 are probe rows of the same run. T010's regression probes run one after another (one
program instance at a time on the hidden desktop).

## Implementation strategy

MVP = US1 (the data-loss case). US2 and US3 are the same rule's other outcomes, checked by the same
probe run.
