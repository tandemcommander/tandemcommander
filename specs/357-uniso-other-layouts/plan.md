# Implementation Plan: A multi-session image opened through another plain layout is kept after a partial unpack

**Branch**: `357-uniso-other-layouts` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/357-uniso-other-layouts/spec.md`

## Summary

`CISOImage::Open`'s plain branch runs 355's rest check only for a file with a raw start (`rawStart &&
!CcdMissing`). The check itself already works at the opened layout (`DataOffset`, `SectorRawSize`,
`SectorHeaderSize`). The plain branch now remembers which check opened the file (`SalIsoPlainLayout`) and asks a
new pure decision `SalIsoPlainRawRuleApplies(rawStart, ccdMissing, layout)` (`src/common/salisotrack.h`)
whether 355's block runs: a raw start without a missing `.ccd` as before (any layout), and - new - a file
without a raw start opened through the NRG offset, 2336, NCD, PDI, ECDC, CIF, C2D or CIF 2332 check. ISO
(cooked, 354), Xbox, MDF, HFS, APFS without a raw start: no. 355's block and rule are unchanged otherwise.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new; `salisotrack.h` (header-only, used by uniso and saltests)  
**Storage**: N/A (no registry, no files written)  
**Testing**: `saltests` (`TestIsoPlainLayouts_357`), hidden-desktop probe `probe/iso357_probe.ps1` (images by
`probe/img357.py` from 334's `mkimg334.sh` seeds); regressions: probes of 353, 354, 355, 356  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (`uniso.spl`)  
**Performance Goals**: as 355 - one read of 132 bytes per open of such an image; up to 512 reads of 2048 bytes  
**Constraints**: no UI string, no plug-in ABI change; 353's, 354's and 356's blocks unchanged  
**Scale/Scope**: one plug-in source file, one common header, one test group

## Constitution Check

- I. Build reproducibility: no new dependency, no project change. PASS
- II. Backward compatibility: a one-session image of the covered layouts (within 16 sectors of its volume, or a
  tail of zero user data up to 512 sectors) behaves as in 0.2.0; raw, cooked, Xbox, HFS, APFS images unchanged;
  the change keeps images where data would be lost or cannot be shown absent. PASS
- III. Incremental modernization: a pure rule in `src/common/` with tests, a minimal plug-in edit. PASS
- IV. Windows commitment: unchanged. PASS
- V. Plugin architecture: no `spl_*.h` change, no `LAST_VERSION_OF_SALAMANDER` change. PASS
- VI. UI consistency: no new message. PASS

Re-check after design: PASS (unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/357-uniso-other-layouts/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ iso357_probe.ps1, img357.py, result_*.txt, regress_*.txt
```

### Source Code (repository root)

```text
src/common/salisotrack.h          # + SalIsoPlainLayout enum, SalIsoPlainRawRuleApplies
src/saltests/saltests.cpp         # + TestIsoPlainLayouts_357
src/plugins/uniso/isoimage.cpp    # Open's plain branch: remember the layout; 355's block condition via the rule
```

**Structure Decision**: the existing plug-in and common-header layout (as features 334-356).

## Complexity Tracking

None.
