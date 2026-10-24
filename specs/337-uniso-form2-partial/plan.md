# Implementation Plan: A file covering part of a Form 2 stream no longer lets Unpack delete the image

**Branch**: `337-uniso-form2-partial` | **Date**: 2026-10-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/337-uniso-form2-partial/spec.md`

## Summary

Feature 336's `CISOImage::MarkUncoveredStreams` marks the listing incomplete only when no listed file
starts in a Form 2 stream track. It now also checks *how much* of the stream the files read: the walk of
the listed tree collects, for every file that starts in a stream track, the track-relative sectors the
unpack reads (`[extent - ExtentOffset, + ceil(size / 2048))`, clipped to the track). Per stream track the
ranges are sorted and merged; the uncovered sectors are counted; more than 300 mark the listing, else
each uncovered stored sector is read and must have an all-zero 2324-byte Form 2 user data area (the
gaps of a real vcdimager disc), otherwise the listing is marked. The track's sector count comes from its
track-table end, extended to the next track's start and to the image end when the end is unknown, never
past the image file (fails closed). The pure rules go into `src/common/salisotrack.h` with saltests.

## Technical Context

**Language/Version**: C++20 (MSVC v143), WinAPI; the ISO plug-in `uniso`  
**Primary Dependencies**: none new (`<algorithm>` for `std::sort` in the header)  
**Storage**: N/A (reads the image only)  
**Testing**: `saltests` (pure rules); GUI probe `specs/337-uniso-form2-partial/probe/iso337_probe.ps1` on the hidden desktop (based on 336's); 335's `review3/rev335c_probe.ps1` for real vcdimager images  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application, plug-in  
**Performance Goals**: at most 300 stored sectors (< 1 MB) read per stream track per listing, only when a file starts in it; the gap search is linear in the files starting in the track per gap (at most 300 gaps)  
**Constraints**: fail closed on every doubt; plug-in ABI unchanged; no UI text  
**Scale/Scope**: `salisotrack.h`, `isoimage.cpp/.h`, `saltests.cpp`, a probe

## Constitution Check

- I Build reproducibility: no new dependency, no build change - PASS.
- II Backward compatibility: images without stream tracks unchanged; real vcdimager VCD/SVCD images
  still deleted (their uncovered sectors are empty gaps); only images whose streams are partly covered
  by data are kept now - fails closed, no data lost - PASS.
- III Incremental modernization: pure rules in `src/common` with tests - PASS.
- IV Windows commitment: unchanged - PASS.
- V Plug-in architecture preservation: no interface change; header-only rules - PASS.
- VI UI consistency: no UI change - PASS.

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/337-uniso-form2-partial/
├── plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md
└── probe/ (img337.py, iso337_probe.ps1, results)
```

### Source Code (repository root)

```text
src/common/salisotrack.h          # + SalIsoFileStartTrack, SalIsoStreamTrackSectors, SalIsoFileSectorSpan,
                                  #   SalIsoStreamSpan + SalIsoMergeStreamSpans, SalIsoStreamUncovered,
                                  #   SalIsoStreamNextGap, SalIsoForm2PayloadOffset, SalIsoPayloadEmpty,
                                  #   SalIsoStreamGapsMark (SAL_ISO_STREAM_GAP_SECTORS = 300)
src/plugins/uniso/isoimage.h/.cpp # MarkUncoveredStreams / NoteListedFileStarts collect spans, check gaps
src/saltests/saltests.cpp         # TestIsoStreamPartial_337
```

**Structure Decision**: existing layout; the rule beside 334-336's in `salisotrack.h`.

## Complexity Tracking

No violations.
