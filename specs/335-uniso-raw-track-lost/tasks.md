# Tasks: A disc image with a data track whose file system is lost is kept by Unpack with "Delete archive after unpacking"

**Input**: Design documents from `specs/335-uniso-raw-track-lost/` (plan.md, spec.md, research.md,
data-model.md, quickstart.md)
**Tests**: required by the project rules (saltests for the pure rule, a hidden-desktop probe).

## Phase 1: Setup

- [ ] T001 Record the before measurement (probe `iso335_probe`, PASS 10 / FAIL 4 at e363177e) in specs/335-uniso-raw-track-lost/fix-log.md and keep specs/335-uniso-raw-track-lost/probe/result_before.txt

## Phase 2: Foundational (the pure rule - blocks every story)

- [ ] T002 Add `SalIsoSectorIsForm2(raw, len, sectorRawSize)` to src/common/salisotrack.h (2352+: sync, mode byte 2, submode bit 0x20 at 18 and 22; 2336: bit 0x20 at 2 and 6; anything else false) and rename `SalIsoTrackMarksListing`'s second parameter to `rawLost` with its comment updated
- [ ] T003 Add `TestIsoSectorForm2_335` to src/saltests/saltests.cpp (Form 2 raw / 2336, Form 1, Mode 1, destroyed sync, one copy only, short reads, NULL, 2048-byte and other sizes, sizes above 2352) and call it from the test list
- [ ] T004 Build (`.\build.cmd`) and run saltests - 0 failed; a mutant that returns true always / false always fails the new checks (record in fix-log.md)

## Phase 3: User Story 1 - A damaged data session is not deleted with the image (P1)

**Independent test**: probe rows M-NOFS, M-NOFS-F1 keep the image; M-OK-2336 deletes it.

- [ ] T005 [US1] Rename `Track::OutsideImage` to `Track::RawLost` in src/plugins/uniso/isoimage.h (comment: outside the image or sector 16 not Form 2) and in `Track::Track()` / `MarkTrack` in src/plugins/uniso/isoimage.cpp
- [ ] T006 [US1] In `CISOImage::Open` (src/plugins/uniso/isoimage.cpp), for an fsData track inside the image, read the first bytes of the stored sector 16 (`GetSectorOffset(0x10) - SectorHeaderSize`; 24 bytes for 2352+, 8 for 2336, none otherwise) with `ReadDataByPos` and set `RawLost = outside || !SalIsoSectorIsForm2(...)`; update the `ListImage` comments that name `OutsideImage` / "readable raw data track"

## Phase 4: User Story 2 - Video CDs unpack as before (P1)

**Independent test**: probe rows S-VCD, M-FORM2 delete the image.

- [ ] T007 [US2] Verify by the probe that a Mode 2 / 2336 Form 2 track is not marked (S-VCD, M-FORM2) - specs/335-uniso-raw-track-lost/probe/iso335_probe.ps1

## Phase 5: User Story 3 - A damaged track of a one-session image is not lost (P2)

**Independent test**: probe rows S-NOFS, S-RAW keep the image.

- [ ] T008 [US3] Verify by the probe that the single listing marks the track (S-NOFS, S-RAW) - specs/335-uniso-raw-track-lost/probe/iso335_probe.ps1

## Phase 6: Polish & cross-cutting

- [ ] T009 Run the probe after the fix on the hidden desktop -> specs/335-uniso-raw-track-lost/probe/result_after.txt (14 / 0) and a mutant build (Form 2 always true) -> the four rows FAIL, recorded in fix-log.md
- [ ] T010 Run the regression probes of features 322, 329, 330, 333, 334 -> specs/335-uniso-raw-track-lost/probe/regress_*.txt (334's S-RAW changes by design)
- [ ] T011 Encoding guard `python tools/check_encoding.py --strict` -> TOTAL: 0; clang-format of the changed lines only
- [ ] T012 Update specs/335-uniso-raw-track-lost/fix-log.md (after, checks, deviations)

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 / T008 (probe run T009) -> T010 -> T011 -> T012.
US2 and US3 are verified by the same probe run as US1; no parallel work (one source file each step).

## Implementation strategy

MVP = Phase 2 + US1 (the rule and the mark); US2 / US3 are checks of the same change.
