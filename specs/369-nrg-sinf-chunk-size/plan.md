# Implementation Plan: NRG SINF chunks read by their size

**Branch**: `369-nrg-sinf-chunk-size` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/369-nrg-sinf-chunk-size/spec.md`

## Summary

The ISO plug-in's NRG chunk loop (`ReadNRGRoot`, `src/plugins/uniso/nrg.cpp`) reads the next chunk
header wherever the previous reader left the file position; `readSINF` always reads 4 bytes. Fix: a
pure rule `SalNrgSinfUsable(pos, size, fileSize)` (`src/common/salnrgcdtext.h`, exactly 4 bytes and
within the image) decides whether a SINF chunk gives a count; a refused or short-read SINF chunk adds no
count and marks `iso->ListingLeftOut` incomplete; and `ReadNRGRoot` remembers each known chunk's start
and seeks to `start + Size` after its reader. ETN2 needs nothing (feature 365).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; `salnrgcdtext.h` (header-only, uniso + saltests)
**Storage**: N/A
**Testing**: `saltests` (`TestNrgSinf369`), hidden-desktop probe `iso369_probe`; regression probes
`iso340_probe`, `nrg350_probe`, `iso365_probe`
**Target Platform**: Windows 11 x64
**Project Type**: desktop app plug-in (uniso)
**Performance Goals**: N/A (one extra seek per chunk)
**Constraints**: plug-in ABI untouched; no UI string; no registry change
**Scale/Scope**: two files of code + the test file

## Constitution Check

- I Build reproducibility: no new dependency, header-only rule - PASS.
- II Backward compatibility: well-formed images read as before (probes 340 / 350 / 365) - PASS.
- III Incremental modernization: local fix, rule in `src/common/` with tests - PASS.
- IV Windows commitment: unchanged - PASS.
- V Plugin architecture: no interface change (`spl_*.h` untouched) - PASS.
- VI UI consistency: no new box, no string; the existing incomplete-listing behaviour - PASS.

Re-check after design: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/369-nrg-sinf-chunk-size/
├── plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md
└── probe/  img369.py, iso369_probe.ps1, result_*.txt
```

### Source Code (repository root)

```text
src/common/salnrgcdtext.h        SAL_NRG_SINF_SIZE, SalNrgSinfUsable
src/plugins/uniso/nrg.cpp        readSINF (refuse + mark), ReadNRGRoot (seek to the chunk's end)
src/saltests/saltests.cpp        TestNrgSinf369
```

**Structure Decision**: existing layout; no new file in the source tree.

## Complexity Tracking

None.
