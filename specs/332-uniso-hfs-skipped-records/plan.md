# Implementation Plan: An HFS+ image whose catalog records were skipped as damaged is kept by Unpack with "Delete archive after unpacking"

**Branch**: `332-uniso-hfs-skipped-records` | **Date**: 2026-10-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/332-uniso-hfs-skipped-records/spec.md`

## Summary

Feature 328 gave the `uniso` plug-in a "listing incomplete" mark (`CISOImage::ListingLeftOut.
SetIncomplete()`); a whole-image unpack of a marked listing fails, so "Delete archive after unpacking"
keeps the image. `CHFS::ListDirectory` skips damaged catalog records and ends at a record type it
does not handle without setting it. This feature:

- moves the decision "what is this catalog leaf record" into a pure rule
  `SalHfsCatalogRecordClass` in `src/common/salhfscatalog.h` (header-only - the plug-in already uses
  this header, feature 322): FOLDER / FILE (an entry to list), NOT_ENTRY (a thread record, the root
  folder's record when it is the volume label, a folder / file whose name starts with U+0000 - HFS+
  metadata), DAMAGED (skipped, marked), UNKNOWN (a named record of a type the reader does not handle -
  marked, the listing ends there as today);
- uses it in `CHFS::ListDirectory`: DAMAGED -> `SetIncomplete()` + skip; UNKNOWN -> `SetIncomplete()`
  + `return FALSE` (as before); a name that does not convert -> `SetIncomplete()` + skip;
- checks the rule in `saltests` (every class, the boundaries 87/88, 247/248, 255/256 units, a NULL /
  short record, the probe's four damages);
- adds the hidden-desktop probe `probe/iso332_probe.ps1` (H rows + UDF regression rows).

The UDF reader is not changed (feature 330 already marks a file whose entry cannot be read - research
R1). No UI string, no plug-in interface change, no message added or removed.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: plug-in API (unchanged); `src/common/salhfscatalog.h` (322), `CSalListingLeftOut` (328)  
**Storage**: N/A  
**Testing**: `saltests` (new `TestHfsRecordClass332`); hidden-desktop probe `probe/iso332_probe.ps1`; regression probes 322 / 328 / 329 / 330  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application, archiver plug-in `uniso`  
**Performance Goals**: none (one classification per catalog record, as many checks as before)  
**Constraints**: plug-in ABI unchanged; no UI string; listing of intact images unchanged  
**Scale/Scope**: `salhfscatalog.h` (one function), `hfs.cpp` (`ListDirectory`), `saltests.cpp`, the probe

## Constitution Check

- I Build reproducibility: no new dependency. PASS
- II Backward compatibility: an intact image lists, unpacks and is deleted as before; thread records,
  the volume label and HFS+ metadata stay unmarked; the plug-in interface is untouched. PASS
- III Incremental modernization: a pure rule in `src/common` with unit checks, 328's existing mark. PASS
- IV Windows commitment: N/A. PASS
- V Plug-in architecture: no ABI change; a header-only shared rule (CLAUDE.md: plug-ins cannot compile
  a `.cpp` of `src/common`). PASS
- VI UI consistency: nothing new shown. PASS

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/332-uniso-hfs-skipped-records/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/ (iso332_probe.ps1, mkimg332.sh, img332.py, result_*.txt)
```

No `contracts/`: the rule is internal to the plug-in and saltests; nothing is exposed to plug-ins or
users.

### Source Code (repository root)

```text
src/common/salhfscatalog.h      SalHfsCatalogRecordClass + SAL_HFSREC_* (feature 332)
src/plugins/uniso/hfs.cpp       CHFS::ListDirectory: the rule decides; DAMAGED / UNKNOWN / a name that
                                does not convert mark the listing incomplete
src/saltests/saltests.cpp       TestHfsRecordClass332
```

**Structure Decision**: the existing plug-in and shared-header layout; no new file in `src/`.

## Complexity Tracking

None.
