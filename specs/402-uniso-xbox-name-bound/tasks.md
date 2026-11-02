# Tasks: ISO plug-in - an Xbox entry name is never read past the end of its directory

**Input**: `specs/402-uniso-xbox-name-bound/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: requested by the item (a probe row and saltests checks).

## Phase 1: Setup

- [ ] T001 Copy the probe written before the branch (img402.py, iso402_probe.ps1, result_before.txt) into specs/402-uniso-xbox-name-bound/probe/ and record the before measurement in specs/402-uniso-xbox-name-bound/fix-log.md

## Phase 2: Foundational

- [ ] T002 Create the header-only rule `SalIsoXboxEntryHeadFits` / `SalIsoXboxEntryFits` (64-bit, no wrap, next offset aligned to 4) in src/common/salisoxboxentry.h per data-model.md

## Phase 3: User Story 1 - a damaged Xbox image is reported, not listed with invented names (P1)

**Independent test**: probe rows XD-NAME, XD-OVER1, XD-MAX, XD-SUB; saltests `TestIsoXboxEntry402`.

- [ ] T003 [P] [US1] Add `TestIsoXboxEntry402` (boundaries: fits exactly, one byte over, len 255, len 0, offset past size, sizes near 2^32; a model walk of crafted directories that lists names through the rules and reads only inside the bytes) and call it from main in src/saltests/saltests.cpp
- [ ] T004 [US1] In `CXDVDFS::ScanDir` of src/plugins/uniso/xdvdfs.cpp include salisoxboxentry.h; loop and padding head checks by `SalIsoXboxEntryHeadFits`; before reading the name `SalIsoXboxEntryFits` - on false the walk's one box (`IDS_ERROR_LISTING_IMAGE`, `SalIsoWalkBoxQuiet(Walk, false)`, the directory's sector), `ret = SalIsoWalkAfterChild(ret, ERR_TERMINATE)`, `break`; the next offset from the rule (end the loop if it is past `size`)
- [ ] T005 [US1] Build (`.\build.cmd`), run saltests (0 failed), a negative control of the rule (the name bound removed) failing saltests, then the probe after (XD-NAME, XD-OVER1, XD-MAX, XD-SUB PASS) - results in specs/402-uniso-xbox-name-bound/probe/result_after.txt and fix-log.md

## Phase 4: User Story 2 - a valid Xbox image is unchanged (P1)

**Independent test**: XD-EDGE; feature 400's and 401's probes.

- [ ] T006 [US2] Probe row XD-EDGE PASS (in the T005 run); regressions: specs/400-uniso-walk-after-unreadable/probe/iso400_probe.ps1 (48 / 0) and specs/401-uniso-share-length/probe/iso401_probe.ps1 (10 / 0) into specs/402-uniso-xbox-name-bound/probe/regress_400.txt / regress_401.txt

## Phase 5: Polish

- [ ] T007 Encoding guard `python tools/check_encoding.py --strict` (TOTAL: 0), fix-log.md complete (before / after, decisions, commands)

## Dependencies

T001 -> T002 -> (T003 [P], T004) -> T005 -> T006 -> T007. US2 needs the US1 change built.

## Parallel example

T003 (saltests.cpp) and T004 (xdvdfs.cpp) touch different files once T002 exists.

## Implementation strategy

MVP = US1 (the bound); US2 proves nothing valid changed. One build covers both.
