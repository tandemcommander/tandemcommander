# Tasks: The program does not depend on Windows 8 functions to start (feature 126)

**Input**: `specs/126-package-api-late-bind/` - spec.md, plan.md, research.md, data-model.md, quickstart.md
**Tests**: requested by the maintainer ("independent tests for every issue").

## Phase 1: Setup

- [x] T001 Write `specs/126-package-api-late-bind/probe/pe_imports.py` (PE import-table reader: list, delay, find, diff, check)
- [x] T002 Keep the pre-fix Release executable (`%TEMP%\tc126_release_before.exe`) for the diff

## Phase 2: Foundational (measure first)

- [x] T003 Read the imports of the Release tree: the two functions, which files (research R1)
- [x] T004 Minimum Windows versions from Microsoft's reference (research R1)
- [x] T005 Start `specs/126-package-api-late-bind/fix-log.md`

## Phase 3: User Story 1 - the program starts wherever its own check lets it (P1)

**Independent test**: `pe_imports.py check` on the Release tree = 0; saltests with the functions absent.

- [x] T006 [US1] `src/common/salshell.h`: `CSalShellPackageApi`, `SalShellResolvePackageApi`, `SalShellPackagePath`
- [x] T007 [US1] `src/common/salshell.cpp`: the lookup through the table; the resolver (`GetModuleHandleW` + `GetProcAddress`); `CSalShellOsProbe::GetPackagePath` uses both; drop `#include <appmodel.h>`
- [x] T008 [P] [US1] `src/saltests/saltests.cpp`: `TestPackageApi126` - absent table / members, every failure branch with fakes, refusal of a path that does not fit

## Phase 4: User Story 2 - nothing changes on Windows 11 (P1)

**Independent test**: `probe/package_live.ps1`; the existing `TestCommandShell071` unchanged and passing.

- [x] T009 [US2] `src/saltests/saltests.cpp`: the real resolver finds both functions here and reports an invented family as absent; `--package-path <family>` mode of `main`
- [x] T010 [P] [US2] `specs/126-package-api-late-bind/probe/package_live.ps1`: compare with `Get-AppxPackage`

## Phase 5: Gates and records

- [x] T011 Builds (Debug, Release), saltests, `tools/check_encoding.py`
- [x] T012 `pe_imports.py diff` before/after (exactly two entries removed) and `check` on the Release tree -> `probe/imports_result.txt`
- [x] T013 Run `probe/package_live.ps1` -> `probe/package_live_result.txt`
- [x] T014 Independent review by a separate agent (refute-first)
- [x] T015 Records: `fix-log.md`, `specs/FEATURE-HISTORY.md`, `CHANGELOG.md`, `specs/NEXT-WORK.md` (the step owed on an old Windows; the floor decision), `issues/issue_6_report.md`, `issues/PROGRESS.md`
- [x] T016 Commit on `126-package-api-late-bind`, nothing pushed

## Dependencies

T006 -> T007 -> T008/T009; T010 after T009; T011-T014 after the code.

## Implementation strategy

US1 and US2 are one change; they are separate stories because they are tested differently.
