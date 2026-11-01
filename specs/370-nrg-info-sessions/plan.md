# Implementation Plan: The image information of an NRG image stays within its session table

**Branch**: `370-nrg-info-sessions` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/370-nrg-info-sessions/spec.md`

## Summary

`CISOImage::DumpInfo` (`src/plugins/uniso/viewer.cpp`) walks the track table and reads the next
session's count whenever the track index reaches the running sum of the counts - past the session table
when the counts cover fewer tracks than the image holds, and with a signed count. The dump is rewritten
to walk the **sessions** as `CISOImage::ListTracks` does since feature 340: each session gets
`SalIsoSessionTracks(first, (unsigned)Session[s], Tracks.Count, fits)` tracks (`src/common/salisotrack.h`),
its heading and that count are printed with exactly those tracks; the tracks left after the last session
are printed under one new line `IDS_INFO_NO_SESSION` ("\nTracks not in any session\n"). The new string is
translated by the two-stage `.slt` refresh of module `uniso`.

## Technical Context

**Language/Version**: C++20 (MSVC v143, `/std:c++latest`)
**Primary Dependencies**: none new; `src/common/salisotrack.h` (header-only, feature 340's `SalIsoSessionTracks`)
**Storage**: N/A
**Testing**: `saltests` (session walk rows for the dump's cases); GUI probe `probe/iso370_probe.ps1` on the hidden desktop (F3 on eight NRG images, the dump read from the disk cache)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (uniso)
**Performance Goals**: N/A (one loop over at most the session and track tables)
**Constraints**: plug-in ABI untouched; no change to the listing, readers, or stored data
**Scale/Scope**: one function, one new UI string, translations of one module

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency; `build.cmd full` with the refreshed `.slt` |
| II Backward compatibility | output for images whose counts fit (every non-NRG format, normal NRG) unchanged (probe F-FIT) |
| III Incremental modernization | the existing rule `SalIsoSessionTracks` reused, no new mechanism |
| IV Windows commitment | unchanged |
| V Plugin architecture preservation | plug-in internal; no ABI change |
| VI UI consistency | the new line follows the session heading's form; translated into all enabled languages (formal register) |

Gate: PASS (pre- and post-design).

## Project Structure

### Documentation (this feature)

```text
specs/370-nrg-info-sessions/
├── plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/ img370.py, iso370_probe.ps1, result_*.txt
```

### Source Code

```text
src/plugins/uniso/viewer.cpp        CISOImage::DumpInfo - walk by sessions
src/plugins/uniso/uniso.rh2         IDS_INFO_NO_SESSION 1157 (free slot of bundle 72, 1152..1167)
src/plugins/uniso/lang/lang.rc2     its English text
src/common/salisotrack.h            comment line for feature 370 (rule unchanged)
src/saltests/saltests.cpp           TestIsoSessionDump_370: the dump's walk for the probe's cases
translations/*/uniso.slt, .origin   the refresh (stop-rules 2.13)
```

**Structure Decision**: existing plug-in structure; no new files outside `specs/`.

## Complexity Tracking

None.
