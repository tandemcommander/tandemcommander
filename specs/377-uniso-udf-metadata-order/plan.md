# Implementation Plan: A UDF 2.50 image whose volume descriptor precedes its partition descriptor lists and unpacks

**Branch**: `377-uniso-udf-metadata-order` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/377-uniso-udf-metadata-order/spec.md`

## Summary

`CUDF::Open` (`src/plugins/uniso/udf.cpp`) walks the main volume descriptor sequence in order; on the logical
volume descriptor `ReadLVD` → `ReadPartitionMap` immediately reads the metadata partition's file entry with
`ReadBlockLog(location)` = `PD.Start + location`. IMAPI2FS UDF 2.50 writes the LVD (sector 34) before the PD
(sector 35), so `PD` is not read yet (uninitialised) and the metadata file entry is not found: no metadata
extents, the File Set Descriptor in the metadata partition cannot be translated, the listing fails.

Fix (the item's *Approach*, second option): `ReadPartitionMap` only records the metadata file's location in
the map; `ReadSupportingTables` (called after the whole sequence is read, already a per-map switch with an
empty `mapMetadata` case) reads and parses the metadata file entry with exactly the code that ran before.
For a PD-first volume the same sector is read with the same `PD.Start` - same result.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; ISO plug-in `uniso` (`src/plugins/uniso/udf.cpp`, `udf.h`)
**Storage**: N/A
**Testing**: GUI probe on the hidden desktop (`specs/377-uniso-udf-metadata-order/probe/iso377_probe.ps1`),
regression probes of 356, 358, 361; `saltests` run (no new pure rule, see research R3)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in
**Performance Goals**: unchanged (one sector read moved, not added)
**Constraints**: no UI string, no plug-in ABI change; plug-in internal structures only
**Scale/Scope**: about 30 changed lines in one file pair

## Constitution Check

- I Build reproducibility: no new dependency, no build change - PASS.
- II Backward compatibility: PD-first volumes read the same sector; no setting or format change - PASS.
- III Incremental modernization: a minimal local fix - PASS.
- IV Windows commitment: N/A - PASS.
- V Plug-in architecture preservation: `CPartitionMap` is private to the plug-in; no `spl_*.h` change - PASS.
- VI UI consistency: no UI change, the existing error box is kept - PASS.

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/377-uniso-udf-metadata-order/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/            # iso377_probe.ps1, img377.py, results
└── tasks.md
```

No `contracts/`: the change is internal to the plug-in (no interface exposed).

### Source Code (repository root)

```text
src/plugins/uniso/
├── udf.h      # CPartitionMap gains the metadata file location
└── udf.cpp    # ReadPartitionMap records it; ReadSupportingTables reads the metadata file entry
```

**Structure Decision**: one plug-in, two files.

## Complexity Tracking

None.
