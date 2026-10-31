# Implementation Plan: Every track of a disc image starts with defined values

**Branch**: `351-uniso-track-defaults` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/351-uniso-track-defaults/spec.md`

## Summary

`CISOImage::Track::Track()` (`src/plugins/uniso/isoimage.cpp`) leaves `SectorSize`,
`SectorHeaderSize`, `Mode`, `Start`, `End`, `ExtentOffset` and `FSType` as the heap held them; the
CloneCD reader (`CISOImage::ReadSessionCCD`, `src/plugins/uniso/img.cpp`) sets `FSType` only for an
audio track, and a Nero CUEX track (`readCUEX`, `src/plugins/uniso/nrg.cpp`) that no DAOX entry
describes keeps every field unset. Fix:

1. The constructor sets every field: `FSType = fsUnknown`, `Mode = mNone`, the sizes, bounds and
   extent offset 0 (the existing `FileSystem`, `Bootable`, `RawLost`, `Form2Stream` unchanged).
2. A pure rule `SalIsoCcdTrackKind(mode)` in `src/common/salisotrack.h` (0 -> audio, 1 / 2 -> data,
   anything else -> unknown) with `saltests` checks; the CloneCD loop maps it: audio -> `mNone` /
   `fsAudio` (as before), data -> `mMode1` / `mMode2` with `fsISO9660` (the value the Nero reader
   gives a data track; `Open` detects the real file system and replaces it), unknown -> the
   constructor's `mNone` / `fsUnknown`.
3. The Nero readers need no change: with (1) an undescribed CUEX track is `fsUnknown` with zero
   bounds - `Open` does not detect it, `ListTracks` / the single-session path mark it (334).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new  
**Storage**: N/A  
**Testing**: `saltests` (`TestIsoCcdTrackKind_351`); hidden-desktop probe `probe/iso351_probe.ps1`
(images by `probe/img351.py` from 334's `mkimg334.sh` seeds) on Debug and on a Release build of the
fixed plug-in; regressions: the probes of 334, 335, 350  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (uniso)  
**Performance Goals**: N/A  
**Constraints**: plug-in ABI unchanged; header-only rule (uniso includes `src/common` headers as
`../../common/...`, 331); the 0.2.0 Release tree under `build\tandemcommander\Release_x64` is left as
it is - the Release "after" measurement builds only `uniso.vcxproj` (Release x64) with
`OPENSAL_BUILD_DIR` pointing to a folder under `%TEMP%` and runs a copy of the 0.2.0 tree with that
`uniso.spl` (research R2)  
**Scale/Scope**: one constructor, one reader loop, one header function, one test function

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | No new dependency. PASS |
| II. Backward compatibility | Every reader that describes a track overwrites the defaults as before (FR-004; N-ONE, 334 / 335 / 350 probes). PASS |
| III. Incremental modernization | Field defaults and a pure rule with tests. PASS |
| IV. Windows commitment | Unchanged. PASS |
| V. Plugin architecture | No change to `spl_*.h`, no ABI change (`Track` is internal to uniso). PASS |
| VI. UI consistency | No UI text, dialog or menu change - no `.slt` refresh. PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/351-uniso-track-defaults/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md
├── checklists/requirements.md
└── probe/ (iso351_probe.ps1, img351.py, result_*.txt)
```

No `contracts/`: nothing outside the plug-in sees the track record.

### Source Code (repository root)

```text
src/plugins/uniso/isoimage.cpp   Track::Track() - every field defined
src/plugins/uniso/img.cpp        ReadSessionCCD's track loop - SalIsoCcdTrackKind
src/common/salisotrack.h         SalIsoCcdTrackKind (new, header-only)
src/saltests/saltests.cpp        TestIsoCcdTrackKind_351 (next to TestIsoTrackMarks334)
```

**Structure Decision**: existing files only; the rule goes next to 334's track rules.

## Complexity Tracking

None.
