# Tasks: "*.ext" masks match accented extensions by whole letters

**Input**: Design documents from `specs/283-mask-code-page-fold/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/mask-optimize-kind.md, quickstart.md

**Tests**: requested by the item (saltests checks) and the spec (probe rows, SC-001..SC-003).

## Phase 1: Setup

- [ ] T001 Start the running log `specs/283-mask-code-page-fold/fix-log.md` with the measurement at cb0d80f5 (sites, reachability table of research.md R1, probe `result_before.txt` 14 PASS / 6 FAIL)

## Phase 2: Foundational

- [ ] T002 Create `src/common/salmaskopt.h` (UTF-8 BOM, SPDX header of the project): `SalMaskOptimizeKind(const char* preparedMask, BOOL extendedMode)` returning 0 / 1 / 2 per `contracts/mask-optimize-kind.md` (the old classification of `CMaskGroup::PrepareMasks` + "every extension byte < 0x80" for 2)

## Phase 3: User Stories 1 + 2 - accented `*.xxx` masks match by whole letters, never the wrong file (P1)

**Goal**: an accented `*.xxx` mask goes through `AgreeMask` (include, exclude, any group size).
**Independent Test**: probe rows `miss`, `miss-hash`, `miss-excl`, `false`, `false-hash`, `nfd`.

- [ ] T003 [US1] In `src/masks.cpp` `CMaskGroup::PrepareMasks`, replace the inline classification by `flags->Optimize = SalMaskOptimizeKind(buf, ExtendedMode)` (`hashableMasks++` when it is `MASK_OPTIMIZE_EXTENSION` and `excludePos == -1`); include `salmaskopt.h`; `static_assert` that its values equal `MASK_OPTIMIZE_NONE/ALL/EXTENSION`
- [ ] T004 [US1] In `src/masks.cpp`, comment the `StrICmp(ext, mask + 3)` sites and `COMPUTEMASKGROUPHASH` (only ASCII extension masks reach them since 283; a non-ASCII name extension cannot equal one - saltests), with `encoding-check: allow acp-byte-table-on-name` markers if the guard flags them
- [ ] T005 [P] [US1] saltests in `src/saltests/saltests.cpp`: the classification table of the contract (incl. `*.čtx`, `*.ĥ`, `*.tčx`, `*.t?x`, `*.a.b`, `*.#x` in both modes, `*.`, `*`, `*.*`, `?*.txt`)
- [ ] T006 [P] [US2] saltests in `src/saltests/saltests.cpp`: the old shortcut's measured defects under an emulated CP1250 `CharLowerA` table (`ĥ` vs `Ĺ` equal, `čtx` vs `ČTX` unequal) and that the new rule sends both masks to the letter matcher (kind 0)

## Phase 4: User Story 3 - ASCII masks behave as before (P2)

**Independent Test**: probe rows `same`, `ascii`, `ascii-hash`, `ascii-no`; saltests differential.

- [ ] T007 [P] [US3] saltests in `src/saltests/saltests.cpp`: differential - a copy of the old classification as the reference; over generated masks (alphabet `* ? # . a B 1` + bytes 0xC4 0x8D, lengths 0..6, both modes) old == new whenever every byte is ASCII, and new is 0 or equal to old otherwise
- [ ] T008 [P] [US3] saltests in `src/saltests/saltests.cpp`: in every ANSI code page (874, 932, 936, 949, 950, 1250-1258) the emulated `CharLowerA` fold of a byte 0x80-0xBF is never < 0x80 (research R2)

## Phase 5: Polish & verification

- [ ] T009 Build (`.\build.cmd`), saltests (`saltests: <n> checks, 0 failed`), encoding guard (`TOTAL: 0 finding(s)`) - results in fix-log.md
- [ ] T010 Run the probe after the fix (`probe/result_after.txt`: PASS 20, FAIL 0) and a negative control (the probe against a build without the T003 change must fail, or the before run counts as it - recorded in fix-log.md)
- [ ] T011 Record in fix-log.md: before / after, commands, the unreachable sites (research R1) with their guards unchanged

## Dependencies

T001 -> T002 -> T003 -> T004; T005-T008 need T002 (parallel to each other, all in saltests.cpp - edit sequentially); T009 needs T003-T008; T010 needs T009; T011 last.

## Parallel examples

- T005, T006, T007, T008 are independent checks (one file, written one after another).

## Implementation strategy

MVP = T002 + T003 (the fix) + probe. Then the saltests checks, then verification.
