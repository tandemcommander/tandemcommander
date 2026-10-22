# Implementation Plan: A long single mask never overruns the mask group preparation

**Branch**: `298-mask-group-long-mask` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/298-mask-group-long-mask/spec.md`

## Summary

`CMaskGroup::PrepareMasks` (`src/masks.cpp`) cuts each mask of the group into `char maskBuf[MAX_PATH]` and
normalizes it into `char buf[MAX_PATH]` without a bound; a single mask of 260+ bytes (reachable at every
start through a plug-in's `ThumbnailMasks` registry value) overruns the stack. The two work buffers become
one heap block sized to the group text (`strlen + 1` each - neither step ever makes a mask longer than its
text). The cutting, trimming and normalizing move into a header-only rule `src/common/salmaskgroup.h`
(byte-for-byte the old algorithm), checked by saltests against a copy of the old code with unbounded
buffers. `::PrepareMask` (exported to plug-ins as `CSalamanderGeneral::PrepareMask`) calls the same rule;
its signature and contract stay.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143; core compiled with `/J` (char unsigned)
**Primary Dependencies**: none new (Win32 only)
**Storage**: N/A (no change to what is stored)
**Testing**: `saltests` (header rule), hidden-desktop probe `probe/mask298_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand.vcxproj`)
**Performance Goals**: one extra `malloc`/`free` per `PrepareMasks` call - negligible next to the per-mask
`malloc` the function already does
**Constraints**: no change of results for groups that prepared before (FR-003); plug-in ABI untouched
(FR-004); no new UI strings
**Scale/Scope**: one function in `src/masks.cpp`, one new header, one saltests block

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency, header-only rule - PASS |
| II Backward compatibility | identical results for every group that prepared before (saltests reference comparison); plug-in interface unchanged - PASS |
| III Incremental modernization | a local fix of one function - PASS |
| IV Windows commitment | Win32 only - PASS |
| V Plug-in architecture preservation | `PrepareMask` export unchanged in signature and contract - PASS |
| VI UI consistency | no UI change - PASS |

Standing rules: never cut a name or mask (FR-002 - kept whole); UTF-8 bytes handled as bytes exactly as
before (the rule casts to `unsigned char`, identical under `/J`).

## Project Structure

### Documentation (this feature)

```text
specs/298-mask-group-long-mask/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/mask-group-split.md
├── fix-log.md
├── probe/mask298_probe.ps1 (+ results)
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salmaskgroup.h     new: SalMaskGroupCutMask, SalMaskGroupTrimMask, SalPrepareMaskU8
src/masks.cpp                 PrepareMask -> SalPrepareMaskU8; PrepareMasks: heap work block, the rule
src/saltests/saltests.cpp     TestMaskGroupSplit298 (reference copy of the old algorithm)
```

**Structure Decision**: the existing core + `src/common` header + saltests layout (as feature 283).

## Complexity Tracking

No violations.
