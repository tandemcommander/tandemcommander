# Implementation Plan: A disc image with a track the ISO plug-in cannot open is kept by Unpack with "Delete archive after unpacking"

**Branch**: `334-uniso-session-missing` | **Date**: 2026-10-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/334-uniso-session-missing/spec.md`

## Summary

`CISOImage::ListImage` (ISO plug-in) lists the tracks of an image with a track table; a track that
does not open (multi-session listing, or the last data track of a single-session listing) is skipped
without marking 328's `ListingLeftOut`, and a track whose data lies past the end of the image is taken
as a raw data track that lists nothing. The fix: a pure rule `SalIsoTrackMarksListing` (new header
`src/common/salisotrack.h`, saltests checks) decides from the track's kind (data / audio / unknown),
whether a data track lies outside the image, and what the listing did with it (not tried / not opened /
listing failed / listed) whether the listing is marked incomplete; `CISOImage::Open` records
`Track::OutsideImage` for a track whose detection found no file system and whose sector 16 is not in
the image file; `ListImage` asks the rule for every track in both listing paths. Messages unchanged, no
UI string; a whole unpack of a marked listing fails and "Delete archive after unpacking" keeps the image.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new (WinAPI; the plug-in's own readers)
**Storage**: N/A (reads disc images)
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/iso334_probe.ps1` (seeds by genisoimage
in WSL Ubuntu, NRG images by `probe/img334.py`); regression probes of 322 / 329 / 330 / 333
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`src/plugins/uniso`)
**Performance Goals**: N/A (one comparison per track)
**Constraints**: plug-in ABI untouched; no UI string (no `.slt` refresh); readable raw data tracks
(Video CD), audio tracks that open and "unknown" tracks keep their behaviour
**Scale/Scope**: 2 source files and 1 header of the plug-in, 1 new header in `src/common`, saltests

## Constitution Check

- I Build reproducibility: no new dependency, no build change - PASS.
- II Backward compatibility: images whose tracks all open behave as before (probe controls M-OK,
  S-OK, the earlier ISO probes); only images with a track that cannot be opened are kept - PASS.
- III Incremental modernization: a small pure rule in `src/common` with tests - PASS.
- IV Windows commitment: unchanged - PASS.
- V Plug-in architecture preservation: no interface change; header-only rule (uniso cannot compile a
  `.cpp` of `src/common`) - PASS.
- VI UI consistency: no UI change - PASS.

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/334-uniso-session-missing/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ (iso334_probe.ps1, mkimg334.sh, img334.py, result_*.txt, regress_*.txt)
```

No `contracts/`: nothing outside the plug-in changes (no plug-in interface, no file format).

### Source Code (repository root)

```text
src/common/salisotrack.h            SalIsoTrackMarksListing (new, pure, header-only)
src/saltests/saltests.cpp           TestIsoTrackMarks334
src/plugins/uniso/isoimage.h        Track::OutsideImage; CISOImage::MarkTrack
src/plugins/uniso/isoimage.cpp      Track(), Open (OutsideImage for an fsData track), MarkTrack, ListImage
```

**Structure Decision**: the existing plug-in and `src/common` layout; no new files besides the header
and the probe.

## Complexity Tracking

None.
