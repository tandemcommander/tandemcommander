# Implementation Plan: A UDF volume whose partition maps do not fit its descriptor does not open

**Branch**: `378-uniso-udf-partition-maps` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/378-uniso-udf-partition-maps/spec.md`

## Summary

`CUDF::ReadLVD` (`src/plugins/uniso/udf.cpp`) walks the partition map table of the logical volume descriptor
by the declared count and each map's own length byte, unbounded. A new header-only pure rule
`src/common/salisoudfmaps.h` (`SalIsoUdfLvdMapsFit`) decides from the descriptor's bytes whether every
declared map lies inside [440, min(held, 440 + table length)) with a length that covers its header and the
bytes the reader takes from its type. `ReadLVD` returns `BOOL` and checks the rule before any map is
recorded; `CUDF::Open` refuses the volume (`IDS_ERROR_LISTING_IMAGE`, the descriptor's sector, `quiet`
honoured) - the existing "volume does not open" path (UDF-only track not opened; a bridge's UDF part missing,
listing marked by `CUDFISO::Open`'s anchor check, feature 330).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; ISO plug-in `uniso` (`udf.cpp`, `udf.h`), header-only rule under `src/common/`
**Storage**: N/A
**Testing**: `saltests` (new `TestIsoUdfMaps_378`, with a grid walk), GUI probe
`specs/378-uniso-udf-partition-maps/probe/iso378_probe.ps1` on the hidden desktop, regression probes of 356,
358, 361, 377
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in
**Performance Goals**: the walk is bounded by the sector (at most 804 steps); no allocation before the check
**Constraints**: no UI string, no plug-in ABI change; header-only (uniso cannot link `src/common` .cpp)
**Scale/Scope**: one new header (~60 lines), ~15 changed lines in `udf.cpp` / `udf.h`, saltests checks

## Constitution Check

- I Build reproducibility: a header in `src/common/`, no project change (saltests includes by path) - PASS.
- II Backward compatibility: every well-formed descriptor (maps inside the table and the sector) opens as
  before; only descriptors that the old code read past or looped on are refused - PASS.
- III Incremental modernization: minimal local fix plus a tested pure rule - PASS.
- IV Windows commitment: N/A - PASS.
- V Plug-in architecture preservation: plug-in internal only; no `spl_*.h` change - PASS.
- VI UI consistency: the existing error text is reused - PASS.

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/378-uniso-udf-partition-maps/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/            # iso378_probe.ps1, img378.py, results
└── tasks.md
```

No `contracts/`: the change is internal to the plug-in (no interface exposed).

### Source Code (repository root)

```text
src/common/salisoudfmaps.h        # new: SalIsoUdfPartitionMapMinLen, SalIsoUdfLvdMapsFit
src/plugins/uniso/udf.cpp         # ReadLVD returns BOOL, checks the rule; Open refuses the volume
src/plugins/uniso/udf.h           # ReadLVD declaration
src/saltests/saltests.cpp         # TestIsoUdfMaps_378
```

**Structure Decision**: existing plug-in and shared-rule layout (as 358 / 360 / 361).

## Complexity Tracking

None.
