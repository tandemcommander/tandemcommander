# Implementation Plan: A Form 2 track that no listed file covers keeps the image after Unpack with "Delete archive after unpacking"

**Branch**: `336-uniso-form2-uncovered` | **Date**: 2026-10-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/336-uniso-form2-uncovered/spec.md`

## Summary

Feature 335's `CISOImage::Open` (ISO plug-in) decides that a track-table data track with no file system
is a Mode 2 Form 2 stream (`RawLost` false) and nothing marks it afterwards. The fix records that
decision as `Track::Form2Stream` and, after the listing, walks the listed tree: every listed file of more
than zero bytes notes the track its start extent maps to (`SalIsoNoteFileStart`, by
`SalIsoTrackOfExtent` - the rule of `GetTrackFromExtent`, which the unpack uses to pick the track it
reads a file from, and which now calls the shared rule). A Form 2 stream track no file starts in marks
the listing (`SalIsoStreamTrackMarksListing` -> `ListingLeftOut.SetIncomplete()`, feature 328's path: a
whole unpack fails, "Delete archive after unpacking" keeps the image). The rules are header-only in
`src/common/salisotrack.h` with `saltests` checks. No UI string.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new
**Storage**: N/A (reads disc images)
**Testing**: `saltests` (pure rules); hidden-desktop probe `probe/iso336_probe.ps1` (feature 335's rows with
the turned expectations + covered / uncovered stream rows; seeds by 334's `mkimg334.sh` and this
feature's `mkimg336.sh` in WSL Ubuntu, images by 335's `img335.py` / `ccd335.py` and `probe/img336.py`);
reviewer 3's real vcdimager probe `specs/335-uniso-raw-track-lost/probe/review3/rev335c_probe.ps1`
(deletion controls); regression probes 322 / 329 / 330 / 333 / 334
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`src/plugins/uniso`)
**Performance Goals**: one walk of the listed tree after listing, only when the image has a Form 2
stream track
**Constraints**: plug-in ABI untouched; no UI string (no `.slt` refresh); tracks that are not Form 2
streams and images without a track table untouched
**Scale/Scope**: `salisotrack.h`, `saltests.cpp`, `isoimage.h`, `isoimage.cpp`

## Constitution Check

- I Build reproducibility: no new dependency, no build change - PASS.
- II Backward compatibility: images without Form 2 stream tracks behave as before; a Video CD whose
  `AVSEQnn` files cover its streams too (real vcdimager rows); only images with a stream no file
  covers are kept now - fails closed, no data lost - PASS.
- III Incremental modernization: small pure rules in `src/common` with tests - PASS.
- IV Windows commitment: unchanged - PASS.
- V Plug-in architecture preservation: no interface change; header-only rules - PASS.
- VI UI consistency: no UI change - PASS.

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/336-uniso-form2-uncovered/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ (iso336_probe.ps1, mkimg336.sh, img336.py, result_*.txt, regress_*.txt)
```

No `contracts/`: nothing outside the plug-in changes.

### Source Code (repository root)

```text
src/common/salisotrack.h            SalIsoTrackOfExtent, SalIsoNoteFileStart, SalIsoStreamTrackMarksListing (new)
src/saltests/saltests.cpp           TestIsoStreamCovered_336
src/plugins/uniso/isoimage.h        Track::Form2Stream; MarkUncoveredStreams; ListTracks
src/plugins/uniso/isoimage.cpp      Track(), Open (Form2Stream), GetTrackFromExtent (the shared rule),
                                    ListImage = ListTracks + MarkUncoveredStreams
```

**Structure Decision**: the existing plug-in and `src/common` layout; no new source files.

## Complexity Tracking

None.
