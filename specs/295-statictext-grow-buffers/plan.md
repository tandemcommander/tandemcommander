# Implementation Plan: A dialog's status text and the panel's size field survive running out of memory

**Branch**: `295-statictext-grow-buffers` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/295-statictext-grow-buffers/spec.md`

## Summary

`CStaticText::SetText` (src/gui.cpp) grows `Text` and `TextW`, and with an ellipsis style also
`AlpDX`, `Text2` and `Text2W`, with up to five `realloc` calls; when a later call fails it `free`s
the earlier successful results (one of which `Text` may still refer to) and returns with `TextW`
already replaced - the control is left with released blocks. The growth moves onto a variadic form
of feature 293's rule in `src/common/salgrowpair.h`: `SalGrowBuffers` grows any number of buffers,
each with its own element type and an extra element count over the shared capacity (3 for the two
"..." buffers); each successful result is stored at once, the capacity rises only when all grew, a
fresh block of a buffer that had none is released again. `SalGrowBufferPair` becomes the two-buffer
case of it (same calls, same order, same results), so feature 293's `saltests` keep checking it.
`CStatusWindow::SetSize` (src/stswnd.cpp) gets the missing `malloc` check before its first write.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new (CRT `realloc` / `free`)
**Storage**: N/A (in-memory buffers of a control)
**Testing**: `saltests` (header-only rule with feature 293's failing fake heap); reading proof in fix-log
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `tandemcommander.exe`)
**Performance Goals**: unchanged - same allocations, same sizes on the success path
**Constraints**: behaviour identical when memory is available; no new UI strings; no ABI change
**Scale/Scope**: one function in src/gui.cpp, one in src/stswnd.cpp, the header, one test function

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency, header-only; saltests gets one test function |
| II. Backward compatibility | no stored data, no plug-in interface change (`CStaticText` is core-internal; plug-ins reach it through `CGUIStaticTextAbstract`, whose `SetText` contract - TRUE / FALSE - is unchanged); success path identical |
| III. Incremental modernization | an existing tested rule generalized, callers unchanged |
| IV. Windows commitment | CRT only |
| V. Plug-in architecture | untouched |
| VI. UI consistency | no UI change; the old text stays shown on failure as before |

Gate: PASS (before and after design).

## Project Structure

### Documentation (this feature)

```text
specs/295-statictext-grow-buffers/
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
src/common/salgrowpair.h      # + SalGrowBuffers (variadic), SalGrowBuf; SalGrowBufferPair on top of it
src/gui.cpp                   # CStaticText::SetText grows its 2 / 5 buffers with SalGrowBuffers
src/stswnd.cpp                # CStatusWindow::SetSize checks malloc before writing
src/saltests/saltests.cpp     # TestGrowBuffers295: five buffers of three types, chosen calls failing
```

**Structure Decision**: the pure rule stays in `src/common/salgrowpair.h` (feature 293's home of
it; the file name is kept so the existing includes stay valid). No contract: nothing outside the
core uses the header.

## Complexity Tracking

None.
