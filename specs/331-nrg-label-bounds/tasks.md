# Tasks: An NRG image's CD-Text labels and track table never reach past a buffer

**Input**: Design documents from `specs/331-nrg-label-bounds/` (plan.md, spec.md, research.md, data-model.md, quickstart.md)

**Tests**: requested by the spec (FR-007, SC-001..SC-003: `saltests` checks).

## Phase 1: Setup

- [ ] T001 Start `specs/331-nrg-label-bounds/fix-log.md` with the measurement at d87666d5 (sites by reading, the build of HEAD)

## Phase 2: Foundational (the rule header)

- [ ] T002 Create `src/common/salnrgcdtext.h` (UTF-8 BOM, header-only): `SalNrgChunkFits`, `SalNrgCdTextLen`, `SalNrgCdTextGather` (in place allowed), `SalNrgCdTextNext`, `SalNrgDaoTrackInRange`, `SalNrgAudioTrackNameAlloc`
- [ ] T003 Add `TestNrgCdText331` to `src/saltests/saltests.cpp` (include the header, call it from `main`): chunk fit incl. sizes near 2^32 and 2^64; gathered length == `SalNrgCdTextLen` and <= size for sizes 0..200 and near 4 GiB (length only), content of blocks equals the reference, gather in place; label split with and without a final terminator, empty strings, exhaustion; DAOX range 0 / 1 / count / count + 1 / negative; names for labels 0..4096 bytes and numbers 1, 9, 10, 99, 100, 1000 hold the whole label

## Phase 3: User Story 1 - the track name (P1)

- [ ] T004 [US1] `src/plugins/uniso/audio.cpp` `CAudio::ListDirectory`: build the name with `SalNrgAudioTrackNameAlloc`, pass it to `AddFileDir`, free it; NULL -> `ListingLeftOut.SetIncomplete()` + `Error(IDS_INSUFFICIENT_MEMORY)`, return FALSE

## Phase 4: User Story 2 - the readers (P1)

- [ ] T005 [US2] `src/plugins/uniso/nrg.cpp` `readCDTX`: position + file size -> `SalNrgChunkFits`, else skip the chunk; `malloc(header->Size)` (size 0: no labels); full read required; gather in place; set the volume label and the tracks' labels from `SalNrgCdTextNext` through 0-terminated heap copies
- [ ] T006 [US2] `src/plugins/uniso/nrg.cpp` `readDAOX`: complete header / entry reads; apply an entry only when `SalNrgDaoTrackInRange`
- [ ] T007 [US2] `src/plugins/uniso/isoimage.cpp` `CISOImage::GetTrack`: `track < Tracks.Count`

## Phase 5: Polish

- [ ] T008 Build (`.\build.cmd`), `saltests` 0 failed, encoding guard `TOTAL: 0`
- [ ] T009 Feature 329's probe row A-OPEN on the hidden desktop (regression of the fitting-label path), result into `specs/331-nrg-label-bounds/probe/`
- [ ] T010 Negative control: a mutant of each rule (e.g. the gather bound without the flag bytes, the range `<=` count + 1) fails `saltests`; record in `fix-log.md`
- [ ] T011 Inbox items for research R5 (CUEX size underflow, SINF session counts) with source `measure:331`

## Dependencies

T002 -> T003, T004, T005, T006; T007 independent; T008 after T003..T007; T009, T010 after T008.

## Parallel opportunities

T004, T005/T006 and T007 touch different files once T002 exists.

## Implementation strategy

The header and its tests first (T002-T003), then the three sites, then the checks. MVP = US1 (the
overrun the item is named after); US2 completes *Expected*.
