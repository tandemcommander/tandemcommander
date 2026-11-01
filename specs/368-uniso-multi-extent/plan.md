# Implementation Plan: ISO plug-in - an ISO 9660 file stored in several extents is listed once and extracted whole

**Branch**: `368-uniso-multi-extent` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/368-uniso-multi-extent/spec.md`

## Summary

The ISO 9660 reader of the ISO plug-in (`src/plugins/uniso/iso9660.cpp`) groups the consecutive file records of one
identifier whose records but the last carry the multi-extent bit (0x80) into one listed file: its size is the sum of
the records' data lengths, its `CISOImage::CFilePos` carries the list of extents, and `CISO9660::UnpackFile` reads
the extents in record order. A chain without its last record, a chain whose extents leave the first extent's track,
or one on a track that stores Mode 2 Form 2 data is left out, reported with the existing "Error reading directory
structure" box and marks the listing incomplete (a whole Unpack fails, the image is kept). The decisions are a pure
header `src/common/salisoextent.h` with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; header-only rule under `src/common/` (the plug-in includes `../../common/...`
as it does `salisounpack.h`)
**Storage**: N/A (no registry, no file format of the product changes)
**Testing**: `saltests` (pure rule: grouping, broken chains, the per-sector read plan, the track check); GUI probe
`specs/368-uniso-multi-extent/probe/iso368_probe.ps1` on the hidden desktop; regression probes 338 and 337
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, archive plug-in (`uniso.spl`)
**Performance Goals**: a 4 GiB file extracts at the same per-sector speed as a single-extent file (one read per
2048-byte sector, as today); listing cost unchanged (records are already read)
**Constraints**: plug-in ABI unchanged (`CFilePos` is the plug-in's own data); no new UI string; the 366 / 367 Form 2
paths and 336 / 337 coverage checks unchanged for single-extent files
**Scale/Scope**: one reader (ISO 9660 / Joliet / Rock Ridge trees), ~150 lines changed, one new header

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency; header-only rule; builds with `build.cmd` |
| II. Backward compatibility | single-extent files read as before; a chain was listed as several files before (wrong content) - now one file; no setting or stored data changes |
| III. Incremental modernization | the change is local to the ISO 9660 walk and reader; the pure rule goes to `src/common/` with tests (project rule) |
| IV. Windows commitment | unchanged |
| V. Plugin architecture | no change of the plug-in interface (`LAST_VERSION_OF_SALAMANDER` stays); `CFilePos` is private to uniso |
| VI. UI consistency | no new dialog or text; the existing listing-error box reports a broken chain |

Gate: PASS (no violation). Re-checked after design: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/368-uniso-multi-extent/
├── spec.md
├── plan.md              # this file
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/salisoextent.md
├── checklists/requirements.md
├── fix-log.md
├── probe/               # img368.py, mkimg368.sh, iso368_probe.ps1, results
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
src/common/salisoextent.h          # new: pure rule (chain grouping, read plan, track check)
src/plugins/uniso/isoimage.h       # CFilePos: extent list + destructor; CISOImage::ChainReadable
src/plugins/uniso/isoimage.cpp     # CISOImage::ChainReadable (tracks of the extents, Form 2 layout)
src/plugins/uniso/iso9660.h        # AddFileDir / file-record helper signatures
src/plugins/uniso/iso9660.cpp      # ListDirectoryRe: chain state; AddFileDir: size + extents; UnpackFile: extents
src/saltests/saltests.cpp          # TestIsoMultiExtent_368
```

**Structure Decision**: existing plug-in and test projects; one new header under `src/common/`.

## Complexity Tracking

None.
