# Tasks: Code Viewer decodes single-byte files with the product's conversion tables

**Input**: `specs/262-codeview-code-tables/` - plan.md, spec.md, research.md, data-model.md,
contracts/encoding-menu.md, quickstart.md
**Tests**: the project rule asks pure decisions to be checked in `saltests` (CLAUDE.md, stop-rules
§2.5) - included.

## Phase 1: Setup

- [X] T001 Generate the 256-byte literals of `convert/centeuro/c8521250.tab` and `iso21250.tab` for the unit checks (Python, read-only) and keep the generator command in specs/262-codeview-code-tables/fix-log.md

## Phase 2: Foundational (blocks every story)

- [X] T002 Create the header-only rule src/common/salcodetable.h: `SalCodeTableApply` (in place, `t[(unsigned char)c]`), `SalCodeTableDisplayName` (single `&` dropped, `&&` -> `&`, trailing spaces trimmed), `SalCodeTableCycle(pos, dir, count)` (wraps), `SalCodeTableFromCommand(offset, fixedCount, tableCount, &enc, &table)` (menu id -> encoding / table index, FALSE out of range), `SalCodeTableToUse(forcedEncoding, forcedTable, remembered, ansiIndex)` (data-model table), `SalCodeTableFindName(names, count, name)` (byte-exact, NULL entries skipped)
- [X] T003 Add `TestCodeTable262()` to src/saltests/saltests.cpp: the corpus lines of cp852.bat / iso8859-2.ini through the real tables decode (code page 1250) to "Příliš žluťoučký kůň úpěl ďábelské ódy"; ASCII is identity; display names; cycle wrap both ways and count 5; command mapping incl. out of range; table choice rows of data-model.md; find by exact bytes (case and spacing differ -> not found); include the header and call the test from `main`

## Phase 3: User Story 1 - read a single-byte file in another code page (P1)

**Goal**: the Encoding menu lists the tables, choosing one re-decodes the open file, status bar names it, F8 cycles.
**Independent test**: quickstart steps 1-4.

- [X] T004 [US1] src/plugins/codeview/intake.h / intake.cpp: `CvLoadFile(nameUtf8, forcedEncoding, ansiTable, forcedLanguage, out)` - when the result is `cvEncAnsi` and `ansiTable != NULL`, apply it to the bytes (`SalCodeTableApply`, in place over the read buffer) before `CvDecode` with `CP_ACP`; `out.TableApplied` records it; every other path unchanged
- [X] T005 [US1] src/plugins/codeview/viewer.h: per-window table list (`std::vector<CvCodeTableItem>` name/table/isSeparator), `ForcedTable`, `TableUsed`, helper declarations (`LoadCodeTables`, `TableCount`, `TableAt`, `CurrentListPos`)
- [X] T006 [US1] src/plugins/codeview/viewer.cpp: enumerate with `EnumConversionTables` when the menu is built; append a separator and the tables (`AppendMenuA`, ids `CM_ENCODING_FIRST + 5 + i`, separators collapsed; no table enumerated -> the five entries only, no separator); `RefreshChecks` checks exactly one item (table used, else encoding)
- [X] T007 [US1] src/plugins/codeview/viewer.cpp: `SelectEncoding(encoding, table)` - re-read into a copy with the chosen table, keep the live intake on failure (FR-009); `WM_COMMAND` range `CM_ENCODING_FIRST .. +5+T` via `SalCodeTableFromCommand`; `CycleEncoding` over `5 + T` positions with `SalCodeTableCycle` (T = 0 -> the old cycle over five)
- [X] T008 [US1] src/plugins/codeview/viewer.cpp `UpdateStatus`: the table's display name (code page -> wide with `CP_ACP`) instead of `ANSI` when a table decoded the file

## Phase 4: User Story 2 - the choice is remembered (P2)

**Goal**: the chosen table applies to later single-byte files, also after a restart; *System code page* forgets it.
**Independent test**: quickstart step 5-6.

- [X] T009 [US2] src/plugins/codeview/codeview.h / codeview.cpp: remembered name (`char[210]`, code-page bytes) behind a critical section created at DLL attach; `CvGetDefaultConvert(char* buf, int size)`, `CvSetDefaultConvert(const char* name)` (a name that does not fit is not stored - refuse, never cut; returns FALSE)
- [X] T010 [US2] src/plugins/codeview/config.cpp: `DefaultConvert` REG_SZ - save: code page -> wide -> UTF-8; load: UTF-8 -> wide -> code page with `WC_NO_BEST_FIT_CHARS` and the used-default check; any failure -> empty
- [X] T011 [US2] src/plugins/codeview/viewer.cpp: `OpenFile` (also next / previous file) looks the remembered name up in the window's list (`SalCodeTableFindName`) and passes that table for a detected single-byte file (`SalCodeTableToUse`); `SelectEncoding` sets the remembered name on a successful table choice and clears it on a successful *System code page* choice; UTF-8 / UTF-16 choices leave it; other open windows are not notified or re-decoded (FR-010 - no broadcast)

## Phase 5: User Story 3 - nothing changes for files that work today (P1)

**Goal**: no remembered table = today's behaviour; the five entries unchanged.
**Independent test**: saltests rows "no table"; codeview `run_tests.cmd`; code review of the unchanged paths.

- [X] T012 [US3] Verify in src/plugins/codeview/intake.cpp that with `ansiTable == NULL` the decode path is byte-for-byte the old one (diff read), and that `CvCanView` is untouched; record in specs/262-codeview-code-tables/fix-log.md

## Phase 6: Polish

- [X] T013 Run `python tools/check_encoding.py --strict` (TOTAL: 0), `.\build.cmd` (BUILD SUCCEEDED), saltests (0 failed), `src\plugins\codeview\test\run_tests.cmd`; record numbers in specs/262-codeview-code-tables/fix-log.md
- [X] T014 Record in specs/262-codeview-code-tables/fix-log.md the GUI rows NOT DRIVEN (the decoded text lives in a WebView2 page; menu / letters / remembering need a person - quickstart "By a person") for the person-step item

## Dependencies

T001 -> T003; T002 -> T003, T004, T006-T011; T004 -> T007; T005 -> T006-T008, T011; T009 -> T010, T011.
US1 before US2 (US2 reuses the list and `SelectEncoding`); US3 is a check over US1/US2.

## Parallel opportunities

T001 with T002; T009/T010 with T005/T006 (different files).

## Implementation strategy

MVP = Phases 1-3 (the tables usable on the open file); then US2 (remembering); then the US3 check and polish.
