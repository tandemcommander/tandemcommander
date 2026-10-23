# Implementation Plan: The ISO plug-in checks an HFS+ catalog against the image; Joliet file names kept whole

**Branch**: `322-uniso-hfs-btree-joliet` | **Date**: 2026-10-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/322-uniso-hfs-btree-joliet/spec.md`

## Summary

The HFS+ catalog walk of the ISO plug-in (`src/plugins/uniso/hfs.cpp`, `CHFS::BTree::BTree`) and
its record consumers (`GetRootName`, `ListDirectory`, `UnpackFile`) use node numbers, links, node
size, record counts, record offsets and key lengths from the image unchecked. The walk moves into a
header-only pure rule `src/common/salhfscatalog.h` that validates every node and record against the
loaded buffer, ends on a cycle, and returns per record the bytes it may use; the consumers check
key, name and folder / file data against that. Joliet file names (`iso9660.cpp`
`ExtractExtFileName`) are copied whole after their UTF-8 conversion. `saltests` checks the rule
with hand-built catalogs and a deterministic mutation fuzz; a hidden-desktop probe opens targeted
and randomly mutated HFS+, ISO 9660, Joliet and Rock Ridge images.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new; the plug-in includes `../../common/salhfscatalog.h`  
**Storage**: N/A  
**Testing**: `saltests` (pure rule + fuzz); PowerShell probe on the hidden desktop
(`tools/run_on_hidden_desktop.ps1`), images from IMAPI2 (Joliet) and xorriso 1.5.6 in WSL
(ISO 9660 + Joliet + Rock Ridge + HFS+), mutated by a Python script in the probe folder  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (`uniso.spl`)  
**Performance Goals**: the walk stays linear in the catalog size (one bit per node for the cycle check)  
**Constraints**: plug-in ABI unchanged; header-only rule (the plug-in cannot compile a `.cpp` of
`src/common`); valid images list exactly as before  
**Scale/Scope**: two source files of one plug-in, one new header, one new UI string

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency; xorriso is test tooling only, outside the build |
| II. Backward compatibility | valid images list and extract as before (probe rows of 223 + new valid controls); only out-of-bounds structures are refused |
| III. Incremental modernization | a local fix in place; the pure rule follows the `src/common/sal*.h` pattern |
| IV. Windows commitment | unchanged |
| V. Plug-in architecture | no interface change; `LAST_VERSION_OF_SALAMANDER` untouched |
| VI. UI consistency | one new error message in the plug-in's existing style, translated by the `.slt` refresh (§2.13) |

Gate: PASS (no violations). Re-checked after design: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/322-uniso-hfs-btree-joliet/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/salhfscatalog.md
├── fix-log.md
├── probe/   iso322_probe.ps1, mkimg322.sh (xorriso in WSL), mut322.py (mutations), result_*.txt
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salhfscatalog.h          # new: the catalog walk and the record view (pure)
src/plugins/uniso/hfs.cpp, hfs.h    # BTree uses the rule; consumers check records
src/plugins/uniso/iso9660.cpp       # Joliet names copied whole
src/plugins/uniso/uniso.rh2         # IDS_ERR_HFS_BTREE_DAMAGED 1061
src/plugins/uniso/lang/lang.rc2     # its English text
src/saltests/saltests.cpp           # TestHfsCatalog322 (+ fuzz)
translations/*/uniso.slt, .origin   # the refresh of the new string
```

**Structure Decision**: the existing plug-in and `saltests`; no new project.

## Complexity Tracking

None.
