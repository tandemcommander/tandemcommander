# Tasks: The tar plug-in applies PAX extended headers

**Input**: `specs/306-tar-pax-headers/` - plan.md, spec.md, research.md, data-model.md, contracts/salpaxheader.md, quickstart.md
**Tests**: `saltests` checks (FR-009) and the hidden-desktop probe (SC-001) are required by the spec.

## Phase 1: Setup

- [X] T001 Start `specs/306-tar-pax-headers/fix-log.md` with the before measurement (`probe/result_before.txt`, 9 FAIL / 13 PASS) and the GNU-TOOLONG crash

## Phase 2: Foundational (blocks every story)

- [X] T002 Write `src/common/salpaxheader.h` per contracts/salpaxheader.md (SalPaxValues, SalPaxInit/Clear, SalPaxNextRecord, SalPaxParseSize, SalPaxParseTime, SalPaxApply, SalPaxEffectivePath/Size/MTime, SalPaxPathHasTooLongComponentU8), UTF-8-BOM, SPDX header
- [X] T003 Add `TestPaxHeader306` to `src/saltests/saltests.cpp` (records, malformed forms, NUL padding, empty values, last-wins, size bounds, time forms and range, precedence, component check agreeing with `SalNameTooLongForFileSystemU8`) and call it from the test list
- [X] T004 Add `MTimeFrac`, `NameFromPax` to `SCommonHeader` and `GlobalPax`, `ReportRefusedNames`, `RefusedNameShown` to `CArchive` in `src/plugins/tar/tar.h`; reset / free them in `SCommonHeader::Initialize`, the `CArchive` constructor and destructor in `src/plugins/tar/untar.cpp`

## Phase 3: User Story 1 - real names (P1)

- [X] T005 [US1] In `CArchive::ReadTarHeader` (`src/plugins/tar/untar.cpp`) read `x` / `g` data (bounded by `SAL_PAX_MAX_HEADER_BYTES`), `SalPaxApply` into the member / global values, refuse malformed with `IDS_TARERR_HEADER`, read and validate the next header block, continue; remove `XHDTYPE` / `XGLTYPE` from the "cannot handle" cases
- [X] T006 [US1] Apply the effective PAX path as `header.Name` (over a GNU long name and the classic name), set `NameFromPax`; reset `GlobalPax` in `ReadArchiveHeader` when `probe` is TRUE (`src/plugins/tar/untar.cpp`)

## Phase 4: User Story 2 - size and time (P2)

- [X] T007 [US2] Apply the effective `size` (not for LNK / SYM / DIR) and `mtime` (seconds + `MTimeFrac`) in `ReadTarHeader`; add `MTimeFrac` after the FILETIME conversion in `ReadArchiveHeader` (`src/plugins/tar/untar.cpp`)

## Phase 5: User Story 3 - refusal (P3)

- [X] T008 [US3] In `ReadArchiveHeader` after normalisation: `NameFromPax` + `SalPaxPathHasTooLongComponentU8` -> `Ignored`; when `ReportRefusedNames` and not yet shown, show `GetErrorText(ERROR_FILENAME_EXCED_RANGE)` + the path (heap text, title `IDS_TARERR_TITLE`); set `ReportRefusedNames` in `ListArchive` and `UnpackWholeArchive` (`src/plugins/tar/untar.cpp`)

## Phase 6: Polish & verification

- [X] T009 `python tools/check_encoding.py --strict` - TOTAL: 0; FR-010: `git diff main --stat -- src/plugins/tar/lang src/plugins/tar/tar.rc2 src/plugins/tar/tar.rh2` empty (no UI string added)
- [X] T010 `build.cmd` - BUILD SUCCEEDED; `saltests.exe` - 0 failed
- [X] T011 Probe after: `specs/306-tar-pax-headers/probe/result_after.txt` - all rows PASS
- [X] T012 Negative control: the PAX branch disabled -> PAX rows FAIL (`probe/result_negctl.txt`); restore and rebuild
- [X] T013 Regression probes 252, 273, 275 -> `probe/regress_*.txt` unchanged
- [X] T014 Record results in `fix-log.md`; Inbox item for the GNU-TOOLONG crash (`measure:306`)

## Dependencies

T001 → T002 → T003; T002 → T004 → T005 → T006 → T007 → T008 → T009..T014. Stories share one
function, so they are implemented in order; each is checked by its own probe rows.

## Parallel opportunities

T003 (tests) and T004 (struct fields) touch different files after T002.

## Implementation strategy

MVP = US1 (names); US2 and US3 follow in the same reader; one build and probe run at the end, the
negative control after.
