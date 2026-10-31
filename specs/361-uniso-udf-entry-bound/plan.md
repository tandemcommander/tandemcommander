# Implementation Plan: ISO plug-in - a damaged UDF file entry no longer hangs the listing or reads past its sector

**Branch**: `361-uniso-udf-entry-bound` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/361-uniso-udf-entry-bound/spec.md`

## Summary

The general file-entry reader `CUDF::ReadFileEntry(Uint8* data, bool bEFE, Uint16 part, CICBTag* icbTag, CAD*
ad, int maxAds)` (`src/plugins/uniso/udf.cpp`) takes the descriptor area `[176 (+40) + L_EA, + L_AD)` of the
2048-byte sector in 32-bit arithmetic without a bound and walks it with a `switch` on the ICB descriptor type
that has no case for the reserved types 4 - 7 (no progress - a hang). The fix:

1. A pure rule in a new header `src/common/salisoudfentry.h`, built on feature 360's rules of
   `salisoudfvat.h` (`SalIsoUdfVatDescArea`, `SalIsoUdfVatDescSize`):
   `SalIsoUdfEntryDescs(sectorLen, extended, lEA, lAD, type, first, end, size)` - the area inside the sector
   and the descriptor size (8 / 16 / 20, 0 = embedded data), or false (refused) for an area outside the
   sector, a reserved type, or an area that is not a whole number of descriptors.
2. `ReadFileEntry` asks the rule first and returns a new value `UDF_FE_REFUSED` (-2) when it refuses; the walk
   advances by the rule's size, so it always ends inside the area. Well-formed entries give the same result as
   before (descriptors, count, terminating entry, embedded offset / length).
3. The callers map the refusal to their existing "unreadable entry" paths:
   - `MapICB(CAD, CICBTag*, CAD*)` returns 0 (root: "Bad root ICB", listing incomplete; sub-folder: listed
     empty, listing incomplete - feature 330);
   - `UnpackFile`: `IDS_UDF_ICB_AND_FILESIZE_MISMATCH` naming the file, `UNPACK_ERROR`;
   - `ReadPartitionMap` (metadata partition): `nMetadataICBs = 0`.
4. `saltests`: `TestIsoUdfEntry_361` - measured cases and a grid model of the reader's walk (ends, stays in the
   sector, well-formed shapes taken, reserved types refused).
5. Probe `probe/iso361_probe.ps1` + `probe/img361.py` (mkudffs mk_cdr by 356's `mkudf356.sh`; genisoimage `-udf`
   hybrid by 330's `mkimg330.sh`); regressions: probes 330 and 360.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; `src/common/salisoudfvat.h` (features 358 - 360)
**Storage**: N/A
**Testing**: `saltests` (`TestIsoUdfEntry_361`); hidden-desktop probe `probe/iso361_probe.ps1` (images in WSL
Ubuntu, changed by `probe/img361.py`); regression: probes 330 (`iso330_probe.ps1`) and 360 (`iso360_probe.ps1`)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`uniso.spl`)
**Performance Goals**: unchanged (a few comparisons per entry)
**Constraints**: no UI string, no dialog, no plug-in ABI change; rules header-only (plug-ins compile no `.cpp`
from `src/common`)
**Scale/Scope**: one reader, three callers, one new header, one test group

## Constitution Check

- I. Build reproducibility: no new dependency, no project file change (a header only). PASS
- II. Backward compatibility: well-formed entries read exactly as before; only entries that hung the reader or
  read past its sector (or are invalid by ECMA-167: reserved type, cut descriptor) are refused, through each
  caller's existing unreadable-entry path. PASS
- III. Incremental modernization: the rule pure in `src/common/` with tests, a minimal plug-in edit. PASS
- IV. Windows commitment: unchanged. PASS
- V. Plugin architecture: no `spl_*.h` change, no `LAST_VERSION_OF_SALAMANDER` change. PASS
- VI. UI consistency: existing messages only. PASS

Re-check after design: PASS (unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/361-uniso-udf-entry-bound/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ iso361_probe.ps1, img361.py, result_*.txt
```

### Source Code (repository root)

```text
src/common/salisoudfentry.h       # new: SalIsoUdfEntryDescs (on 360's DescArea / DescSize)
src/saltests/saltests.cpp         # + TestIsoUdfEntry_361
src/plugins/uniso/udf.cpp         # ReadFileEntry through the rule; MapICB, UnpackFile, ReadPartitionMap
src/plugins/uniso/udf.h           # UDF_FE_REFUSED, the reader's comment
```

**Structure Decision**: the existing plug-in and common-header layout (as features 356 - 360).

## Complexity Tracking

None.
