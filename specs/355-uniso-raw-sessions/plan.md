# Implementation Plan: A raw disc image is kept when it holds more than its listing shows, whatever its name

**Branch**: `355-uniso-raw-sessions` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/355-uniso-raw-sessions/spec.md`

## Summary

When `CISOImage::Open` (ISO plug-in, `src/plugins/uniso/isoimage.cpp`) opens a file through the plain
detection, the file starts with the CD sync pattern (353's `rawStart`) and 353's missing-`.ccd` block does
not apply (`CcdMissing` false - every name but an `.img` whose `.ccd` is missing), the plug-in reads the
primary volume descriptor at the opened layout's sector 16 and asks a new pure rule in
`src/common/salisotrack.h`, `SalIsoRawRestDecision`, what to do with the whole sectors past that volume:
keep the listing (at most 16 whole sectors past it), mark (no valid descriptor, a sector size that is not
positive, the file ends within the volume, more than 512 sectors past it), or check (read the 2048 bytes
of user data of each sector past the volume at the opened layout; mark unless every read is whole and zero
bytes only - `SalIsoBytesAllZero` of 354). A marked listing makes a whole unpack fail (features 328 / 334 /
352 / 353 / 354), so "Delete archive after unpacking" keeps the image.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new; `salisotrack.h` (header-only, used by uniso and saltests)  
**Storage**: N/A (no registry, no files written)  
**Testing**: `saltests` (`TestIsoRawRest_355`), hidden-desktop probe `probe/iso355_probe.ps1` (images by
`probe/img355.py` from feature 334's `mkimg334.sh`); regressions: the probes of 354, 353, 352, 334  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (`uniso.spl`)  
**Performance Goals**: one read of 132 bytes per open of a raw plain image; up to 512 reads of 2048 bytes
only when 17..512 sectors lie past the volume  
**Constraints**: no UI string, no plug-in ABI change; 353's and 354's blocks unchanged  
**Scale/Scope**: one plug-in source file, one common header, one test group

## Constitution Check

- I. Build reproducibility: no new dependency, no project change. PASS
- II. Backward compatibility: a raw one-session image (within 16 sectors of its volume, or a tail of zero
  user data up to 512 sectors) behaves as in 0.2.0; the change keeps images where data would be lost or
  cannot be shown absent. PASS
- III. Incremental modernization: a pure rule in `src/common/` with tests, a minimal plug-in edit. PASS
- IV. Windows commitment: unchanged. PASS
- V. Plugin architecture: no `spl_*.h` change, no `LAST_VERSION_OF_SALAMANDER` change. PASS
- VI. UI consistency: no new message. PASS

Re-check after design: PASS (unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/355-uniso-raw-sessions/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ iso355_probe.ps1, img355.py, result_*.txt, regress_*.txt
```

### Source Code (repository root)

```text
src/common/salisotrack.h          # + SalIsoRawRestDecision (reuses SAL_ISO_REST_*, 353's and 354's constants)
src/saltests/saltests.cpp         # + TestIsoRawRest_355
src/plugins/uniso/isoimage.cpp    # Open's plain branch: a block for rawStart && !CcdMissing after 353's block
```

**Structure Decision**: the existing plug-in and common-header layout (as features 334-354).

## Complexity Tracking

None.
