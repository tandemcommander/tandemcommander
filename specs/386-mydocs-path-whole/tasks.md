# Tasks: The Documents folder is opened whole, never cut

**Input**: `specs/386-mydocs-path-whole/` (plan.md, spec.md, research.md, data-model.md, contracts/salmydocs.md, quickstart.md)
**Tests**: the item asks to measure first - the probe seam and the probe come before the fix; the rule gets saltests checks (stop-rules §2.5).

## Phase 1: Setup

- [ ] T001 Start the running record `specs/386-mydocs-path-whole/fix-log.md` with the measurement of step 3 (code reading at 10eb1994, the caller table of research.md R2)

## Phase 2: Foundational (measure first)

- [ ] T002 Add the Debug-only seam `TC_PROBE_MYDOCS_PATH` to `GetMyDocumentsOrDesktopPath` in `src/shellib.cpp` (old behaviour otherwise unchanged), per contracts/salmydocs.md
- [ ] T003 Write the probe `specs/386-mydocs-path-whole/probe/mydocs386_probe.ps1` (rows LONG, SHORT, RESCUE; registry backup / restore via `specs/098-long-path-overruns/probe/fix_probe_lib.ps1`; fixture under `%TEMP%\tc386`)
- [ ] T004 Build Debug (`.\build.cmd`), run the probe on the hidden desktop -> `specs/386-mydocs-path-whole/probe/result_before.txt`; record in fix-log.md (expected: LONG and RESCUE FAIL = the prefix folder, SHORT PASS); commit the seam and probe

## Phase 3: User Story 1 - the Documents drive opens the Documents folder (P1)

**Goal**: the drive bar / Alt+F1/F2 Documents item and Ctrl+; open the whole Documents path.
**Independent test**: probe row LONG PASS, SHORT PASS.

- [ ] T005 [US1] Create the rule header `src/common/salmydocs.h` (`SalDocumentsOrDesktopToU8`, `SAL_DOCS_*`) per contracts/salmydocs.md and data-model.md
- [ ] T006 [US1] Add `TestDocumentsPath386` to `src/saltests/saltests.cpp` (include `salmydocs.h`; rows of the decision table, 259 / 260 byte boundary, 90 CJK letters with 260 and `SAL_MAX_PATH_UTF8`, a lone surrogate, never a prefix) and call it from `main`
- [ ] T007 [US1] Rewrite `GetMyDocumentsOrDesktopPath` in `src/shellib.cpp`: read Documents wide (seam kept), Desktop wide only when Documents has no path, hand both to `SalDocumentsOrDesktopToU8`; drop `buff[2 * MAX_PATH]`, `lstrcpyn` and `SalU8TrimIncompleteTail`
- [ ] T008 [P] [US1] `src/fileswn0.cpp` Ctrl+;: `char path[SAL_MAX_PATH_UTF8]`, pass `SAL_MAX_PATH_UTF8`
- [ ] T009 [P] [US1] `src/fileswn3.cpp` `ChangePathToDrvType`: `char path[SAL_MAX_PATH_UTF8]`, `GetMyDocumentsOrDesktopPath(path, SAL_MAX_PATH_UTF8)`; check that the other branches (`GetPathForGoogleDrive(path, MAX_PATH)`, `strcpy_s(path, ...)`) keep their limits
- [ ] T010 [P] [US1] `src/salamdr6.cpp` `SafeGetSaveFileNameW` / `SafeGetOpenFileNameW`: `initDir[SAL_MAX_PATH_UTF8]`, pass `SAL_MAX_PATH_UTF8`

## Phase 4: User Story 2 - short buffers refuse (P2)

**Goal**: the rescue path never gets the cut prefix.
**Independent test**: probe row RESCUE PASS.

- [ ] T011 [US2] Check `GetIfPathIsInaccessibleGoTo` (`src/salamdr6.cpp`) and its callers keep working with a refusal (fallback = Windows drive root); add a comment at the call that the refusal is intended (feature 386); no buffer change (spec Clarifications)

## Phase 5: Polish

- [ ] T012 `python tools/check_encoding.py --strict` -> TOTAL: 0; `.\build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed
- [ ] T013 Run the probe after the fix -> `specs/386-mydocs-path-whole/probe/result_after.txt` (all PASS); record before / after in fix-log.md; record Ctrl+; and the File dialog fallback as NOT DRIVEN (same helper; code reading)
- [ ] T014 Add the Inbox leftover for a rescue path that holds a long Documents path (`leftover:386`) if the review or the measurement shows it is worth an item

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> (T008, T009, T010 in parallel) -> T011 -> T012 -> T013 -> T014.
US2 depends on T007 (the helper's refusal).

## Implementation strategy

MVP = Phase 2 + US1 (the defect of the item). US2 is a check of the existing fallback.
