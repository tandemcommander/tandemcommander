# Implementation Plan: A cooked disc image is kept when it holds more than its listing shows

**Branch**: `354-uniso-cooked-sessions` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/354-uniso-cooked-sessions/spec.md`

## Summary

When `CISOImage::Open` (ISO plug-in, `src/plugins/uniso/isoimage.cpp`) opens a file through the plain
detection and the file is cooked (no CD sync pattern at its start - 353's `rawStart` false - and
`CheckForISO` accepted the 2048-byte layout at offset 0), the plug-in reads the primary volume
descriptor at sector 16 and asks a pure rule in `src/common/salisotrack.h` what to do with the rest of
the file past that volume: nothing (no descriptor of ISO 9660 at sector 16, or at most 16 whole
sectors past the volume), mark (the size cannot be read, the file ends within the volume, the rest is
longer than 512 sectors), or check (read the rest - at most 1 MiB - and mark unless it is zero bytes
only, or when it cannot be read whole). A marked listing makes a whole unpack fail (features 328 /
334 / 352 / 353), so "Delete archive after unpacking" keeps the image.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new; `salisotrack.h` (header-only, used by uniso and saltests)  
**Storage**: N/A (no registry, no files written)  
**Testing**: `saltests` (`TestIsoCookedRest_354`), hidden-desktop probe `probe/iso354_probe.ps1`
(images by `probe/img354.py` from feature 334's `mkimg334.sh`, xorriso images by
`probe/mkxorriso354.sh`); regressions: the probes of 353, 352 and 334  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (`uniso.spl`)  
**Performance Goals**: one read of 132 bytes per open of a cooked image; a read of the rest only when
it is 17..512 sectors long (at most 1 MiB, in 64 KiB pieces)  
**Constraints**: no UI string, no plug-in ABI change, Debug and Release identical behaviour  
**Scale/Scope**: one plug-in source file (`isoimage.cpp`), one common header, one test group

## Constitution Check

- I. Build reproducibility: no new dependency, no project change. PASS
- II. Backward compatibility: a plain one-volume image (rest at most 16 sectors, or zero bytes up to
  512 sectors) behaves as in 0.2.0; the only change is a kept image where data would be lost (a later
  session, an appended partition) or where the rest cannot be shown empty. PASS
- III. Incremental modernization: a pure rule in `src/common/` with tests, minimal plug-in edit. PASS
- IV. Windows commitment: unchanged. PASS
- V. Plugin architecture: no `spl_*.h` change, no `LAST_VERSION_OF_SALAMANDER` change. PASS
- VI. UI consistency: no new message. PASS

Re-check after design: PASS (unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/354-uniso-cooked-sessions/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ iso354_probe.ps1, img354.py, mkxorriso354.sh, measure_tails.sh, measure2.sh, result_*.txt
```

### Source Code (repository root)

```text
src/common/salisotrack.h          # + SAL_ISO_ZERO_REST_SECTORS, SalIsoCookedRestDecision, SalIsoBytesAllZero
src/saltests/saltests.cpp         # + TestIsoCookedRest_354
src/plugins/uniso/isoimage.cpp    # Open's plain branch: cookedIso flag at CheckForISO; the rule after DetectTrackFS
```

**Structure Decision**: the existing plug-in and common-header layout (as features 334-353).

## Complexity Tracking

None.
