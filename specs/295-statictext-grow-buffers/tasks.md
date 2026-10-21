# Tasks: A dialog's status text and the panel's size field survive running out of memory

**Input**: Design documents from `specs/295-statictext-grow-buffers/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: requested by the spec (FR-006, SC-001, SC-002) - the `saltests` seam.

## Phase 1: Setup

- [ ] T001 Running log started with the HEAD measurement in specs/295-statictext-grow-buffers/fix-log.md

## Phase 2: Foundational (the shared rule)

- [ ] T002 Add `CSalGrowBuffer<T>` / `SalGrowBuf(ptr, extra)` and the variadic `SalGrowBuffersWith(reallocFn, freeFn, allocated, needed, bufs...)` plus the CRT form `SalGrowBuffers(allocated, needed, bufs...)` (realloc / free inside lambdas - Debug `_CRTDBG_MAP_ALLOC`) in src/common/salgrowpair.h; each success stored at once, every growth attempted in order, `allocated` raised only when all grew, fresh blocks of a failed growth released; rewrite `SalGrowBufferPair` as its two-buffer case; update the header comment
- [ ] T003 Add `TestGrowBuffers295` in src/saltests/saltests.cpp (reusing feature 293's fake heap): five buffers (`char`, `WCHAR`, `int`, `char`+3, `WCHAR`+3) grown from 10 to 100 with every single call failing and chosen combinations; check result, call count, `allocated` unchanged on failure, each buffer live with `allocated + extra` elements, moved / unmoved as expected, live count 5, old contents intact, a later growth succeeds; a fresh set failing at each call stays all NULL with no live block; two-buffer set (no ellipsis) likewise; the CRT form; register it in the test list
- [ ] T004 Build and run saltests; `TestGrowBufferPair293` and `TestGrowBuffers295` pass (0 failed)
- [ ] T005 Negative control: the old `SetText` rule (release earlier results on a later failure) and the old pair rule (store only when all grew) in `SalGrowBuffersWith` - saltests must fail; restore, touch the header, rebuild, 0 failed; record numbers in fix-log.md

## Phase 3: User Story 1 - A dialog text that cannot grow keeps working (P1)

**Goal**: `CStaticText::SetText` never leaves a released block on a failed growth.
**Independent Test**: T003/T004 seam + reading proof in fix-log.md.

- [ ] T006 [US1] Replace the five `realloc` calls of `CStaticText::SetText` in src/gui.cpp with `SalGrowBuffers(Allocated, l + ST_ALLOC_GRANULARITY, ...)` - `Text`, `TextW` always; with `STF_PATH_ELLIPSIS | STF_END_ELLIPSIS` also `AlpDX`, `Text2` (+3), `Text2W` (+3), in the old order; on failure `TRACE_E(LOW_MEMORY); return FALSE;`; include salgrowpair.h
- [ ] T007 [US1] Reading proof in fix-log.md: sizes, order and `Allocated` identical on success; every failure outcome keeps valid blocks and the old text

## Phase 4: User Story 2 - The panel's size field without memory (P2)

**Goal**: `CStatusWindow::SetSize` writes only into storage it has.
**Independent Test**: reading proof.

- [ ] T008 [US2] In `CStatusWindow::SetSize` (src/stswnd.cpp) write `Size[0] = 0` only after `malloc(30)` succeeded; `TRACE_E(LOW_MEMORY)` otherwise
- [ ] T009 [US2] Reading proof in fix-log.md (readers of `Size` are NULL-safe; the next `SetSize` retries)

## Phase 5: Polish

- [ ] T010 `python tools/check_encoding.py --strict` → TOTAL: 0; `.\build.cmd` → BUILD SUCCEEDED; saltests → 0 failed; record in fix-log.md
- [ ] T011 Update the feature 293 note in src/common/salgrowpair.h's header comment to name both callers

## Dependencies

T001 → T002 → T003 → T004 → T005; T006 depends on T002; T008 independent; T010 after all.

## Parallel opportunities

T008 [US2] can be done alongside T002–T006 (different file).

## Implementation strategy

MVP = Phase 2 + US1 (the larger crash); US2 is a one-line guard.
