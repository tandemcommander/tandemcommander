# Implementation Plan: "*.ext" masks match accented extensions by whole letters

**Branch**: `283-mask-code-page-fold` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/283-mask-code-page-fold/spec.md`

## Summary

`CMaskGroup::PrepareMasks` (src/masks.cpp) classifies a prepared mask as `MASK_OPTIMIZE_ALL`
(`*`, `*.*`), `MASK_OPTIMIZE_EXTENSION` (`*.xxx`, no wildcard and no dot after `*.`) or
`MASK_OPTIMIZE_NONE`. `CMaskGroup::AgreeMasks` answers EXTENSION masks with
`StrICmp(ext, mask + 3)` and, with ten or more of them, through a table keyed by
`COMPUTEMASKGROUPHASH` - both fold bytes through the code-page `LowerCase` table, which on UTF-8
misses the other case of an accented letter and confuses unrelated letters (measured, spec
*Background*).

Fix: the classification moves into a pure header `src/common/salmaskopt.h`
(`SalMaskOptimizeKind`) with one added condition - **an extension that is not all ASCII is not
an EXTENSION mask** (it becomes NONE and goes through `AgreeMask`, the whole-letter matcher every
other non-ASCII mask uses). `PrepareMasks` calls the header; everything else stays. ASCII masks
keep the shortcut and the table byte for byte. saltests checks the classification, a differential
against the old classification for every ASCII extension, the measured fold defects of the old
shortcut (an emulated CP1250 table), and that no UTF-8 continuation byte folds to ASCII in any
ANSI code page (so an ASCII shortcut mask can never equal a non-ASCII extension).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: none new; `src/common/` header-only rule
**Storage**: N/A (no registry, no file format)
**Testing**: `saltests` (new checks), hidden-desktop probe `probe/mask283_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand.vcxproj`)
**Performance Goals**: ASCII mask groups unchanged (same shortcut, same table)
**Constraints**: plug-in ABI unchanged (`CSalamanderMaskGroup` keeps its methods, only its answer for accented `*.xxx` masks is corrected); no UI strings
**Scale/Scope**: one function's classification in `masks.cpp`, one new header, saltests

## Constitution Check

- I Build reproducibility: a header + one call; no new dependency. PASS
- II Backward compatibility (0.1.0): every ASCII mask decides as before (differential check); stored masks unchanged; accented `*.xxx` masks now give the answer the general matcher always gave for other accented masks - a defect fix. PASS
- III Incremental modernization: rule extracted into `src/common/` with tests, the call site minimal. PASS
- IV Windows commitment: PASS
- V Plug-in architecture: interface and version untouched (`LAST_VERSION_OF_SALAMANDER` stays). PASS
- VI UI consistency: no UI change. PASS

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/283-mask-code-page-fold/
├── plan.md, research.md, data-model.md, quickstart.md
├── contracts/mask-optimize-kind.md
├── fix-log.md, closing-report.md (later)
├── probe/mask283_probe.ps1, result_*.txt
└── tasks.md
```

### Source Code (repository root)

```text
src/common/salmaskopt.h      # new: SalMaskOptimizeKind (pure, header-only)
src/masks.cpp                # PrepareMasks calls it; comments at the StrICmp / hash sites
src/saltests/saltests.cpp    # checks
```

**Structure Decision**: the project's pattern for pure decisions (a header under `src/common/` +
saltests, e.g. 141 `salmaskname.h`).

## Complexity Tracking

None.
