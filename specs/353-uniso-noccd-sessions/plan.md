# Implementation Plan: A CloneCD image without its .ccd is kept when it holds more than its listing shows

**Branch**: `353-uniso-noccd-sessions` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/353-uniso-noccd-sessions/spec.md`

## Summary

When `CISOImage::Open` (ISO plug-in, `src/plugins/uniso/isoimage.cpp`) falls back to the plain
detection because an `.img`'s `.ccd` could not be opened, and the start of the file carries the CD
sync pattern (a raw dump, as CloneCD writes), the plug-in reads the primary volume descriptor where
the opened layout puts sector 16, takes its volume space size, and marks `ListingLeftOut` incomplete
when the file holds more than 16 whole sectors past that volume (or the size cannot be read). The
decision is a pure, header-only rule in `src/common/salisotrack.h` with `saltests` checks; the
plug-in only gathers its inputs. A whole unpack of a marked listing fails (features 328 / 334 / 352),
so "Delete archive after unpacking" keeps the image.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new; `salisotrack.h` (header-only, used by uniso and saltests)  
**Storage**: N/A (no registry, no files written)  
**Testing**: `saltests` (`TestIsoNoCcdRest_353`), hidden-desktop probe `probe/iso353_probe.ps1`
(images by `probe/img353.py` from feature 334's `mkimg334.sh`); regressions: 352's and 351's probes  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (`uniso.spl`)  
**Performance Goals**: one extra read of 2048 bytes (at most) per open of an `.img` without `.ccd`  
**Constraints**: no UI string, no plug-in ABI change, Debug and Release identical behaviour  
**Scale/Scope**: two source files of the plug-in (`img.cpp`, `isoimage.cpp`, `isoimage.h`), one
common header, one test group

## Constitution Check

- I. Build reproducibility: no new dependency, no project change. PASS
- II. Backward compatibility: an image with a `.ccd` and a plain `.img` behave as in 0.1.0 / 0.2.0;
  the only change is a kept image where data would be lost. PASS
- III. Incremental modernization: a pure rule in `src/common/` with tests, minimal plug-in edit. PASS
- IV. Windows commitment: unchanged. PASS
- V. Plugin architecture: no `spl_*.h` change, no `LAST_VERSION_OF_SALAMANDER` change. PASS
- VI. UI consistency: no new message; the existing "Missing .CCD file" box stays. PASS

Re-check after design: PASS (unchanged).

## Project Structure

### Documentation (this feature)

```text
specs/353-uniso-noccd-sessions/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ iso353_probe.ps1, img353.py, result_*.txt
```

### Source Code (repository root)

```text
src/common/salisotrack.h          # + SalIsoPvdVolumeSectors, SalIsoNoCcdRestMarks, SAL_ISO_LATER_VOLUME_SECTOR
src/saltests/saltests.cpp         # + TestIsoNoCcdRest_353
src/plugins/uniso/isoimage.h      # + BOOL CcdMissing (set by ReadSessionCCD)
src/plugins/uniso/img.cpp         # processCCDFile reports "missing" (CCD::Missing) -> CcdMissing
src/plugins/uniso/isoimage.cpp    # ReadSessionInfo resets CcdMissing; Open's plain branch applies the rule
```

**Structure Decision**: the existing plug-in and common-header layout (as features 334-352).

## Complexity Tracking

None.
