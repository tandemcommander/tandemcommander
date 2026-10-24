# Implementation Plan: A disc image with a data track whose file system is lost is kept by Unpack with "Delete archive after unpacking"

**Branch**: `335-uniso-raw-track-lost` | **Date**: 2026-10-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/335-uniso-raw-track-lost/spec.md`

## Summary

`CISOImage::Open` (ISO plug-in) takes a track-table data track in which `DetectTrackFS` finds no file
system as `fsData` (a raw track that lists nothing); feature 334's `Track::OutsideImage` marks it only
when its sector 16 is outside the image. The fix: a pure rule `SalIsoSectorIsForm2` (feature 334's
header `src/common/salisotrack.h`, saltests checks) says whether the first bytes of the track's sector
16, as the image stores them (sector size 2352+ / 2336 / other), are a Mode 2 Form 2 sector; `Open`
reads those bytes and records `Track::RawLost` (renamed from `OutsideImage`) = outside the image, or not
Form 2. `MarkTrack` passes it to `SalIsoTrackMarksListing` as before (its second parameter, renamed
`rawLost`), which marks such a track in every listing path - 328's `ListingLeftOut`, a whole unpack
fails, "Delete archive after unpacking" keeps the image. Messages unchanged, no UI string.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new
**Storage**: N/A (reads disc images)
**Testing**: `saltests` (pure rule); hidden-desktop probe `probe/iso335_probe.ps1` (seeds by 334's
`mkimg334.sh` in WSL Ubuntu, NRG images by `probe/img335.py`); regression probes 322 / 329 / 330 / 333 / 334
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`src/plugins/uniso`)
**Performance Goals**: N/A (one read of at most 24 bytes per raw data track at open)
**Constraints**: plug-in ABI untouched; no UI string (no `.slt` refresh); Video CD MPEG tracks (Form 2)
keep their behaviour; images without a track table untouched
**Scale/Scope**: `salisotrack.h`, `saltests.cpp`, `isoimage.h`, `isoimage.cpp`

## Constitution Check

- I Build reproducibility: no new dependency, no build change - PASS.
- II Backward compatibility: images whose tracks all have a file system, and Video CDs, behave as before
  (probe controls M-OK-2336, M-FORM2, S-VCD; earlier ISO probes); only images with a data track whose
  file system area is not a stream are kept - PASS.
- III Incremental modernization: a small pure rule in `src/common` with tests - PASS.
- IV Windows commitment: unchanged - PASS.
- V Plug-in architecture preservation: no interface change; header-only rule - PASS.
- VI UI consistency: no UI change - PASS.

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/335-uniso-raw-track-lost/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ (iso335_probe.ps1, img335.py, result_*.txt, regress_*.txt)
```

No `contracts/`: nothing outside the plug-in changes.

### Source Code (repository root)

```text
src/common/salisotrack.h            SalIsoSectorIsForm2 (new); SalIsoTrackMarksListing doc / parameter name
src/saltests/saltests.cpp           TestIsoSectorForm2_335
src/plugins/uniso/isoimage.h        Track::RawLost (was OutsideImage)
src/plugins/uniso/isoimage.cpp      Track(), Open (RawLost for an fsData track), MarkTrack, comments
```

**Structure Decision**: the existing plug-in and `src/common` layout; no new source files.

## Complexity Tracking

None.
