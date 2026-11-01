# Implementation Plan: ISO plug-in - a UDF folder stored in more than one extent is read whole

**Branch**: `364-uniso-udf-folder-extents` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/364-uniso-udf-folder-extents/spec.md`

## Summary

The UDF folder reader `CUDF::MapICB(CAD, CICBTag*, CAD*)` (`src/plugins/uniso/udf.cpp`) reads a folder's file
entry with `ReadFileEntry(..., file, 1)` - room for one allocation descriptor - and `CUDF::ScanDir(CAD dirICB, ...)`
walks `dirICB.Length` bytes from `LogSector(dirICB.Location)` with a two-sector window that steps to the
physically next sector. A folder in several extents is read up to its first extent; a folder whose extents are
shorter than its Information Length is read short; neither is marked. Measured at b1d9e31b
(`probe/result_before.txt`): 20 PASS / 8 FAIL, every damaged or fragmented image deleted after a partial unpack.

The fix:

1. Pure rules in `src/common/salisoudfentry.h` (features 361 - 363's header of the same reader):
   - `SalIsoUdfFolderExtents(types, lens, count, blockLen, infoLen, walk, walkLen)` - which descriptors are walked
     (the leading recorded extents, type 0, length > 0; the walk stops after an extent that is not a whole number
     of blocks), their byte sum, and whether the folder is read whole (`walkLen >= infoLen`).
   - `SalIsoUdfFolderSector(lens, walk, blockLen, sector, extent, block)` - which walked extent holds the folder's
     block `sector` (window coordinates) and the block within it; past the last extent: the last one, block
     counted on (the old contiguous walk).
2. `CUDF::MapICB(CAD, CICBTag*, CUDFFolder*)` reads up to `UDF_FOLDER_MAX_EXTENTS` = 32 descriptors (as
   `UnpackFile`'s `icbs[32]`), applies the rule with the entry's Information Length (`GET_QWORD(sector, 56)`, in
   both entry kinds), keeps 362's walkable check on the first walked extent, and returns the folder (extents,
   count, walk length, embedded offset, `Whole`).
3. `CUDF::ScanDir(const CUDFFolder&, ...)` fills its two-sector window through a new
   `CUDF::ReadFolderWindow(folder, k, buf, lbNum)`: both sectors in one extent (or past the last) - one
   `ReadBlockPhys(phys, 2)` as before; the second sector in the next extent - two one-sector reads. The walk end is
   64-bit.
4. Both callers (`ListDirectory` for the root, `ScanDir` for a sub-folder) mark `Image->ListingLeftOut` incomplete
   when the folder is not `Whole`, then walk what was read (feature 330's mark - a whole unpack fails, the image is
   kept). No UI string.
5. `saltests`: `TestIsoUdfFolderExtents_364` - the measured shapes, every stop reason, the 362 cases, wrap-free sums,
   and the sector mapping over a grid.
6. Probe `probe/iso364_probe.ps1` (before 20 / 8); regressions: probes 330, 361, 362, 363.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; `src/common/salisoudfentry.h` (features 361 - 363)
**Storage**: N/A
**Testing**: `saltests`; hidden-desktop probe `probe/iso364_probe.ps1` (seeds in WSL Ubuntu by `probe/mkimg364.sh`
and 330's `mkimg330.sh`, changed by `probe/img364.py`); regression probes 330, 361, 362, 363
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`uniso.spl`)
**Performance Goals**: unchanged for one-extent folders (the same reads); one extra read per extent boundary
**Constraints**: no UI string, no dialog, no plug-in ABI change; the rules header-only
**Scale/Scope**: `MapICB`, `ScanDir`, a new window reader, two callers; two rules, one test group

## Constitution Check

- I. Build reproducibility: no new dependency, no project file change. PASS
- II. Backward compatibility: a folder whose one recorded extent covers its Information Length is walked exactly as
  before (same reads, same length). Changed: a folder in several extents is read whole; a folder read short is
  marked (the image kept); a folder whose first descriptor is not a recorded extent takes 362's existing refusal.
  PASS
- III. Incremental modernization: the rules pure in `src/common/` with tests. PASS
- IV. Windows commitment: unchanged. PASS
- V. Plugin architecture: no `spl_*.h` change; `MapICB` / `ScanDir` are private members of the plug-in. PASS
- VI. UI consistency: no new message. PASS

Re-check after design: PASS (unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/364-uniso-udf-folder-extents/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ iso364_probe.ps1, img364.py, mkimg364.sh, result_*.txt
```

No `contracts/`: nothing outside the plug-in changes (private members, a header-only rule).

### Source Code (repository root)

```text
src/common/salisoudfentry.h       # + SalIsoUdfFolderExtents, SalIsoUdfFolderSector, SAL_ISO_UDF_FOLDER_MAX_EXTENTS
src/saltests/saltests.cpp         # + TestIsoUdfFolderExtents_364
src/plugins/uniso/udf.h           # + CUDFFolder; MapICB(CAD, CICBTag*, CUDFFolder*); ScanDir(const CUDFFolder&, ...); ReadFolderWindow
src/plugins/uniso/udf.cpp         # MapICB through the rule; ScanDir over the extents; callers mark ListingLeftOut
```

**Structure Decision**: the existing plug-in and common-header layout (as features 361 - 363).

## Complexity Tracking

None.
