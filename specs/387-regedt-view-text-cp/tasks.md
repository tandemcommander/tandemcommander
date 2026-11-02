# Tasks: Registry Editor View of a text value keeps the whole text on a multi-byte code page

**Input**: `specs/387-regedt-view-text-cp/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: requested by the spec (FR-006, SC-001..SC-003) - `saltests` checks.

## Phase 1: Setup

- [X] T001 Start `specs/387-regedt-view-text-cp/fix-log.md` with the step-3 measurement (ctypes reproduction, sites, reachability)

## Phase 2: Foundational

- [X] T002 Add `SalRegViewTextToCodePageAlloc` and the `SALREGVIEW_*` results to `src/common/salregfind.h` (header comment: feature 387; reuses `SalRegFindTextToCodePage`; `units = size / 2`; whole or nothing)

## Phase 3: User Story 1 - View a non-ASCII text value whole (P1)

**Goal**: the viewer's copy holds the whole code-page form. **Independent test**: `saltests`.

- [X] T003 [US1] Add `TestRegViewTextToCodePage387` to `src/saltests/saltests.cpp` (65001 `a€\0` -> 5 bytes `61 E2 82 AC 00`; 65001 `čččč bar\0` -> 13 bytes ending ` bar\0`; 932 two hiragana + NUL -> 5 bytes; 1250 byte-identical to the old one-byte-a-unit export; REG_MULTI_SZ `a\0€\0\0`; odd size; negative control: the old unit-sized space fails on 65001) and call it from the test list
- [X] T004 [US1] Rewrite the conversion in `ExportValueData` in `src/plugins/regedt/fs3.cpp`: allocate `size` only, after the read call the rule with `CP_ACP` for REG_SZ / REG_EXPAND_SZ / REG_MULTI_SZ when `ExportStringsForViewerInASCII`, write the returned bytes and count, free the copy on every path

## Phase 4: User Story 2 - never stale bytes (P2)

**Goal**: failed conversion -> UTF-16 data; short write -> error. **Independent test**: `saltests` (invalid code page).

- [X] T005 [US2] In `TestRegViewTextToCodePage387` (`src/saltests/saltests.cpp`) check the UTF-16 result for an invalid code page and for an empty / 1-byte value (out NULL, len 0)
- [X] T006 [US2] In `ExportValueData` (`src/plugins/regedt/fs3.cpp`) handle `SALREGVIEW_LOWMEM` with `IDS_LOWMEM` (no file), `SALREGVIEW_UTF16` by writing the data as stored, and fix the write check to `WriteFile(...) && written == size`

## Phase 5: Polish

- [X] T007 Encoding guard `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [X] T008 Build `.\build.cmd` -> `BUILD SUCCEEDED`; `saltests.exe` -> `0 failed`
- [X] T009 Repeat the measurement (ctypes old vs saltests new) and record before / after in `specs/387-regedt-view-text-cp/fix-log.md`; the GUI case on a UTF-8 / DBCS machine recorded as NOT DRIVEN (owed to a person)

## Dependencies

T001 -> T002 -> (T003, T004) -> (T005, T006) -> T007 -> T008 -> T009. T003 and T004 touch
different files ([P] possible after T002); US2 extends the same files as US1.

## Implementation strategy

MVP = US1 (T002-T004); US2 is the failure handling of the same function, done in the same pass.
