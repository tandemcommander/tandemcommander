# Tasks: A long single mask never overruns the mask group preparation

**Input**: Design documents from `specs/298-mask-group-long-mask/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/mask-group-split.md, quickstart.md

**Tests**: requested by the spec (FR-005, SC-001, SC-002): saltests and the hidden-desktop probe.

## Phase 1: Setup

- [ ] T001 Record the before measurement (probe rows, crash report) in specs/298-mask-group-long-mask/fix-log.md (done at the start; keep it current)

## Phase 2: Foundational (blocking)

- [ ] T002 Create the header-only rule src/common/salmaskgroup.h per contracts/mask-group-split.md: `SalMaskGroupCutMask`, `SalMaskGroupTrimMask`, `SalPrepareMaskU8` (UTF-8-BOM, SPDX header, bytes compared as unsigned char)

## Phase 3: User Story 1 - a long mask from the configuration does not crash the program (P1)

**Goal**: `CMaskGroup::PrepareMasks` never writes past its work storage.
**Independent Test**: probe rows M300 / M1000 PASS (start, responsive, exit 0, no bug report).

- [ ] T003 [US1] In src/masks.cpp `CMaskGroup::PrepareMasks`: replace `char buf[MAX_PATH]; char maskBuf[MAX_PATH];` by one heap block of 2 x (`strlen(group)` + 1) bytes, allocated after the old prepared masks are released; on allocation failure `TRACE_E(LOW_MEMORY)`, `errorPos = 0`, return FALSE; free it on every return path
- [ ] T004 [US1] In src/masks.cpp `CMaskGroup::PrepareMasks`: use `SalMaskGroupCutMask`, `SalMaskGroupTrimMask` and `SalPrepareMaskU8` for the cut / trim / normalize steps (results unchanged)
- [ ] T005 [US1] In src/masks.cpp `::PrepareMask`: call `SalPrepareMaskU8` (signature and contract unchanged - plug-in export `CSalamanderGeneral::PrepareMask` in src/zip.cpp keeps forwarding to it)
- [ ] T006 [US1] Build (`.\build.cmd`), run the probe specs/298-mask-group-long-mask/probe/mask298_probe.ps1 with label `after` on the hidden desktop; record in fix-log.md

## Phase 4: User Story 2 - a long mask is used whole, never cut (P1)

**Goal**: masks of any length are prepared whole and equal to the old algorithm's unbounded result.
**Independent Test**: saltests `TestMaskGroupSplit298` 0 failed.

- [ ] T007 [US2] Add `TestMaskGroupSplit298` to src/saltests/saltests.cpp (include `salmaskgroup.h`): a reference copy of the old cut / trim / PrepareMask code with unbounded buffers; table of short groups (`;;`, `|`, spaces, `**`, `*?`, control bytes, `\ / < > : "`, UTF-8 letters) compared function by function; 259 / 260 / 261 / 300 / 1000 / 3000-byte single masks (also of 3-byte UTF-8 letters, also a long mask after `|` and one holding `;;`) whole, with guard bytes after the `strlen + 1` storage intact; the old 260-byte storage shown too small for a 300-byte mask (reproduction); call it from `main`
- [ ] T008 [US2] Run saltests (`build\tandemcommander\Debug_x64\saltests\saltests.exe`), record the count in fix-log.md; negative control: break the rule temporarily (e.g. cut at 259) and see the block fail, then restore

## Phase 5: Polish

- [ ] T009 Encoding guard `python tools/check_encoding.py --strict` -> TOTAL: 0; clang-format style kept in the touched files
- [ ] T010 Update specs/298-mask-group-long-mask/fix-log.md with the after measurements and the checks

## Dependencies

T002 -> T003, T004, T005, T007; T003-T005 -> T006; T007 -> T008; all -> T009, T010.
US1 and US2 share the header (T002); after it they are independent.

## Parallel opportunities

T007 (saltests) can be written in parallel with T003-T005 (different files).

## Implementation strategy

MVP = T002-T006 (the crash is gone); T007-T008 prove the masks are kept whole and the results unchanged.
