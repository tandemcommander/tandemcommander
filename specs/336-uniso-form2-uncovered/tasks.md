# Tasks: A Form 2 track that no listed file covers keeps the image

**Input**: `specs/336-uniso-form2-uncovered/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: `saltests` checks of the pure rules (FR-005) and the hidden-desktop probe are part of the item.

## Phase 1: Setup

- [X] T001 Start `specs/336-uniso-form2-uncovered/fix-log.md` with the measurement before (e2e41399: code unchanged since d9406b9b, 335's `result_after_review4.txt` rows; the GUI run refused while the installed program runs)

## Phase 2: Foundational (the pure rules)

- [X] T002 Add `SalIsoTrackOfExtent` (template over the track's extent-offset accessor; `GetTrackFromExtent`'s rule), `SalIsoNoteFileStart` (covered[track] for a file of more than zero bytes) and `SalIsoStreamTrackMarksListing(form2Stream, covered)` to `src/common/salisotrack.h`
- [X] T003 Add `TestIsoStreamCovered_336` to `src/saltests/saltests.cpp` (mapping incl. boundaries, zero / one / unsorted tracks; zero-size file; several stream tracks, some covered; the probe images' layouts) and register it after `TestIsoSectorForm2_335`

## Phase 3: User Story 1 - a Form 2 stream no file covers is not deleted (P1)

**Independent test**: probe rows S-VCD, M-FORM2, C-VCD, C-VCDREAL, S-VCDCOV2, S-VCDZERO keep the image.

- [X] T004 [US1] `Track::Form2Stream` in `src/plugins/uniso/isoimage.h`; initialised FALSE in `Track::Track()` and set to `!outside && form2` in `CISOImage::Open` in `src/plugins/uniso/isoimage.cpp`
- [X] T005 [US1] `GetTrackFromExtent` calls `SalIsoTrackOfExtent` in `src/plugins/uniso/isoimage.cpp`
- [X] T006 [US1] Rename the listing body to `ListTracks`; `ListImage` = `ListTracks` + `MarkUncoveredStreams(dir)` (walk the listed tree, note each file's start track, mark each uncovered Form 2 stream; no `dir` -> every stream marks) in `src/plugins/uniso/isoimage.h` / `isoimage.cpp`
- [X] T007 [US1] Build (`.\build.cmd`), `saltests` -> 0 failed; mutant (coverage ignored) fails the new checks - recorded in `fix-log.md`

## Phase 4: User Story 2 - a real Video CD still unpacks whole and is deleted (P1)

**Independent test**: R-VCD-CCD, R-SVCD-CCD, R-VCD-NRG, S-VCDCOV, C-VCDCOV, M-FORM2COV delete the image with every file.

- [X] T008 [P] [US2] Seed script `specs/336-uniso-form2-uncovered/probe/mkimg336.sh` (genisoimage in WSL: `s1c.iso` with `a.txt` "A1" and `avseq01.dat`)
- [X] T009 [P] [US2] Image writer `specs/336-uniso-form2-uncovered/probe/img336.py` (patches `avseq01.dat`'s directory records to start at the stream track; kinds single_vcdcov, single_vcdcov2, single_vcdzero, multi_form2cov as NRG, ccd_vcdcov as CloneCD)
- [X] T010 [US2] Probe `specs/336-uniso-form2-uncovered/probe/iso336_probe.ps1` (335's rows with S-VCD, M-FORM2, C-VCD, C-VCDREAL turned to kept; the new rows; content of binary files checked by size)
- [X] T011 [US2] Run the probe on the build before the fix (negative control) and after; run `rev335c_probe.ps1` on the real vcdimager images after - results in `probe/`

## Phase 5: Polish

- [X] T012 Regression probes 322 / 329 / 330 / 333 / 334 on the fixed build -> `probe/regress_*.txt`
- [X] T013 `python tools/check_encoding.py --strict` -> TOTAL: 0; clang-format on the changed lines only
- [X] T014 `fix-log.md` complete (measurements, checks, deviations, what is owed to a person)

## Dependencies

T001 -> T002 -> T003 -> T004..T006 -> T007 -> T010 -> T011 -> T012..T014; T008 / T009 in parallel with T004..T007.

## Implementation strategy

MVP = Phase 2 + Phase 3 (the mark). Phase 4 proves the cost stays limited to uncovered streams.
