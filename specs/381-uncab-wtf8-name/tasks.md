# Tasks: UnCAB - a cabinet name with an unpaired surrogate no longer fails the whole cabinet

**Input**: `specs/381-uncab-wtf8-name/` (spec.md, plan.md, research.md, data-model.md,
contracts/cab-name-decoding.md, quickstart.md)
**Tests**: requested by the spec (FR-005 unit checks, SC-001/SC-002 probe rows).

## Phase 1: Setup

- [ ] T001 Start the running record `specs/381-uncab-wtf8-name/fix-log.md` with the step-3 measurement (fixture, probe, `result_before0.txt` / `result_before.txt`, the silent-refusal correction)

## Phase 2: Foundational

- [ ] T002 Add `SplIsWtf8(const char*)` to `src/plugins/shared/splunicode.h` (the existing `SplUnicodeDetail::Wtf8ToW` measure call; NULL -> FALSE), per contracts/cab-name-decoding.md
- [ ] T003 Create the header-only rule `src/plugins/uncab/cabname.h`: `CCabNameRead` (`CABNAME_UTF8`, `CABNAME_CODEPAGE`, `CABNAME_REFUSE`), `CABNAME_A_NAME_IS_UTF` (0x80), `CabNameReadAs(name, attribs)` per data-model.md

## Phase 3: User Story 1 - WTF-8 names list and unpack (P1)

**Goal**: a flagged WTF-8 name is read as UTF-8, byte for byte.
**Independent test**: saltests `TestCabName381`; probe rows U-WTF8, U-WTF8L, L-WTF8, L-WTF8L.

- [ ] T004 [US1] Add `TestCabName381` to `src/saltests/saltests.cpp` (include `../plugins/uncab/cabname.h`; register it in the test list): accepted vectors (ASCII, `a\xC3\xA9`, lone high/low surrogates, a reversed pair, a 4-byte astral letter) give `CABNAME_UTF8` flagged and unflagged-unreported, `CABNAME_CODEPAGE` with attribs 0; `SplIsWtf8` agrees with `SplU8ToWAlloc != NULL` and the core's `SalU8ToW` on every vector, and exhaustively over all 1-, 2- and 3-byte strings
- [ ] T005 [US1] Rewrite `CabNameToU8` in `src/plugins/uncab/uncab.cpp` on `CabNameReadAs` (keep the verbatim copy, the `lstrlen >= bufSize` refusal and the code-page branch; `static_assert(CABNAME_A_NAME_IS_UTF == _A_NAME_IS_UTF)`); update its comment
- [ ] T006 [US1] Build (`.\build.cmd`), run saltests, run the probe -> `probe/result_after.txt`

## Phase 4: User Story 2 - malformed names stay refused, others unchanged (P2)

**Independent test**: probe rows U-OK, L-OK, U-BAD, U-OVER, L-BAD; saltests refusal vectors.

- [ ] T007 [US2] In `TestCabName381` (`src/saltests/saltests.cpp`): malformed vectors (`a\xFFb`, `a\xC0\x80b`, overlong 3-byte, above U+10FFFF, stray continuation, truncated, truncated surrogate) give `CABNAME_REFUSE` flagged and `CABNAME_CODEPAGE` with attribs 0 and with -1
- [ ] T008 [US2] Confirm in `probe/result_after.txt` that the control and refusal rows stay PASS (same as `result_before.txt`)

## Phase 5: Polish

- [ ] T009 `python tools/check_encoding.py --strict` (TOTAL: 0) and `python tools/check_encoding.py --plugins` (no `uncab/uncab.cpp`), counts in `fix-log.md`
- [ ] T010 Negative control: the T004/T007 checks against a strict-only rule fail (recorded in `fix-log.md`)
- [ ] T011 Record before / after, commands and results in `specs/381-uncab-wtf8-name/fix-log.md`

## Dependencies

T001 -> T002 -> T003 -> (T004, T005) -> T006 -> T007 -> T008 -> T009..T011. US2 checks reuse US1's rule.

## Parallel opportunities

T004 (saltests) and T005 (uncab.cpp) touch different files once T003 exists.

## Implementation strategy

MVP = US1 (the item's main point); US2 guards that nothing else changes. No UI string changes, so no
`.slt` refresh.
