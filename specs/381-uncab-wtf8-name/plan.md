# Implementation Plan: UnCAB - a cabinet name with an unpaired surrogate no longer fails the whole cabinet

**Branch**: `381-uncab-wtf8-name` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/381-uncab-wtf8-name/spec.md`

## Summary

`CabNameToU8` (`src/plugins/uncab/uncab.cpp`) decides how a stored cabinet name is read with a strict
UTF-8 test (`MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS)`), which rejects the WTF-8 form of an
unpaired surrogate; a rejected flagged name aborts `FDICopy`. The decision moves into a header-only
rule `src/plugins/uncab/cabname.h` (`CabNameReadAs`: as UTF-8 / in the code page / refuse) whose
validity test is a new plug-in helper `SplIsWtf8` (`src/plugins/shared/splunicode.h`) - exactly the
WTF-8 decoder the plug-in helpers already use (feature 089), which `saltests` checks against the
core's. `CabNameToU8` keeps its byte-for-byte copy, its buffer check and its code-page branch.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: Windows SDK FDI (`fdi.h`, cabinet.dll), `splunicode.h` (header-only)
**Storage**: N/A
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/cab381_probe.ps1` with the fixture
writer `probe/cab381.py`, `tools/check_encoding.py --plugins`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (plug-in)
**Performance Goals**: none (one decode per entry name, as today)
**Constraints**: plug-in ABI untouched; no UI string change (no `.slt` refresh); never cut a name
**Scale/Scope**: one function in one plug-in, one helper, one rule header, unit checks

## Constitution Check

| Principle | Check |
|---|---|
| I. Build reproducibility | no new dependency; header-only additions; vendored nothing new - PASS |
| II. Backward compatibility | every name accepted today is accepted with the same bytes (WTF-8 is a superset of strict UTF-8); refused malformed names stay refused; code-page names unchanged - PASS |
| III. Incremental modernization | one decision site, behind a tested rule - PASS |
| IV. Windows commitment | Win32 only - PASS |
| V. Plugin architecture | no change to `spl_*.h` or `LAST_VERSION_OF_SALAMANDER`; `splunicode.h` gains an inline helper (compile-time, no ABI) - PASS |
| VI. UI consistency | no UI change - PASS |

Post-design re-check: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/381-uncab-wtf8-name/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/cab-name-decoding.md
├── fix-log.md
└── probe/  cab381.py, cab381_probe.ps1, result_*.txt
```

### Source Code (repository root)

```text
src/plugins/shared/splunicode.h   + SplIsWtf8()
src/plugins/uncab/cabname.h       new: CabNameReadAs() (header-only rule)
src/plugins/uncab/uncab.cpp       CabNameToU8 uses CabNameReadAs
src/saltests/saltests.cpp         + TestCabName381
```

**Structure Decision**: the rule is UnCAB-specific, so it lives with the plug-in; `saltests` includes
it by relative path as it already includes `../plugins/shared/splunicode.h`.

## Complexity Tracking

None.
