# Tasks: The information line survives running out of memory as its text grows

**Input**: Design documents from `specs/293-infoline-realloc-pair/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: requested by the spec (FR-005, SC-001, SC-002) - unit rules in `saltests` with a failing
allocator.

## Phase 1: Setup

- [X] T001 Start the running log `specs/293-infoline-realloc-pair/fix-log.md` with the measurement at ad477c57 (reading proof of the defect, callers enumerated, TextW / SizeW findings)

## Phase 2: Foundational

- [X] T002 Create the header-only rule `SalGrowBufferPair` (allocator injected; each successful result stored at once; capacity raised only when both grew; a fresh block released again on failure) in src/common/salgrowpair.h (UTF-8 BOM, SPDX header like src/common/salinfolinebuf.h)

## Phase 3: User Story 1 - A panel line that cannot grow keeps working (Priority: P1)

**Goal**: a failed growth of the directory / information line leaves valid buffers and the old text.

**Independent Test**: `saltests` `TestGrowBufferPair293` with a fake allocator that fails chosen calls,
moves every successful block and marks released blocks.

- [X] T003 [US1] Add `TestGrowBufferPair293` (four outcomes of data-model.md, the fresh-line case, a retry after a failure, no growth when the capacity suffices) and its include / call in src/saltests/saltests.cpp
- [X] T004 [US1] Replace the two `realloc` calls of `CStatusWindow::SetText` with `SalGrowBufferPair(Text, AlpDX, Allocated, l)` in src/stswnd.cpp (include the header; keep the TRACE_E and the FALSE result)
- [X] T005 [US1] Negative control: substitute the old store-only-when-both-succeed rule in src/common/salgrowpair.h, build saltests, record the failing checks in fix-log.md, restore the rule

## Phase 4: Polish & Cross-Cutting

- [X] T006 Encoding guard `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`
- [X] T007 `.\build.cmd` → `BUILD SUCCEEDED`; `saltests.exe` → `0 failed`; record numbers in fix-log.md
- [X] T008 Reading proof in fix-log.md: grep every write of `Text`, `AlpDX`, `Allocated` in src/stswnd.cpp; only the constructor, destructor and the rule touch them
- [X] T009 Record the out-of-scope findings (SetSize `Size[0]` before the NULL check; src/gui.cpp `CStaticText::SetText` frees the moved block) as backlog Inbox items with source measure:293

## Dependencies

T001 → T002 → T003, T004 (T003 and T004 touch different files) → T005 → T006–T008 → T009.

## Parallel example

T003 (src/saltests/saltests.cpp) and T004 (src/stswnd.cpp) can be written in parallel after T002.

## Implementation strategy

One story; MVP = the whole feature. No GUI probe: the low-memory case cannot be driven on the
running program (spec Assumptions).
