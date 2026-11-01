# Tasks: ISO plug-in - a UDF folder stored in more than one extent is read whole

**Input**: Design documents from `specs/364-uniso-udf-folder-extents/` (plan.md, spec.md, research.md,
data-model.md, quickstart.md)
**Tests**: `saltests` checks for the rules (stop-rules §2.5) and the hidden-desktop probe are part of the feature.

## Phase 1: Setup

- [ ] T001 Record the measurement before (probe 20 / 8 at b1d9e31b) in specs/364-uniso-udf-folder-extents/fix-log.md and keep probe/result_before.txt, probe/iso364_probe.ps1, probe/img364.py, probe/mkimg364.sh in specs/364-uniso-udf-folder-extents/probe/

## Phase 2: Foundational (blocking)

- [ ] T002 Add `SAL_ISO_UDF_FOLDER_MAX_EXTENTS`, `SalIsoUdfFolderExtents` and `SalIsoUdfFolderSector` to src/common/salisoudfentry.h (data-model.md *Rules*; 64-bit, no wrap)
- [ ] T003 Add `TestIsoUdfFolderExtents_364` to src/saltests/saltests.cpp: genisoimage shapes (one extent = Information Length), the probe's shapes (2048 + 916, 2048 + type 3, 2048 + type 1, 38 / 40 of 88), length 0 terminator, a non-multiple non-last extent, 33 descriptors at the limit, embedded data, the sector mapping over a grid (each block of each extent, the boundary, past the last), and register it in the test list
- [ ] T004 Add `struct CUDFFolder` and change the declarations `MapICB(CAD, CICBTag*, CUDFFolder*)`, `ScanDir(const CUDFFolder&, ...)`, add `ReadFolderWindow` in src/plugins/uniso/udf.h

## Phase 3: User Story 1 - A fragmented folder is listed and unpacked whole (P1)

**Goal**: every recorded extent of a folder is walked; an identifier crossing an extent boundary is read whole.
**Independent test**: probe rows R-ROOTSPLIT, R-ROOTFRAG, R-SUBSPLIT, R-SUBFRAG, L-ROOTFRAG, L-SUBFRAG.

- [ ] T005 [US1] `CUDF::MapICB(CAD, CICBTag*, CUDFFolder*)` in src/plugins/uniso/udf.cpp: read up to 32 descriptors, apply `SalIsoUdfFolderExtents` with the entry's Information Length (`GET_QWORD(sector, 56)`), keep 362's walkable check on the first walked extent, fill the folder
- [ ] T006 [US1] `CUDF::ReadFolderWindow` and `CUDF::ScanDir(const CUDFFolder&, ...)` in src/plugins/uniso/udf.cpp: the two-sector window through `SalIsoUdfFolderSector` (one two-sector read inside an extent, two one-sector reads across a boundary), the walk end 64-bit, the sub-folder descent with a `CUDFFolder`

## Phase 4: User Story 2 - A folder that cannot be read whole keeps the image (P1)

**Goal**: a folder read short of its Information Length marks the listing incomplete.
**Independent test**: probe rows R-ROOTCONT, R-ROOTUNREC, R-ALEN38, R-ALEN40, L-ROOTCONT.

- [ ] T007 [US2] In `CUDF::ListDirectory` (root) and `CUDF::ScanDir` (sub-folder) in src/plugins/uniso/udf.cpp: `Image->ListingLeftOut.SetIncomplete()` when the mapped folder is not `Whole`, then walk what was read

## Phase 5: User Story 3 - Intact images are unchanged (P2)

**Independent test**: control rows L-BIG, C-BIG, C-UD; probes 330, 361, 362, 363.

- [ ] T008 [US3] Build (`.\build.cmd`), run saltests, run probe iso364_probe.ps1 on the hidden desktop -> specs/364-uniso-udf-folder-extents/probe/result_after.txt (every row PASS)
- [ ] T009 [US3] Run the regression probes 330, 361, 362, 363 -> specs/364-uniso-udf-folder-extents/probe/regress_<NNN>.txt with their recorded counts

## Phase 6: Polish

- [ ] T010 Encoding guard `python tools/check_encoding.py --strict` (TOTAL: 0), clang-format only the feature's hunks in src/plugins/uniso/udf.cpp, src/plugins/uniso/udf.h, src/common/salisoudfentry.h, src/saltests/saltests.cpp
- [ ] T011 Update specs/364-uniso-udf-folder-extents/fix-log.md (after measurement, checks, decisions)

## Dependencies

T001 -> T002 -> T003, T004 -> T005 -> T006 -> T007 -> T008 -> T009 -> T010 -> T011. US1 and US2 share `MapICB` /
`ScanDir` (one file), so they are sequential.

## Parallel opportunities

T003 (saltests) and T004 (udf.h) are different files after T002.

## Implementation strategy

MVP = US1 + US2 together (the same two functions); US3 is the regression check.
