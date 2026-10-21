# Implementation Plan: The information line survives running out of memory as its text grows

**Branch**: `293-infoline-realloc-pair` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/293-infoline-realloc-pair/spec.md`

## Summary

`CStatusWindow::SetText` (src/stswnd.cpp) grows two parallel buffers - `Text` (bytes) and `AlpDX`
(one `int` per byte) - with two `realloc` calls and stores the results only when both succeed. A
successful first call that moved the block, followed by a failed second one (or the reverse), leaves
the window pointing at a released block. The growth moves into a header-only rule
`src/common/salgrowpair.h` (`SalGrowBufferPair`): each successful result is stored at once, the
recorded capacity rises only when both buffers hold the new size, and a block newly obtained for a
buffer that had none is released again on failure (so a fresh line stays empty instead of holding an
unterminated block). The rule takes the allocator as a parameter, which is the low-memory seam for
`saltests`; `SetText` calls it with the CRT `realloc` / `free`.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new (CRT `realloc` / `free`)
**Storage**: N/A (in-memory buffers of a window)
**Testing**: `saltests` (header-only rule with an injected failing allocator); reading proof in fix-log
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `tandemcommander.exe`)
**Performance Goals**: unchanged - same number of allocations on the success path
**Constraints**: behaviour identical when memory is available; no new UI strings; no ABI change
**Scale/Scope**: one function in src/stswnd.cpp, one new header, one test function

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency, header-only; saltests project unchanged except one include and one test |
| II. Backward compatibility | no stored data, no plug-in interface change; success path identical |
| III. Incremental modernization | one rule extracted into a tested header, callers unchanged |
| IV. Windows commitment | CRT only |
| V. Plug-in architecture | untouched (`CStatusWindow` is core-only) |
| VI. UI consistency | no UI change; the old text stays shown on failure as before |

Gate: PASS (before and after design).

## Project Structure

### Documentation (this feature)

```text
specs/293-infoline-realloc-pair/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salgrowpair.h      # new: SalGrowBufferPair (header-only, allocator injected)
src/stswnd.cpp                # CStatusWindow::SetText uses it
src/saltests/saltests.cpp     # TestGrowBufferPair293: failing-allocator seam
```

**Structure Decision**: the pure rule lives in `src/common/` as the standing rules ask ("put pure
decisions in a header under src/common with saltests checks"); `saltests` already compiles headers
from that folder (its include list).

## Complexity Tracking

None.
