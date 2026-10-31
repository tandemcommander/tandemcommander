# Implementation Plan: An NRG image's CUEX chunk gives only the tracks it holds

**Branch**: `350-nrg-cuex-bounds` | **Date**: 2026-10-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/350-nrg-cuex-bounds/spec.md`

## Summary

`readCUEX` (`src/plugins/uniso/nrg.cpp`) takes its entry count from `(Size - 16) / 16` in unsigned
32-bit arithmetic and reads entries until the count is reached or a read fails, never checking the
chunk against the image or how many bytes a read returned. Fix: a pure rule
`SalNrgCuexEntryCount(size)` (0 under 16 bytes, else `(size - 16) / 16`) in
`src/common/salnrgcdtext.h` with `saltests` checks; `readCUEX` skips a chunk that does not lie within
the image (`SalNrgChunkFits`, as 331's `readCDTX`), checks every read's length, makes no track from a
short read, and seeks to the chunk's end after its entries.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143  
**Primary Dependencies**: none new; the uniso plug-in's `CFile` (`Read`, `Seek`, `GetFileSize`)  
**Storage**: N/A  
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/nrg350_probe.ps1` (images by
`probe/img350.py`); regression: feature 329's A-OPEN row  
**Target Platform**: Windows 11 x64  
**Project Type**: desktop application plug-in (uniso)  
**Performance Goals**: a damaged image opens within seconds and within 150 MB of an intact one's peak
memory (SC-001)  
**Constraints**: plug-in ABI unchanged; header-only rule (uniso includes `src/common` headers as
`../../common/...`, 331)  
**Scale/Scope**: one reader function, one header function, one test function

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | No new dependency; vendored only. PASS |
| II. Backward compatibility | Well-formed images give the same tracks (FR-005, N-OK, 329 A-OPEN). PASS |
| III. Incremental modernization | A local bound in one reader, a pure rule with tests. PASS |
| IV. Windows commitment | Unchanged. PASS |
| V. Plugin architecture | No change to `spl_*.h`, no ABI change. PASS |
| VI. UI consistency | No UI text, dialog or menu changes - no `.slt` refresh. PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/350-nrg-cuex-bounds/
├── plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/ (img350.py, nrg350_probe.ps1, result_*.txt)
```

No `contracts/`: the change is internal to the plug-in (no interface another component relies on).

### Source Code (repository root)

```text
src/common/salnrgcdtext.h        # + SalNrgCuexEntryCount (feature 350)
src/plugins/uniso/nrg.cpp        # readCUEX bounded
src/saltests/saltests.cpp        # + TestNrgCuex350
```

**Structure Decision**: the existing layout; the rule joins 331's NRG rules in the same header.

## Complexity Tracking

None.
