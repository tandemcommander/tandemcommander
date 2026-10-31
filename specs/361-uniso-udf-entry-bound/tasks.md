# Tasks: ISO plug-in - a damaged UDF file entry no longer hangs the listing or reads past its sector

**Input**: Design documents from `specs/361-uniso-udf-entry-bound/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: requested by the item (`saltests` checks, probe rows).

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [X] T001 Start `specs/361-uniso-udf-entry-bound/fix-log.md` with the measurement at 73bb1246 (review 1 of 360's hang, the callers of research R1)
- [X] T002 Write the image builder `specs/361-uniso-udf-entry-bound/probe/img361.py` (kinds `rootadt5` on mk_cdr.img; `foldadt5`, `foldleabig`, `fileadt5` on genisoimage ud.iso; each refuses an unexpected layout)
- [X] T003 Write the probe `specs/361-uniso-udf-entry-bound/probe/iso361_probe.ps1` (from `specs/360-uniso-udf-vat-bound/probe/iso360_probe.ps1` and `specs/330-iso-unreadable-folder/probe/iso330_probe.ps1`: seeds by `mkudf356.sh` and `mkimg330.sh` in WSL; list rows L-ROOT5, L-FOLD5, L-FOLDLEA; unpack rows R-ROOT5, R-FOLD5, R-FOLDLEA, R-FILE5; controls C-MKCDR, C-UD, L-UD; registry backed up and restored)
- [X] T004 Run the probe on the build before the fix (`probe/result_before.txt`) and record the rows in `fix-log.md`

## Phase 2: Foundational

- [X] T005 Create `src/common/salisoudfentry.h` with `SalIsoUdfEntryDescs` on 360's `SalIsoUdfVatDescArea` / `SalIsoUdfVatDescSize` (UTF-8 BOM, SPDX header)
- [X] T006 Add `TestIsoUdfEntry_361` to `src/saltests/saltests.cpp` (measured cases, a grid model of the reader's walk: ends, stays in the sector, well-formed shapes taken, reserved types refused) and call it from the test list

## Phase 3: User Story 1 - a damaged folder entry does not hang the program (P1)

**Independent test**: rows L-ROOT5, R-ROOT5, L-FOLD5, R-FOLD5, L-FOLDLEA, R-FOLDLEA.

- [X] T007 [US1] `CUDF::ReadFileEntry(Uint8*, bool, Uint16, CICBTag*, CAD*, int)` in `src/plugins/uniso/udf.cpp`: ask `SalIsoUdfEntryDescs` first, return `UDF_FE_REFUSED`; walk by the rule's size; well-formed results unchanged
- [X] T008 [US1] `UDF_FE_REFUSED` and the reader's comment in `src/plugins/uniso/udf.h`
- [X] T009 [US1] `CUDF::MapICB(CAD, CICBTag*, CAD*)` returns 0 on a refused entry in `src/plugins/uniso/udf.cpp`
- [X] T010 [US1] `CUDF::ReadPartitionMap` stores 0 metadata extents on a refused entry in `src/plugins/uniso/udf.cpp`

## Phase 4: User Story 2 - a damaged file entry does not hang the unpack (P1)

**Independent test**: row R-FILE5.

- [X] T011 [US2] `CUDF::UnpackFile` shows `IDS_UDF_ICB_AND_FILESIZE_MISMATCH` naming the file and returns `UNPACK_ERROR` on a refused entry in `src/plugins/uniso/udf.cpp`

## Phase 5: User Story 3 - well-formed images as before (P2)

**Independent test**: controls C-MKCDR, C-UD, L-UD; probes 330 and 360.

- [X] T012 [US3] Build (`build.cmd`), `saltests`, run `iso361_probe.ps1` after the fix (`probe/result_after.txt`)
- [X] T013 [US3] Regressions: `specs/330-iso-unreadable-folder/probe/iso330_probe.ps1` and `specs/360-uniso-udf-vat-bound/probe/iso360_probe.ps1` on the same build (`probe/regress_330.txt`, `probe/regress_360.txt`)

## Phase 6: Polish

- [X] T014 Negative controls: mutate the rule (drop the reserved-type refusal; drop the sector bound) → `saltests` fails; restore with `git checkout HEAD --` and rebuild
- [X] T015 `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`; clang-format the changed sources
- [X] T016 Complete `fix-log.md` (before / after, commands, results)

## Dependencies

T001 → T002 → T003 → T004 (before any source change) → T005 → T006 → T007 - T011 → T012 → T013 → T014 → T015 → T016.
US1 and US2 share T007 / T008; US3 verifies both.

## Parallel opportunities

T005 and T006 touch different files; T009 - T011 are one file (sequential).

## Implementation strategy

MVP = US1 (the measured hang). US2 adds the unpack caller; US3 proves no regression.
