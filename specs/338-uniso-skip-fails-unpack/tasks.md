# Tasks: ISO plug-in - a whole unpack with a skipped file keeps the image

**Input**: `specs/338-uniso-skip-fails-unpack/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: saltests checks for the pure rules (project rule §2.5) and the hidden-desktop probe `iso338_probe`.

## Phase 1: Setup

- [X] T001 Keep the measurement record in specs/338-uniso-skip-fails-unpack/fix-log.md (before: probe/result_before.txt, PASS 10 / FAIL 6)

## Phase 2: Foundational (blocking)

- [X] T002 Create the header-only rules in src/common/salisounpack.h: `SAL_ISO_UNPACK_*` codes, `SalIsoFileUnpackResult`, `SalIsoUnpackItemWhole`, `CSalIsoWholeUnpackTally`, `SalIsoWholeUnpackSucceeded`, `CSalIsoWrittenFiles` (identity keys from src/common/salsamefile.h in hash sets, `Lost` fail-closed)
- [X] T003 Add `TestIsoWholeUnpack_338` to src/saltests/saltests.cpp (include salisounpack.h; per-file result table, whole decision, written-set: 128-bit / 64-bit keys, unusable ids, not read, Lost, different volumes) and call it from the runner; negative control: a mutant of `SalIsoFileUnpackResult` / `SalIsoWholeUnpackSucceeded` fails checks (recorded)
- [X] T004 Assert `UNPACK_*` == `SAL_ISO_UNPACK_*` in src/plugins/uniso/isoimage.h (include ../../common/salisounpack.h)

## Phase 3: User Story 1 - a skipped file keeps the image (P1)

**Independent test**: probe rows R-SKIP, R-SKIPALL, C-SKIP, O-SKIP keep the image; OK / O-YES delete it.

- [X] T005 [P] [US1] End `CISO9660::UnpackFile` with `ret = SalIsoFileUnpackResult(ret, bFileComplete)` in src/plugins/uniso/iso9660.cpp
- [X] T006 [P] [US1] The same in `CRawFS::UnpackFile`, src/plugins/uniso/rawfs.cpp
- [X] T007 [P] [US1] The same in `CUDF::UnpackFile`, src/plugins/uniso/udf.cpp
- [X] T008 [P] [US1] The same in `CXDVDFS::UnpackFile`, src/plugins/uniso/xdvdfs.cpp
- [X] T009 [P] [US1] In `CHFS::UnpackFile` (src/plugins/uniso/hfs.cpp): extents that end before the size make the file incomplete; a listed record that is not a file record returns ERROR with the existing damaged-B-tree box; the same end rule
- [X] T010 [US1] `CISOImage::ExtractAllItems` (src/plugins/uniso/isoimage.cpp/.h) takes a `CSalIsoWholeUnpackTally&`: a file result other than OK sets `NotWhole`, Cancel sets `Cancelled` and returns as before
- [X] T011 [US1] `UnpackWholeArchive` (src/plugins/uniso/uniso.cpp) returns `SalIsoWholeUnpackSucceeded(tally, ListingLeftOut)`

## Phase 4: User Story 2 - a folder that cannot be created keeps the image (P2)

**Independent test**: probe row D-SKIP.

- [X] T012 [US2] In `ExtractAllItems` a FALSE `UnpackDir` sets `NotWhole` (src/plugins/uniso/isoimage.cpp)

## Phase 5: User Story 3 - two listed files of one name keep the image (P3)

**Independent test**: probe rows TWINS (kept) and O-YES (deleted).

- [X] T013 [US3] In `ExtractAllItems` (src/plugins/uniso/isoimage.cpp): build the file's target name (`AppendSafeName`), when it exists read its identity and ask `CSalIsoWrittenFiles::WrittenBefore`; after an OK result set `WroteOverOwn` if it was, and `Note` the written file's identity; the set lives for the whole unpack (passed in from `UnpackWholeArchive`)

## Phase 6: Polish

- [X] T014 Build (`.\build.cmd`), encoding guard (`python tools/check_encoding.py --strict`), saltests; FR-005: `git diff main -- '*.rc' '*.rc2' '*.rh'` is empty (no UI string); record in fix-log.md
- [X] T015 Probe after: specs/338-uniso-skip-fails-unpack/probe/iso338_probe.ps1 -> 8 RUN rows PASS; negative control (tally ignored) fails the rows again; record
- [X] T016 Regressions: probes of 330 (iso330_probe.ps1) and 337 (iso337_probe.ps1) keep their results; record
- [X] T017 clang-format of the changed lines only (`--lines`), never whole files (saltests.cpp trap of 334-336)
- [X] T018 FR-007: read `UnpackArchive` and `UnpackOneFile` (src/plugins/uniso/uniso.cpp) against the reader changes - their results stay (Copy keeps only Cancel; one file was already `== UNPACK_OK` with a fresh silent mask); record in fix-log.md

## Dependencies

T002 -> T003, T004 -> T005..T009 (parallel) -> T010 -> T011, T012, T013 -> T014 -> T015, T016. MVP: Phases 1-3.
