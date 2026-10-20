# Implementation Plan: case twins are addressed exactly

**Branch**: `261-case-twins-exact-match` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/261-case-twins-exact-match/spec.md`

## Summary

Four core sites take the first name equal ignoring case although a case-sensitive folder can hold
twins (a.txt, A.txt). One pure rule set in `src/common/salnamerun.h` (feature 230's header), with
`saltests` checks, decides them:

- **lookup by name** (`SalNamePickIndex`): the byte-identical item; else the one item equal by
  `SalNameEqualOrdinalCI` when it is the only one; else none. Used by the viewer's next / previous
  file (`fileswnb.cpp`, WM_USER_ENUMFILENAMES), the User Menu's second compare name
  (`mainwnd3.cpp`) and Ctrl+X ghosting in the other panel (`shellsup.cpp`).
- **Compare Directories pairing** (`SalHasCaseTwinInRun`, `SalTwinRunPairs`, `SalTwinRunOrder`,
  `SalTwinRunSlotCmp`): the lists are sorted by `CmpNameExt` (first key `RegSetStrICmpEx`). When
  the merge meets a run pair (one first key on both sides) and either run holds a twin, the run
  pair is paired as a set - byte-identical names, then case-only pairs between names without twins
  - and both runs of the comparison's copies are rearranged pairs first; the merge then compares
  positions. Without twins: `CmpNameExtIgnCase` as today (feature 232). The copies are sorted
  back to the panel's order before the marks are transferred by index. Used in the panel merge
  (`CmpDirsNames`, context `CCmpDirsRun`) and in the sub-folder check (`mainwnd5.cpp`).

## Technical Context

**Language/Version**: C++20, MSVC v143
**Primary Dependencies**: none new (`salunicode.h` ordinal comparison)
**Storage**: none
**Testing**: `saltests` (pure rules), hidden-desktop probe `probe/twin261_probe.ps1`, regression
probe `specs/232-compare-dirs-case-only-names/probe/cmp232_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core)
**Performance Goals**: Compare Directories adds at most 4 name comparisons per pair of equal names
(neighbour checks); lookups stay one linear pass
**Constraints**: no new UI strings; no plug-in ABI change; names compared as WTF-8 bytes
**Scale/Scope**: 4 call sites in 4 files + one header + tests

## Constitution Check

- I. Build Reproducibility: no new dependency, no build change. PASS
- II. Backward Compatibility: without twins every site behaves as before (FR-001, edge cases);
  configuration and registry untouched. PASS
- III. Incremental Modernization: a small header rule, sites changed in place. PASS
- IV. Windows Platform Commitment: unchanged. PASS
- V. Plugin Architecture Preservation: core only; `salnamerun.h` is core-only already. PASS
- VI. UI Consistency: no UI change. PASS

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/261-case-twins-exact-match/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md, fix-log.md
├── contracts/name-rules.md
└── probe/twin261_probe.ps1, result_before.txt, result_after.txt
```

### Source Code

```text
src/common/salnamerun.h      the rules (+ comment block for feature 261)
src/mainwnd5.cpp             Compare Directories: panel merge (files, dirs), sub-folder check
src/fileswnb.cpp             viewer next / previous: finding the remembered file
src/mainwnd3.cpp             User Menu compare name 2 from the other panel
src/shellsup.cpp             Ctrl+X ghosting in the other panel (dirs, files)
src/saltests/saltests.cpp    checks of the rules, a merge simulation
```

**Structure Decision**: existing core files; the rules join feature 230's header.

## Complexity Tracking

None.
