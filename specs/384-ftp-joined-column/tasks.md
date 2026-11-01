# Tasks: FTP - a listing column built from several parts is decoded part by part

**Input**: Design documents from `specs/384-ftp-joined-column/` (plan.md, spec.md, research.md, data-model.md, quickstart.md)

**Tests**: the spec asks for unit checks of the pure rule (FR-009) and a probe (SC-001 / SC-002) - included.

## Phase 1: Setup

- [X] T001 Reproduction probe and test server (z/VM listing form) in specs/384-ftp-joined-column/probe/ftp384_probe.ps1 and specs/384-ftp-joined-column/probe/ftpmini.py; before-run recorded in specs/384-ftp-joined-column/probe/result_before.txt (2 FAIL, 6 PASS)

## Phase 2: Foundational

- [ ] T002 Add the pure rules `SalFtpJoinPartHandling` (enum SALFTPJOIN_RAW / COLUMN / LITERAL -> decode as server field / append as is / decode alone) and `SalFtpJoinedFieldIsCodePageName` in src/common/salftpsrvenc.h
- [ ] T003 Add saltests checks for both rules (every kind, unknown kind = as is, the four truth-table rows) in src/saltests/saltests.cpp

## Phase 3: User Story 1 - a z/VM name with non-ASCII letters in both parts on a code-page server (P1)

**Goal**: `nameč.extč` from a cp1250 z/VM listing is shown and addressed as `nameč.extč`.
**Independent test**: probe rows ZVM-CP-DEL and ZVM-CP-DL pass.

- [ ] T004 [US1] Add `FTPListingJoinFieldU8(headU8, headLen, part, partLen, partKind)` in src/plugins/ftp/ftputils.cpp (declaration in src/plugins/ftp/ftputils.h): decode the part by `SalFtpJoinPartHandling` (raw: `FTPFieldToU8(.., FTPListingServer, 0)`; literal: `FTPFieldToU8(.., NULL, 0)`; column: copy), join into a `SalamanderGeneral->Alloc` buffer, register the joined value with `FTPAddServerName(srv, FTPNAME_CODEPAGE, ..)` when `SalFtpJoinedFieldIsCodePageName` (head is a code-page name of `FTPListingServer`, or the raw part is not `SalFtpListingFieldIsU8`); NULL on low memory
- [ ] T005 [US1] Split `AssignU8StringToColumn` (takes an owned, already decoded string) out of `AssignStringToColumn` in src/plugins/ftp/parser2.cpp; `AssignStringToColumn` keeps decoding and calls it; the 215 name limit (`FTP_MAX_NAME_U8`) check and the invalid-type / invalid-index handling stay in the split-out function
- [ ] T006 [US1] Rewrite case `fpfAdd_string_to_column` in src/plugins/ftp/parser2.cpp: part kind from `Parameters[1]->Type` (`pptStateVar` raw, `pptColumnID` column, `pptString` literal), `FTPListingJoinFieldU8`, then `AssignU8StringToColumn`; empty part still ignored; low memory sets `lowMemErr`
- [ ] T007 [US1] Build (`.\build.cmd`) and run the probe -> result_after.txt in specs/384-ftp-joined-column/probe/ (ZVM-CP-DEL, ZVM-CP-DL PASS)

## Phase 4: User Story 2 - names that worked keep working (P2)

**Goal**: ASCII-head code-page names and UTF-8 server names unchanged.
**Independent test**: probe rows ZVM-CP-ASCII and ZVM-UTF-DEL pass; 288 / 269 / 224 probes unchanged.

- [ ] T008 [US2] Run the regression probes of features 288, 269, 224 (specs/288-ftp-per-server-encoding/probe/ftp288_probe.ps1, specs/269-ftp-wtf8-listing/probe/ftp269_probe.ps1, specs/224-ftp-utf8-server-names/probe/ftp224_probe.ps1) -> results in specs/384-ftp-joined-column/probe/regress_*.txt
- [ ] T009 [US2] Negative control: the probe's after-run with the old case restored fails ZVM-CP-DEL / ZVM-CP-DL (record in specs/384-ftp-joined-column/fix-log.md)

## Phase 5: Polish

- [ ] T010 `python tools/check_encoding.py --strict` (TOTAL: 0), clang-format of changed sources, saltests 0 failed; record in specs/384-ftp-joined-column/fix-log.md

## Dependencies

T001 -> T002 -> T003; T002 -> T004 -> T005 -> T006 -> T007 -> T008, T009 -> T010. US2 depends on US1 (same code).

## Parallel examples

T003 (saltests) and T005 (parser split) touch different files and may run in parallel after T002.

## Implementation strategy

MVP = US1 (T002-T007); US2 is verification of the same change.
