# Tasks: Importing a configuration file never writes or deletes keys outside the program's own root

**Input**: Design documents from `specs/263-import-foreign-reg-keys/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/import-root-rule.md, quickstart.md

**Tests**: requested by the spec (FR-006 `saltests`, SC-001/SC-002 probe rows).

## Phase 1: Setup

- [X] T001 Start the running log `specs/263-import-foreign-reg-keys/fix-log.md` with the measurement at `0e36adce` (probe rows, `probe/result_before.txt`) and the callers enumerated in research R4

## Phase 2: Foundational (blocks every story)

- [X] T002 Create the header-only rule `SalRegKeyIsInsideRoot` in `src/common/salregroot.h` per `contracts/import-root-rule.md` (UTF-8-BOM, house header comment, no globals)
- [X] T003 [P] Add `TestRegImportRoot263` with the contract's cases (equal, below, trailing `\`, sibling `0.10` / `0.1x`, parent, other key, doubled backslash, letter case, empty / NULL name and root, non-ASCII byte) to `src/saltests/saltests.cpp`, include the header and call it from `main`
- [X] T004 List `src/common/salregroot.h` in `src/vcxproj/salamand.vcxproj` and `src/vcxproj/salamand.vcxproj.filters` - not done: the recent rule headers (`salregfind.h` 257, `salcodetable.h` 262) are not listed either; the build tracks the include (see fix-log)
- [X] T005 Append `RPE_KEY_OUTSIDE_ROOT` to `eRPE_ERROR` and the defaulted parameter `LPCTSTR onlyUnderHKCU = NULL` to `Parse()` in `src/reglib/src/regparse.h`
- [X] T006 In `Parse()` in `src/reglib/src/regparse.cpp`: at every `[` line, after the root key and name are recognised and before create / open / delete, return `RPE_KEY_OUTSIDE_ROOT` when the restriction is given and the root key is not `HKEY_CURRENT_USER` or the name is not inside (trace the line in the core build, FR-007); outside the core code-page build a non-NULL restriction refuses every key line

**Checkpoint**: `saltests` builds and passes; `Parse()` without the parameter behaves as before.

## Phase 3: User Story 1 - a file with a foreign key writes nothing (P1)

**Independent test**: probe rows MIXED and HKCR.

- [X] T007 [US1] In `ImportConfiguration()` in `src/salamdr2.cpp`: pass `SalamanderConfigurationRoots[0]` to the memory pass and the registry pass; map `RPE_KEY_OUTSIDE_ROOT` to `IDS_IMPORTCFG_NOTREG` in the error switch; trace the refused file name; the file itself is never written (FR-007)

## Phase 4: User Story 2 - a delete line never removes another program's key (P1)

**Independent test**: probe row DELETE.

- [X] T008 [US2] Confirm in `src/reglib/src/regparse.cpp` that the check of T006 runs before the delete branch (`bDelete`) as well as before `CreateKey`; probe row DELETE in `specs/263-import-foreign-reg-keys/probe/import263_probe.ps1` covers it

## Phase 5: User Story 3 - a file without our configuration is refused without a question (P2)

**Independent test**: probe row NOROOT.

- [X] T009 [US3] In `ImportConfiguration()` in `src/salamdr2.cpp`: replace the `IDS_IMPORTCFG_NOTOURVER` question by a refusal (`regerr = RPE_NOT_REG_FILE`, reported with `IDS_IMPORTCFG_NOTREG`); leave the string in `src/lang/texts.rc2` unchanged

## Phase 6: User Story 4 - the program's own files import as before (P1)

**Independent test**: probe rows OURS and OWNDEL.

- [X] T010 [US4] Check that `ExportConfiguration()` in `src/salamdr2.cpp` writes only keys and the delete line inside the root (research R5) and that the probe's OURS / OWNDEL rows pass after the change

## Phase 7: Polish & verification

- [X] T011 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [X] T012 `.\build.cmd` (PowerShell) -> `BUILD SUCCEEDED`
- [X] T013 `saltests.exe` -> `0 failed`
- [X] T014 Probe after (quickstart step 3) -> all rows PASS (OURS, OWNDEL, MIXED, NOROOT, DELETE, HKCR), registry restored identical; result in `specs/263-import-foreign-reg-keys/probe/result_after.txt`
- [X] T015 Negative control: the probe's MIXED/NOROOT/DELETE rows fail on the before build (`probe/result_before.txt`, already recorded) and a saltests check flipped by hand fails - record in `fix-log.md`
- [X] T016 Record before / after, commands and results in `specs/263-import-foreign-reg-keys/fix-log.md`

## Dependencies

- T002 -> T003, T004, T006; T005 -> T006 -> T007, T008, T009; T007-T010 -> T011-T016.
- US1, US2 and US3 share `ImportConfiguration()` / `Parse()` - done in order, not in parallel.

## Parallel examples

- T003 (saltests) and T005 (regparse.h) touch different files after T002.

## Implementation strategy

MVP = Phase 2 + US1 (T007): the restriction in both passes already stops every foreign write and
delete; US3 removes the question; US4 is the regression check.
