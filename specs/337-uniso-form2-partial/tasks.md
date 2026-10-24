# Tasks: A file covering part of a Form 2 stream no longer lets Unpack delete the image

**Input**: `specs/337-uniso-form2-partial/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: saltests checks and a GUI probe (the project's rules require both for this area).

## Phase 1: Setup

- [X] T001 Start `specs/337-uniso-form2-partial/fix-log.md` with the measurement at 1c43d7d8 (probe rows, real-image dump, code trace)

## Phase 2: Foundational (pure rules)

- [X] T002 Add to `src/common/salisotrack.h`: `SalIsoFileStartTrack` (336's guards, start track or -1; `SalIsoNoteFileStart` calls it), `SalIsoStreamTrackSectors` (R4), `SalIsoFileSectorSpan` (R3), `SalIsoStreamSpan` + `SalIsoMergeStreamSpans`, `SalIsoStreamUncovered`, `SalIsoStreamNextGap`, `SalIsoForm2PayloadOffset`, `SalIsoPayloadEmpty`, `SAL_ISO_STREAM_GAP_SECTORS` = 300 and `SalIsoStreamGapsMark`
- [X] T003 Add `TestIsoStreamPartial_337` to `src/saltests/saltests.cpp` (spans of the probe images and the real VCD layout, merging, gaps, track sectors with wrong / unknown ends, payload offsets and emptiness, the decision) and call it beside `TestIsoStreamCovered_336`

## Phase 3: User Story 1 - a partly covered stream keeps the image (P1)

**Independent test**: probe rows S-VCDPART, S-VCDCOV, C-VCDCOV, M-FORM2COV, S-VCDTAIL kept.

- [X] T004 [US1] In `src/plugins/uniso/isoimage.h/.cpp`: `NoteListedFileStarts` also collects a `SalIsoStreamSpan` for every file whose start track is a stream track (sector counts computed once per stream track); `MarkUncoveredStreams` merges them and, per covered stream track, marks the listing when the uncovered sectors exceed the bound or a gap sector is not an empty, wholly readable Form 2 payload; out of memory marks
- [X] T005 [US1] `specs/337-uniso-form2-partial/probe/img337.py`: 336's kinds plus `single_vcdfull` (file over all 64 sectors), `ccd_vcdfull`, `single_vcdgap` (64-sector stream whose last 16 sectors are empty Form 2, file over 48), `single_vcdtail` (the same 16 sectors hold data), `multi_form2full`
- [X] T006 [US1] `specs/337-uniso-form2-partial/probe/iso337_probe.ps1` (from 336's): 336's partial rows want KEPT; new rows; `-FoldersOff` rows MF-FORM2COV kept, MF-FORM2FULL deleted

## Phase 4: User Story 2 - full coverage and real Video CDs still deleted (P1)

**Independent test**: S-VCDFULL, C-VCDFULL, S-VCDGAP deleted; `rev335c_probe.ps1` real rows deleted.

- [X] T007 [US2] Run the probe (after) and 335's `review3/rev335c_probe.ps1 -ImgDir %TEMP%\rev335c\imgs`; record in fix-log
- [X] T008 [US2] Negative controls: (a) saltests mutant - `SalIsoStreamGapsMark` ignores the gaps' content -> saltests fail; (b) the gap check disabled in `MarkUncoveredStreams`, built, probe -> the partial rows deleted (`probe/result_before_negative.txt`); then rebuild the fix

## Phase 5: Polish

- [X] T009 Encoding guard, `.\build.cmd`, saltests; clang-format on changed lines only
- [X] T010 Regression runs of `specs/336-uniso-form2-uncovered/probe/iso336_probe.ps1` rows that are unchanged by this feature (recorded verdict changes for its partial rows)
- [X] T011 fix-log *Checks*, CHANGELOG entry under the unreleased section, FEATURE-HISTORY entry (at closing)

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005/T006 [P] -> T007 -> T008 -> T009 -> T010 -> T011.
MVP: Phase 2 + US1.
