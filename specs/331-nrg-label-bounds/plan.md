# Implementation Plan: An NRG image's CD-Text labels and track table never reach past a buffer

**Branch**: `331-nrg-label-bounds` | **Date**: 2026-10-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/331-nrg-label-bounds/spec.md`

## Summary

Three sites of the `uniso` plug-in's NRG path take sizes and numbers from the image unchecked. The
pure decisions move into a new header-only rule `src/common/salnrgcdtext.h` (tested in `saltests`),
and the sites use it:

- **Track name** (`audio.cpp` `CAudio::ListDirectory`): `SalNrgAudioTrackNameAlloc` builds the whole
  name (`NN label` / `Audio Track NN`) in a heap buffer of the length `snprintf` reports; the name goes
  to `AddFileDir` unchanged, so feature 329's listing rule lists or leaves out and reports it; out of
  memory marks the listing incomplete and shows the plug-in's out-of-memory error (as `AddFileDir`).
- **CD-Text** (`nrg.cpp` `readCDTX`): the chunk is used only when `SalNrgChunkFits` (its bytes lie
  within the image after the header, 64-bit arithmetic); the buffer is `malloc(header->Size)` (no
  added terms, no wrap; `malloc(0)` avoided); a failed allocation or a short read gives no labels.
  The text is gathered in place by `SalNrgCdTextGather` (block k at 4 + 18k, at most 12 bytes,
  clipped to the chunk) and split by `SalNrgCdTextNext` (a string without a terminator ends at the
  text's end); each label is copied to a 0-terminated heap string for `SetLabel`. A chunk not used is
  skipped with `Seek(header->Size, FILE_CURRENT)` like an unknown chunk.
- **DAOX** (`nrg.cpp` `readDAOX`): header and entry reads must be complete; an entry is applied only
  when `SalNrgDaoTrackInRange(number, trackCount)` (1..count) - else it is read and dropped.
- **`CISOImage::GetTrack`** (`isoimage.cpp`): `track < Tracks.Count` (was `<=`).

No new UI string, no plug-in interface change, no message added or removed.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: plug-in API (unchanged); feature 329's listing rule in `CAudio::AddFileDir`  
**Storage**: N/A  
**Testing**: `saltests` (`TestNrgCdText331`: the four rules over sizes 0..200, sizes near 4 GiB, label lengths 0..4096, track numbers); feature 329's probe as the regression of the fitting-label path  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application, archiver plug-in `uniso`  
**Performance Goals**: none (labels are gathered once per image open, linear in the chunk)  
**Constraints**: plug-in ABI unchanged; no UI string; consistent images list exactly as before  
**Scale/Scope**: `audio.cpp`, `nrg.cpp`, `isoimage.cpp` (a few lines each), the new header, saltests

## Constitution Check

- I Build reproducibility: a header in `src/common/`, no dependency. PASS
- II Backward compatibility: consistent images list the same names; the plug-in interface is
  untouched. PASS
- III Incremental modernization: local checks at the three sites, a tested rule. PASS
- IV Windows commitment: N/A. PASS
- V Plug-in architecture: no ABI change; the rule is header-only for the plug-in (standing rule). PASS
- VI UI consistency: feature 329's report is the only message. PASS

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/331-nrg-label-bounds/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── checklists/requirements.md
```

No `contracts/`: nothing is exposed to plug-ins or users.

### Source Code (repository root)

```text
src/common/salnrgcdtext.h        new: SalNrgChunkFits, SalNrgCdTextGather (+ Len), SalNrgCdTextNext,
                                 SalNrgDaoTrackInRange, SalNrgAudioTrackNameAlloc
src/plugins/uniso/audio.cpp      ListDirectory: the heap name
src/plugins/uniso/nrg.cpp        readCDTX, readDAOX: the checks
src/plugins/uniso/isoimage.cpp   GetTrack: index < count
src/saltests/saltests.cpp        TestNrgCdText331
```

**Structure Decision**: the existing plug-in and test project; the rule header sits next to
`salisonamefit.h` (328), which `uniso` already includes from `src/common/`.

## Complexity Tracking

None.
