# Tasks: A folder inside an archive opened in another case is entered under the archive's own spelling

**Input**: Design documents from `specs/273-tar-case-root/` (plan.md, spec.md, research.md,
data-model.md, quickstart.md)
**Tests**: `saltests` checks for the pure rule (stop-rules §2.5) and the hidden-desktop probe
(spec SC-001..003).

## Phase 1: Setup

- [X] T001 Record the before measurement (probe `probe/result_before.txt`, 8 PASS / 4 FAIL) and the reading of the sites in specs/273-tar-case-root/fix-log.md

## Phase 2: Foundational (the rule)

- [X] T002 Write the header-only rule `SalArcPathRespell` (result codes OK / NOTFOUND / TOOLONG; accessor: count, name, sub-folder, equality; first match per folder; skips a leading and a trailing backslash; empty component = NOTFOUND; output without leading / trailing backslash; never writes past `outSize`) in src/common/salarcpathspell.h (UTF-8 BOM, SPDX header as salcasetwins.h)
- [X] T003 Add `TestArcPathRespell273` to src/saltests/saltests.cpp (fake tree: case-insensitive comparator re-spells `DOCS` -> `Docs`, `dOCS\SUB` -> `Docs\Sub`; case-sensitive comparator keeps `DOCS` among twins `Docs` / `DOCS` and refuses `docs`; first match among two CI-equal folders; missing / empty component; leading and trailing backslash; root ""; output one byte too small -> TOOLONG, exact size -> OK), call it from `main`, and list the header in src/vcxproj/saltests/saltests.vcxproj

## Phase 3: User Story 1 + 2 - copy from a folder opened in another case / the panel shows the archive's spelling (P1)

**Goal**: the path inside the archive is stored as the listing spells it, so TAR extracts and the panel shows `Docs`.
**Independent Test**: probe rows TAR-COPY, TAR-DEEP, 7Z-COPY, 7Z-DEEP.

- [X] T004 [US1] Add `BOOL CSalamanderDirectory::GetPathSpelling(const char* path, char* out, int outSize)` (the rule over `GetDirsCount` / `GetDirEx` / `GetSalamanderDir(int)` / `SalDirStrCmpEx`) in src/zip.h and src/zip.cpp
- [X] T005 [US1] In `CFilesWindow::ChangePathToArchive` (src/fileswn2.cpp), after the loop that shortens the path until `GetArchiveDirFiles() != NULL`, re-spell `ZIPPath` through `GetArchiveDir()->GetPathSpelling` into a `SAL_MAX_PATH_UTF8` buffer and `SetZIPPath` it when it succeeded and differs; on failure keep the typed path
- [X] T006 [US1] Build (`.\build.cmd`), run saltests, run the probe (`probe/result_after.txt`), record in specs/273-tar-case-root/fix-log.md

## Phase 4: User Story 3 - archives with case twins behave as before (P1)

**Independent Test**: probe rows TAR-TWINS, 7Z-TWINS; 252's probe.

- [X] T007 [US3] Run 252's probe specs/252-archive-case-sensitivity/probe/arc252_probe.ps1 on the new build (expected 16 / 0) and record it in specs/273-tar-case-root/fix-log.md
- [X] T008 [US3] Negative control: a build with the call of T005 disabled must fail TAR-COPY in specs/273-tar-case-root/probe/arccase273_probe.ps1 (record `probe/result_negctl.txt`), then restore the call and rebuild

## Phase 5: Polish

- [X] T009 Encoding guard `python tools/check_encoding.py --strict` -> TOTAL: 0; clang-format the changed sources (src/common/salarcpathspell.h, src/zip.cpp, src/zip.h, src/fileswn2.cpp, src/saltests/saltests.cpp)
- [X] T010 Update the probe's header comment and file references in specs/273-tar-case-root/probe/arccase273_probe.ps1 (feature 273 naming) and quickstart results in specs/273-tar-case-root/fix-log.md

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 / T008 -> T009 -> T010. US3 depends on US1's
change (it checks that the change leaves twins alone).

## Parallel opportunities

T003 (tests) and T004 (core accessor) touch different files and may be written in parallel once
T002 exists; T007 and T008 are sequential (one program instance per probe).

## Implementation strategy

MVP = Phases 1-3 (the item's defect). Phase 4 proves the unchanged behaviour; Phase 5 closes.
