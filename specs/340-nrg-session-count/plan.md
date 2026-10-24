# Implementation Plan: An NRG image whose session counts do not fit its tracks is listed within its tracks and kept

**Branch**: `340-nrg-session-count` | **Date**: 2026-10-24 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/340-nrg-session-count/spec.md`

## Summary

The ISO plug-in's "Session NN" listing (`CISOImage::ListTracks`, `src/plugins/uniso/isoimage.cpp`) takes
each session's track count from the image (NRG SINF chunks, stored as `int`) and walks the track table
for that many tracks without a bound. A new pure rule `SalIsoSessionTracks` in
`src/common/salisotrack.h` gives the number of tracks a session really gets - its count read as an
unsigned 32-bit number, at most the tracks left from where the session starts - and whether the count
fits. `ListTracks` walks only those tracks and marks the listing incomplete (328's `ListingLeftOut`)
when a count does not fit. saltests checks the rule; the probe `iso340_probe.ps1` drives five damaged
images and two controls.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new; the uniso plug-in, `src/common/salisotrack.h` (header-only, 334)  
**Storage**: N/A  
**Testing**: saltests (pure rule), hidden-desktop probe `specs/340-nrg-session-count/probe/iso340_probe.ps1`
(seeds by 334's `mkimg334.sh` in WSL Ubuntu, images by `img340.py`); regression: 334's and 335's probes  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (`uniso.spl`)  
**Performance Goals**: N/A (one comparison a session)  
**Constraints**: plug-in ABI untouched; no UI string (no `.slt` refresh); uniso includes common headers as
`../../common/...` (331's trap)  
**Scale/Scope**: one function of one plug-in + one inline rule + checks

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency, no project change (header-only rule) - PASS |
| II. Backward compatibility (baseline 0.1.0) | images whose counts fit behave as before (F-FIT, F-ZERO, 334 / 335 probes); no settings, registry or ABI change - PASS |
| III. Incremental modernization | a local bound in one loop, a pure rule with checks - PASS |
| IV. Windows commitment | unchanged - PASS |
| V. Plugin architecture preservation | no change to `spl_*.h` or `LAST_VERSION_OF_SALAMANDER` - PASS |
| VI. UI consistency | no new box or text; the existing "incomplete listing" path - PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/340-nrg-session-count/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/ (iso340_probe.ps1, img340.py, result_*.txt)
```

No `contracts/`: the change is internal to the plug-in (no interface other code or plug-ins rely on).

### Source Code (repository root)

```text
src/common/salisotrack.h           # + SalIsoSessionTracks (feature 340)
src/plugins/uniso/isoimage.cpp     # CISOImage::ListTracks uses it, marks a count that does not fit
src/saltests/saltests.cpp          # + TestIsoSessionTracks_340
```

**Structure Decision**: the existing layout; the rule joins 334's header, which uniso already includes.

## Complexity Tracking

None.
