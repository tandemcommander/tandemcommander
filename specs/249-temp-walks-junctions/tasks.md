# Tasks: the external unpacker's walk and the temporary-folder cleanups never go through a link

**Input**: `specs/249-temp-walks-junctions/` - spec.md, plan.md, research.md, quickstart.md
**Tests**: the GUI probe `probe/tempjunction249_probe.ps1` (measurement required by the item); no new `saltests` checks (the decision used is already checked).

## Phase 1: Setup

- [ ] T001 Record the before-measurement (7-Zip formats, probe rows SWEEP / PLAIN / UNPACK, the self-extractor's and `sfx7zip`'s reachability) in specs/249-temp-walks-junctions/fix-log.md and keep specs/249-temp-walks-junctions/probe/result_before.txt

## Phase 2: Foundational

- [ ] T002 Make the UNPACK row of specs/249-temp-walks-junctions/probe/tempjunction249_probe.ps1 also require the error message ("System error" naming `top`) and keep the PLAIN row requiring no message; add a DEEP row (archive `a\top\a.txt`, panel `t.arj\a\top`, the fake creates a real `a` and the junction `a\top`) for a link at the second level; the SWEEP row unchanged

## Phase 3: User Story 1 - unpacking from inside an archive never moves files from behind a link (P1) MVP

**Independent test**: probe row UNPACK FAIL -> PASS, PLAIN PASS.

- [ ] T003 [US1] In `PackUniversalUncompress` (src/pack1.cpp), in the archive-path walk: after the found entry is known to be a directory, build its full path (`srcDir` without the trailing `*` + the name, the existing length check first) and, when `FILE_ATTRIBUTE_REPARSE_POINT` is set and `DeleteAsDirLink` says link, compose `<path>: GetErrorText(ERROR_REPARSE_POINT_ENCOUNTERED)` on the heap (`CSalHeapString`), `RemoveTemporaryDir(tmpDirNameBuf)`, and return `(*PackErrorHandlerPtr)(parent, IDS_PACKERR_GENERAL, text)` - before any move
- [ ] T004 [US1] Check the callers' handling of `FALSE` (src/fileswn7.cpp unpack route: `RemoveEmptyDirs(newDirs)`, no selection change; src/salshlib.cpp drag & drop: nothing deleted) and record it in specs/249-temp-walks-junctions/fix-log.md

## Phase 4: User Story 2 - the start-up cleanup proven on the build (P2)

**Independent test**: probe row SWEEP PASS on the build after the change.

- [ ] T005 [US2] Run the probe after the change (quickstart step 2) into specs/249-temp-walks-junctions/probe/result_after.txt; record SWEEP / PLAIN / UNPACK in specs/249-temp-walks-junctions/fix-log.md

## Phase 5: User Story 3 - the self-extractor's cleanup source does not walk a link (P3)

**Independent test**: reading + compile-only syntax check.

- [ ] T006 [P] [US3] In `_RemoveTemporaryDir` (src/plugins/zip/selfextr/selfextr.cpp) remove a directory carrying `FILE_ATTRIBUTE_REPARSE_POINT` with `RemoveDirectory` instead of recursing (comment: feature 249, not built)
- [ ] T007 [US3] Compile-only check of src/plugins/zip/selfextr/selfextr.cpp (`cl /Zs` with its folder on the include path) and record the result in specs/249-temp-walks-junctions/fix-log.md

## Phase 6: Polish

- [ ] T008 `python tools/check_encoding.py --strict` (TOTAL: 0), `.\build.cmd` (BUILD SUCCEEDED), `saltests.exe` (0 failed); results in specs/249-temp-walks-junctions/fix-log.md
- [ ] T009 Negative control: confirm the UNPACK row fails on the build before the change (result_before.txt) and passes after; note it in specs/249-temp-walks-junctions/fix-log.md

## Dependencies

T001 -> T002 -> T003 -> T004 -> T008 -> T005 -> T009; T006 -> T007 independent of US1 / US2.

## Parallel opportunities

T006 (selfextr.cpp) can be done alongside T003 (pack1.cpp) - different files.

## Implementation strategy

MVP = US1 (the only reachable defect). US2 is a measurement on the same probe run; US3 a contained source change.
