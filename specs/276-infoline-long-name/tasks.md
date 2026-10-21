# Tasks: The information line shows items with very long names

**Input**: Design documents from `specs/276-infoline-long-name/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: requested by the spec (FR-005 `saltests` checks; SC-001 the probe).

## Phase 1: Setup

- [ ] T001 Start `specs/276-infoline-long-name/fix-log.md` with the before measurement (probe `probe/result_before.txt`: 13 PASS / 4 FAIL, ARCCAP and ARCDEEP one box each, line unchanged; the cause by reading)

## Phase 2: Foundational (the pure rule)

- [ ] T002 Create `src/common/salinfolinebuf.h` (UTF-8 BOM, SPDX header like `salcachename.h`): `SAL_INFOLINE_FIRST_LEN` 1000, `SAL_INFOLINE_MAX_LEN` 65535, `inline int SalInfoLineNextLen(int len)` (below the first -> the first; at or above the bound -> 0; else min(2 * len, bound))
- [ ] T003 Add `TestInfoLineBuf276` to `src/saltests/saltests.cpp` (include + call in main): the sequence from 1000 is 2000, 4000, ..., 64000, 65535, 0 (8 attempts); strictly increasing, never above the bound; the bound holds the largest names-only expansion (18 x 765 + 199 + 1) and the default content with two 765-byte names; 1000 does not hold the default content with two 604-byte names (the defect's case); hot-text positions fit a WORD at the bound
- [ ] T004 Negative control: temporarily set the bound to 1000 in the header, run `saltests` and record that `TestInfoLineBuf276` fails; restore (record in fix-log.md)

## Phase 3: User Story 1 - long-named archive members (P1) 🎯 MVP

**Goal**: focusing a 604 / 757-byte archive member shows no box and the information line changes.
**Independent Test**: probe rows ARCCAP, ARCMAX, ARCDEEP, ARCSHORT.

- [ ] T005 [US1] In `CFilesWindow::ItemFocused` (`src/fileswn2.cpp`): keep the plug-in route into `buff[1000]`; expand first into `buff` with `msgParent = NULL`, then while it fails grow a heap buffer by `SalInfoLineNextLen`, the last attempt (next length 0) with `HWindow`; `varPlacementsCount` reset to 100 before each attempt; low memory -> TRACE_E, stop; `SetText` / `SetSubTexts` from the buffer that succeeded; free the heap buffer
- [ ] T006 [US1] Build (`.\build.cmd`), run `saltests` -> 0 failed
- [ ] T007 [US1] Run the probe (after) on the hidden desktop -> `probe/result_after.txt`, every row PASS

## Phase 4: User Story 2 - disk names without 8.3 names (P2)

**Goal**: the same change covers disk names; DISK row stays box-free.
**Independent Test**: probe row DISK; by reading for volumes without 8.3 names.

- [ ] T008 [US2] Record in fix-log.md that the DISK row (754-byte name, with an 8.3 name on the probe volume) passes before and after, and that volumes without 8.3 names reach the same code (not driven - needs an administrator to make such a volume)

## Phase 5: Polish & Cross-Cutting

- [ ] T009 Regression: 260's `specs/260-archive-cache-long-names/probe/cache260_probe.ps1` and 275's `specs/275-arcmember-long-path/probe/arcmember275_probe.ps1` on the new build -> `probe/regress_260.txt`, `probe/regress_275.txt`
- [ ] T010 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [ ] T011 Update fix-log.md with after / regression numbers

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009 -> T010 -> T011. T009 and
T010 could run in parallel (different tools) but share the build.

## Implementation Strategy

MVP = Phase 1-3 (the defect). US2 needs no code of its own.
