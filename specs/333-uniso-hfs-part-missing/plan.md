# Implementation Plan: A hybrid disc image whose HFS+ part does not open is kept by Unpack with "Delete archive after unpacking"

**Branch**: `333-uniso-hfs-part-missing` | **Date**: 2026-10-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/333-uniso-hfs-part-missing/spec.md`

## Summary

`CUDFISO::Open` (ISO plug-in) opens the HFS+ part of every ISO 9660 / UDF hybrid quietly and drops it
when `CHFS::Open` fails, without marking the listing. The fix: `CHFS::Open` records whether the
volume header it read declares an HFS+ volume (`SalHfsVolumeHeaderDeclaresHfsPlus`, a new pure rule
in `src/common/salhfscatalog.h`, saltests checks); `CUDFISO::Open` sets 330's `PartMissing` when a
declared HFS+ part did not open, so `ListDirectory` marks `ListingLeftOut` incomplete and a whole
unpack with "Delete archive after unpacking" keeps the image. No message, no UI string.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new (WinAPI; the plug-in's own readers)
**Storage**: N/A (reads disc images)
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/iso333_probe.ps1` (seeds by xorriso
in WSL Ubuntu, damaged copies by `probe/img333.py`); regression probes of 322 / 329 / 330 / 332
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`src/plugins/uniso`)
**Performance Goals**: N/A (one check of two / four bytes already in memory)
**Constraints**: plug-in ABI untouched; no UI string (no `.slt` refresh); fail closed only where an
HFS+ volume is shown by its own signature (Ubuntu-style APM install images must stay unmarked)
**Scale/Scope**: 3 source files of the plug-in, 1 header in `src/common`, saltests

## Constitution Check

- I Build reproducibility: no new dependency, no build change - PASS.
- II Backward compatibility: valid images and images without an HFS+ volume behave as before
  (probe controls H-OK, APM-EFI, H-NOSIG); only damaged HFS+ hybrids are kept instead of deleted - PASS.
- III Incremental modernization: a small pure rule in `src/common` with tests - PASS.
- IV Windows commitment: unchanged - PASS.
- V Plug-in architecture preservation: no interface change; header-only rule for the plug-in - PASS.
- VI UI consistency: no UI change - PASS.

## Project Structure

### Documentation (this feature)

```text
specs/333-uniso-hfs-part-missing/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ (iso333_probe.ps1, mkimg333.sh, img333.py, result_*.txt, regress_*.txt)
```

### Source Code (repository root)

```text
src/common/salhfscatalog.h          SalHfsVolumeHeaderDeclaresHfsPlus (new, pure)
src/saltests/saltests.cpp           TestHfsVolumeDeclared333
src/plugins/uniso/hfs.h / hfs.cpp   CHFS::Declared, set in Open from the first volume header read
src/plugins/uniso/udfiso.cpp        CUDFISO::Open: a declared HFS+ part that does not open -> PartMissing
```

**Structure Decision**: the existing plug-in and `src/common` layout; no new files besides the probe.

## Complexity Tracking

None.
