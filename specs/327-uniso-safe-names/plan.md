# Implementation Plan: Every name the ISO plug-in lists is made safe before extraction

**Branch**: `327-uniso-safe-names` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/327-uniso-safe-names/spec.md`

## Summary

The ISO plug-in lists names from ISO 9660, Joliet, UDF, HFS+ and Xbox directories, and volume label
folders of hybrids, as the image stores them; only Rock Ridge names are made safe (feature 326).
One pure rule - feature 087's per-name form, already implemented for Rock Ridge as
`SalSuspCleanRockRidgeName` - moves to `src/common/salarcname.h` as `SalArcCleanItemName` (never
fails for a terminated name: when a device name's `_` prefix does not fit, its first letter becomes
`_`); feature 326's function becomes a thin wrapper with its exact behaviour. The plug-in calls the
new rule at every site that lists a name read from the image and once more where each reader joins
the file name to the target path.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new; plug-in `uniso` (header-only rules from `src/common`, feature rule
"shared rules for plug-ins are header-only")  
**Storage**: N/A  
**Testing**: `saltests` (new `TestArcItemName327`), hidden-desktop probe `probe/iso327_probe.ps1`;
regression probes `specs/326-uniso-rrip-without-rr/probe/iso326_probe.ps1`,
`specs/322-uniso-hfs-btree-joliet/probe/iso322_probe.ps1`  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (archiver)  
**Performance Goals**: one linear pass over each name (bytes), no allocation at the listing sites  
**Constraints**: plug-in ABI unchanged; no UI string changes (no `.slt` refresh); names stay UTF-8
(bytes >= 0x80 untouched); never a cut name  
**Scale/Scope**: 6 listing sites, 5 extraction joins, 1 header, 1 test function

## Constitution Check

- I Build reproducibility: no new dependency, no build change - PASS.
- II Backward compatibility: a name already safe is byte-identical (FR-004); plug-in ABI and
  registry unchanged - PASS.
- III Incremental modernization: a pure header rule with unit checks, existing call structure kept
  - PASS.
- IV Windows commitment: makes names valid for Windows - PASS.
- V Plug-in architecture preservation: change inside the plug-in and a header-only `src/common`
  rule - PASS.
- VI UI consistency: no UI change - PASS.

Post-design re-check: unchanged - PASS.

## Project Structure

### Documentation (this feature)

```text
specs/327-uniso-safe-names/
├── plan.md, research.md, data-model.md, quickstart.md, fix-log.md
├── contracts/item-name.md      # the rule SalArcCleanItemName
├── checklists/requirements.md
├── probe/                      # iso327_probe.ps1, img327.py, mkimg327.sh, result_*.txt
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salarcname.h          # + SalArcNameDetail::CleanOneName, SalArcCleanItemName (N3)
src/common/salsusp.h             # SalSuspCleanRockRidgeName -> the shared detail (same behaviour)
src/saltests/saltests.cpp        # + TestArcItemName327
src/plugins/uniso/uniso.h/.cpp   # + MakeSafeName, AppendSafeName (the plug-in's two entry points)
src/plugins/uniso/iso9660.cpp    # MakeListedName (all names), Joliet folders, UnpackFile
src/plugins/uniso/udf.cpp        # ScanDir (after ReadFileIdentifier), UnpackFile
src/plugins/uniso/hfs.cpp        # ListDirectory (after FixIllegalFSChars), UnpackFile
src/plugins/uniso/xdvdfs.cpp     # ScanDir (after EnsureU8Name), UnpackFile
src/plugins/uniso/rawfs.cpp      # UnpackFile
src/plugins/uniso/udfiso.cpp     # ISO / UDF / HFS volume label folders
```

**Structure Decision**: the existing plug-in and `src/common` layout; no new project.

## Complexity Tracking

None.
