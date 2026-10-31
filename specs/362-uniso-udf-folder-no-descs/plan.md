# Implementation Plan: ISO plug-in - a UDF folder entry without descriptors is unreadable, not empty

**Branch**: `362-uniso-udf-folder-no-descs` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/362-uniso-udf-folder-no-descs/spec.md`

## Summary

The folder reader `CUDF::MapICB(CAD icb, CICBTag* icbTag, CAD* file)` (`src/plugins/uniso/udf.cpp`) asks the
general file-entry reader `ReadFileEntry(data, bEFE, part, icbTag, ad, 1)` (feature 361) for the folder's first
descriptor and returns 1 for every result except the refusal. For an entry with L_AD 0 the reader stores no
descriptor and returns 0 (only the terminating descriptor: Length 0, Location 0, `Offset` unset); `ListDirectory`
(root) and `ScanDir` (sub-folder) then walk nothing and report `ERR_OK` - the folder is listed empty, the listing
is not marked, a whole unpack with "Delete archive after unpacking" deletes the image. The fix:

1. A pure rule in feature 361's header `src/common/salisoudfentry.h`:
   `SalIsoUdfFolderEntryWalkable(int stored)` - true only when the reader stored at least one descriptor
   (`stored > 0`) or found embedded data (`-1`, a non-empty area); false for 0 (no descriptors: L_AD 0, also an
   embedded entry with L_AD 0) and for any other negative value (the refusal, `UDF_FE_REFUSED` = -2). A folder
   always holds its parent's identifier, so an entry that describes no bytes is damaged.
2. `MapICB(CAD, CICBTag*, CAD*)` returns 0 when the rule says false (replaces 361's single `UDF_FE_REFUSED`
   test). Its two callers already map 0 to the unreadable-folder path: `ListDirectory` - "Bad root ICB" and
   `ListingLeftOut.SetIncomplete()`; `ScanDir` - the folder stays listed, is not descended,
   `ListingLeftOut.SetIncomplete()` (feature 330).
3. `saltests`: `TestIsoUdfFolderEntry_362` - the rule's values, and a model of the reader's return over a grid of
   L_EA / L_AD / type built on `SalIsoUdfEntryDescs`, checking walkable == (accepted and L_AD > 0).
4. Probe `probe/iso362_probe.ps1` + `probe/img362.py` + `probe/mkimg362.sh` (measured before: 7 FAIL);
   regressions: probes 330 and 361.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; `src/common/salisoudfentry.h` (feature 361)
**Storage**: N/A
**Testing**: `saltests`; hidden-desktop probe `probe/iso362_probe.ps1` (images in WSL Ubuntu); regression probes
330 (`iso330_probe.ps1`) and 361 (`iso361_probe.ps1`)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`uniso.spl`)
**Performance Goals**: unchanged
**Constraints**: no UI string, no dialog, no plug-in ABI change; the rule header-only
**Scale/Scope**: one function in the plug-in, one rule, one test group

## Constitution Check

- I. Build reproducibility: no new dependency, no project file change. PASS
- II. Backward compatibility: every folder entry that describes at least one byte reads as before; only a folder
  entry that describes none (damaged - no parent identifier) takes the existing unreadable path. Files are not
  read through `MapICB(CAD, CICBTag*, CAD*)`. PASS
- III. Incremental modernization: the rule pure in `src/common/` with tests. PASS
- IV. Windows commitment: unchanged. PASS
- V. Plugin architecture: no `spl_*.h` change. PASS
- VI. UI consistency: existing messages only. PASS

Re-check after design: PASS (unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/362-uniso-udf-folder-no-descs/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ iso362_probe.ps1, img362.py, mkimg362.sh, result_*.txt
```

### Source Code (repository root)

```text
src/common/salisoudfentry.h       # + SalIsoUdfFolderEntryWalkable
src/saltests/saltests.cpp         # + TestIsoUdfFolderEntry_362
src/plugins/uniso/udf.cpp         # MapICB(CAD, CICBTag*, CAD*) through the rule
```

**Structure Decision**: the existing plug-in and common-header layout (as feature 361).

## Complexity Tracking

None.
