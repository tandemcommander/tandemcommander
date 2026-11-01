# Tasks: A path typed in another case into an archive with case twins elsewhere opens the folder

**Input**: Design documents from `specs/382-arc-case-twins-path/` (plan.md, spec.md, research.md,
data-model.md, contracts/arcpath-resolve.md, quickstart.md)
**Tests**: requested by the spec (FR-006 unit checks, SC-001..SC-004 probe rows).

## Phase 1: Setup

- [X] T001 Confirm the before measurement is recorded (`specs/382-arc-case-twins-path/probe/result_before.txt`, 14 / 6) and the probe `specs/382-arc-case-twins-path/probe/arctwins382_probe.ps1` uses fixture `tc382` and backup `tc382_backup.reg`

## Phase 2: Foundational (the pure rule)

- [X] T002 Add `SalArcPathResolveCase` (contract `contracts/arcpath-resolve.md`) to `src/common/salarcpathspell.h`, with a header comment for feature 382
- [X] T003 Add `TestArcPathResolveCase382` to `src/saltests/saltests.cpp` (accessor over `FakeDir252` with `CaseSensitive`, `FoldEqual` = legacy fold, `AnyCaseEqual` = legacy fold or `SalNameOrderCompareCI`): unique fold match resolved, exact wins over a twin, ambiguous twins not resolved, deep path, partial resolution keeps the rest verbatim, file name / empty component / below empty folder, case-insensitive listing unchanged, ordinal-only match not accepted but counted, size refusal (exact fit, one less) - and call it from the test list

## Phase 3: User Story 1 - open the folder of an archive with twins elsewhere (P1)

**Independent test**: probe rows MIXED, MIXDEEP, MIXMISS for TAR and 7z.

- [X] T004 [US1] Add `CSalamanderDirectory::ResolvePathCase(const char* path, char* out, int outSize)` to `src/zip.h` and `src/zip.cpp` (accessor extending `CSalDirRespellAccess`: `CaseSensitive` = folder flag, `FoldEqual` = `StrICmpEx`, `AnyCaseEqual` = `StrICmpEx` or `SalNameCompareOrdinalCI`)
- [X] T005 [US1] In `CFilesWindow::ChangePathToArchive` (`src/fileswn2.cpp`), right after the typed `path` is stripped and before the "new path matches the current one" check, call `GetArchiveDir()->ResolvePathCase(path, ...)` into a `char[MAX_PATH]` and take the result when it differs and has the same length
- [X] T006 [US1] Build (`.\build.cmd`), run saltests, run the probe -> MIXED, MIXDEEP, MIXMISS PASS for TAR and 7z (`probe/result_after.txt`)

## Phase 4: User Story 2 - exact names and twins keep their meaning (P2)

**Independent test**: probe rows EXACT and AMBIG for TAR and 7z; probes 273 and 252.

- [X] T007 [US2] Confirm in `probe/result_after.txt` that EXACT and AMBIG rows PASS for TAR and 7z
- [X] T008 [US2] Run `specs/273-tar-case-root/probe/arccase273_probe.ps1` (12 / 0) and `specs/252-archive-case-sensitivity/probe/arc252_probe.ps1` (16 / 0); record in `fix-log.md`

## Phase 5: Polish

- [X] T009 Negative controls: the loose step of `SalArcPathResolveCase` disabled -> saltests checks FAIL and probe MIXED rows FAIL (equivalent to disabling the call in `ChangePathToArchive`) (in a scratch build or by restoring after; record in `fix-log.md`)
- [X] T010 Encoding guard `python tools/check_encoding.py --strict` -> TOTAL: 0
- [X] T011 Update `specs/382-arc-case-twins-path/fix-log.md` (after measurements, checks, negative controls)

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007/T008 -> T009 -> T010 -> T011. US2 needs the
US1 build (the same code serves both). No parallel tasks (each step depends on the build).

## Implementation strategy

MVP = US1 (the item's defect); US2 is the regression guard of the same change.
