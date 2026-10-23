# Tasks: UDF, Xbox, HFS+ and audio entries the panel listing refuses are left out and reported

**Input**: Design documents from `specs/329-uniso-other-readers-refused/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

Tests: the feature's checks are the saltests rules for the new header class and the hidden-desktop
probe `probe/iso329_probe.ps1` (written and run before the fix: 0 / 7).

## Phase 1: Setup

- [X] T001 Write the probe and its seed builders in specs/329-uniso-other-readers-refused/probe/ (iso329_probe.ps1, mkimg329.sh, img329.py) and record the run before the fix in specs/329-uniso-other-readers-refused/probe/result_before.txt and fix-log.md

## Phase 2: Foundational

- [X] T002 Add `CSalLeftOutIds` (Add / Has of 32-bit catalog IDs, Add returns false on out of memory) to src/common/salisonamefit.h and update its header comment (feature 329)
- [X] T003 Add saltests checks for `CSalLeftOutIds` (empty set, added IDs found, others not, many IDs, duplicates) in src/saltests/saltests.cpp

## Phase 3: User Story 1 + 2 - UDF / Xbox / HFS+ entries left out and reported; the unpack keeps the image (P1)

**Goal**: a refused entry is left out alone and recorded on the image; the walk goes on; the report and the failing whole unpack follow from 328's record.
**Independent Test**: probe rows U-COPY, X-COPY, H-COPY, U-UNP-DEL, X-UNP-DEL, H-UNP-DEL.

- [X] T004 [P] [US1] `CUDF::AddFileDir` returns ADD_FAILED / ADD_LISTED / ADD_LEFT_OUT (rule first via `SalListingAcceptsDirU8` / `SalListingAcceptsFileU8`, `Image->ListingLeftOut.Add`; out of memory and a core refusal after the rule mark the listing incomplete; no leaked name) and `ScanDir` skips a left-out entry, descending only listed folders, in src/plugins/uniso/udf.h and src/plugins/uniso/udf.cpp
- [X] T005 [P] [US1] The same for `CXDVDFS::AddFileDir` / `ScanDir` in src/plugins/uniso/xdvdfs.h and src/plugins/uniso/xdvdfs.cpp
- [X] T006 [P] [US1] `CHFS::ListDirectory`: record a refused folder / file and continue; skip records whose parent is a left-out folder (`CSalLeftOutIds`), adding skipped folders' IDs; out of memory marks the listing incomplete, in src/plugins/uniso/hfs.cpp

## Phase 4: User Story 3 - audio track (P3)

**Goal**: a refused track name is left out and recorded; the other tracks stay.
**Independent Test**: probe row A-OPEN.

- [X] T007 [US3] `CAudio::AddFileDir`: record a refused name and return TRUE; never `Clear`; out of memory / a core refusal marks the listing incomplete, in src/plugins/uniso/audio.cpp

## Phase 5: Polish & verification

- [X] T008 Build (`build.cmd`), `saltests`, encoding guard (`python tools/check_encoding.py --strict`); record in specs/329-uniso-other-readers-refused/fix-log.md
- [X] T009 Run the probe after the fix -> specs/329-uniso-other-readers-refused/probe/result_after.txt (7 / 7 PASS); a negative control (the probe on the build before the fix is result_before.txt: 0 / 7)
- [X] T010 Regression probes 328 / 327 / 322 on the fixed build -> specs/329-uniso-other-readers-refused/probe/regress_328.txt, regress_327.txt, regress_322.txt
- [X] T011 Inbox item for the audio track name overrun (`sprintf` into `char[MAX_PATH]` with an NRG CD-Text label of 257+ bytes, src/plugins/uniso/audio.cpp `CAudio::ListDirectory`) - `measure:329`

## Dependencies

- T002 -> T003, T006. T004, T005, T006, T007 independent of each other (different files). T008 after T002-T007; T009, T010 after T008.

## Parallel example

- T004, T005, T007 can be written side by side; T006 after T002.

## Implementation strategy

MVP = Phase 3 (the P1 stories: data loss on unpack + lost folders); then the audio reader; then the
verification phase.
