# Implementation Plan: Registry Editor - Move of an HKCR key held by both halves

**Branch**: `406-regedt-hkcr-both-halves` | **Date**: 2026-11-07 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/406-regedt-hkcr-both-halves/spec.md`

## Summary

A Move of an HKCR key held by both halves deleted the source through HKCR, which removes only the
user's half (measured). Now, when 390's `GetHkcrHalves` finds both halves, the pure rule returns a
new `SAL_HKCR_DELETE_BOTH` and the end of `CopyOrMoveKeyRec` deletes the machine's half by its real
path - after checking that the copy holds all of it (no value hidden by a different user's value of
the same name, the same class name) - and then the user's half by its real path. Every failure is
the existing `IDS_REMOVESOURCE` box; a machine half the copy did not hold is refused there with
`ERROR_NOT_SUPPORTED`.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI registry functions (`RegOpenKeyExW`, `RegQueryInfoKeyW`,
`RegEnumValueW`, `RegQueryValueExW`, `RegDeleteKeyW`)
**Storage**: the Windows registry (the user's own keys; nothing of the product's configuration)
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/hkcr406_probe.ps1`, the probes of
390 / 292 / 294 / 296 / 297
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, plug-in `regedt` (`src/plugins/regedt/fs5.cpp`)
**Performance Goals**: one extra key open + value enumeration per moved key held by both halves
**Constraints**: no new UI string, no plug-in ABI change; never cut a path (390's joined path is
refused when it does not fit); fail closed
**Scale/Scope**: ~80 lines in `fs5.cpp`, ~20 in `salregkeyid.h`, ~15 checks

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency, no build change - PASS |
| II Backward compatibility | registry format and plug-in ABI unchanged; other operations unchanged (FR-006) - PASS |
| III Incremental modernization | a local change in the existing recursion - PASS |
| IV Windows commitment | WinAPI only - PASS |
| V Plug-in architecture | inside the `regedt` plug-in; header-only shared rule - PASS |
| VI UI consistency | the existing box and its buttons, no new text - PASS |

Re-checked after the design: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/406-regedt-hkcr-both-halves/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
└── probe/hkcr406_probe.ps1 (+ results)
```

No `contracts/`: no interface other code relies on changes (the plug-in ABI is untouched).

### Source Code

```text
src/common/salregkeyid.h        SAL_HKCR_DELETE_BOTH; SalRegHkcrDeleteHalf(TRUE, TRUE) = BOTH;
                                SalRegValueSame (type, size, bytes)
src/saltests/saltests.cpp       TestRegHkcrHalf390 updated, TestRegHkcrBoth406
src/plugins/regedt/fs5.cpp      HkcrMachineHalfCopied; SafeDeleteHkcrHalf(checkCopied);
                                CopyOrMoveKeyRec: BOTH = machine (checked), then user
```

## Callers (enumerated with Grep)

- `SalRegHkcrDeleteHalf`: only `CopyOrMoveKeyRec` (`fs5.cpp`) and `saltests`.
- `SafeDeleteHkcrHalf`: only `CopyOrMoveKeyRec`.
- `CopyOrMoveKeyRec` is reached by `CopyOrMoveKey` <- `CopyOrMoveFromFS` (F5 / F6, drag and drop)
  and Quick Rename of a key (`fs3.cpp`, a Move within the same parent). A Quick Rename of an HKCR key
  held by both halves left the machine's half under the old name too; it now gets the same
  both-halves delete (an improvement in the same direction; probe rows do not drive it - the target
  created through HKCR goes to the machine's half, access denied without elevation, research R4).

## Complexity Tracking

None.
