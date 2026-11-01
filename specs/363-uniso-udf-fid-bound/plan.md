# Implementation Plan: ISO plug-in - a UDF file identifier that does not fit the folder buffer is refused

**Branch**: `363-uniso-udf-fid-bound` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/363-uniso-udf-fid-bound/spec.md`

## Summary

The UDF folder walk `CUDF::ScanDir` (`src/plugins/uniso/udf.cpp`) holds two sectors of the folder in
`Uint8 directory[2 * SECTOR_SIZE]` and reads each file identifier at `directory + p` (`p <= SECTOR_SIZE` - the
walk steps one sector forward when `p` passes one sector) through `CUDF::ReadFileIdentifier`, which takes L_FI
(8 bits) and L_IU (16 bits) from the identifier, decodes the name at `38 + L_IU`, L_FI bytes long, and returns the
padded length `4 * ((38 + L_FI + L_IU + 3) / 4)` - without comparing either with the buffer. Measured at 443ee778
(`probe/result_before.txt`): the name read past the buffer decodes to an empty name listed as `_`, the walk goes on,
the listing is not marked, a whole unpack with "Delete archive after unpacking" deletes the image (8 FAIL).

The fix:

1. A pure rule in `src/common/salisoudfentry.h` (features 361 / 362's header of the same reader):
   `SalIsoUdfFidLength(held, pos, lFI, lIU, len)` - true with `len` = the padded identifier length when the
   identifier at `pos` of a buffer of `held` bytes lies whole in it (`pos + len <= held`, computed in 64 bits
   without wrap; the 38-byte head included); false otherwise.
2. `CUDF::ReadFileIdentifier` takes the bytes held from `sector` (`held`) and returns 0 - nothing read past the head,
   no name decoded - when the rule refuses; its only caller `ScanDir` passes `sizeof(directory) - p` and treats 0
   as the existing invalid-tag path: `Error(IDS_UDF_INVALID_TAG_ID); return ERR_CONTINUE;` - the walk ends, the
   result reaches `ListDirectory`, which marks `ListingLeftOut` incomplete (feature 330).
3. `saltests`: `TestIsoUdfFid_363` - values at the bound, the measured shapes (genisoimage's 40/44-byte
   identifiers), the probe's damaged identifiers, wrap values, and a model of the walk over a grid of positions,
   L_FI and L_IU: every accepted identifier lies in the buffer, the next position after the one-sector step is at
   most one sector in, every identifier of at most one block from a position at most one sector in is accepted with
   the old length.
4. Probe `probe/iso363_probe.ps1` + `probe/img363.py` (before: 12 / 8); regressions: probes 330, 361, 362.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; `src/common/salisoudfentry.h` (features 361, 362)
**Storage**: N/A
**Testing**: `saltests`; hidden-desktop probe `probe/iso363_probe.ps1` (seed in WSL Ubuntu by 330's
`mkimg330.sh`); regression probes 330 (`iso330_probe.ps1`), 361 (`iso361_probe.ps1`), 362 (`iso362_probe.ps1`)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`uniso.spl`)
**Performance Goals**: unchanged (one comparison per identifier)
**Constraints**: no UI string, no dialog, no plug-in ABI change; the rule header-only
**Scale/Scope**: one function and its one caller in the plug-in, one rule, one test group

## Constitution Check

- I. Build reproducibility: no new dependency, no project file change. PASS
- II. Backward compatibility: every identifier of a valid image (at most one block, read at most one sector into
  the two-sector buffer) is read as before - same name, same length. Only an identifier past the buffer, damaged,
  takes the existing invalid-tag path. PASS
- III. Incremental modernization: the rule pure in `src/common/` with tests. PASS
- IV. Windows commitment: unchanged. PASS
- V. Plugin architecture: no `spl_*.h` change; `ReadFileIdentifier` is a private member of the plug-in. PASS
- VI. UI consistency: existing message only. PASS

Re-check after design: PASS (unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/363-uniso-udf-fid-bound/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ iso363_probe.ps1, img363.py, result_*.txt
```

### Source Code (repository root)

```text
src/common/salisoudfentry.h       # + SalIsoUdfFidLength
src/saltests/saltests.cpp         # + TestIsoUdfFid_363
src/plugins/uniso/udf.h           # ReadFileIdentifier(sector, held, ...)
src/plugins/uniso/udf.cpp         # ReadFileIdentifier through the rule; ScanDir: 0 -> invalid-tag path
```

**Structure Decision**: the existing plug-in and common-header layout (as features 361 / 362).

## Complexity Tracking

None.
