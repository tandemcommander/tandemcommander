# Implementation Plan: Registry Editor - Copy / Move of a key into the key above its parent

**Branch**: `294-regedt-move-above-parent` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/294-regedt-move-above-parent/spec.md`

## Summary

`CPluginFSInterface::CopyOrMoveFromFS` refuses a target key that is the source or lies inside it
(text, and identity since 292), but not a target key that holds the source. The recursive copy
(`CopyOrMoveKey`) writes `target\P` for every subkey path `P` of the source; when the target holds
the source at `target\R`, every `P` that begins with `R` lands inside the source - and Move deletes
the source at the end (measured: x=3 lost). The key check gets a third test: for every pair of
identities where the source lies strictly inside the target, take the path `R` below the target
(new pure function `SalRegKeyIdBelow` in `src/common/salregkeyid.h`) and open `source\R`; if it
exists the key is refused with the existing "into itself" message (OK = skip, Cancel = stop) before
anything is written. An open error other than "not found" goes through the existing open-error box
(fails closed). A merge into the key above the parent without the repeated chain stays allowed. No
UI text, no plug-in interface change.

## Technical Context

**Language/Version**: C++20 (MSVC v143), WinAPI
**Primary Dependencies**: advapi32 (registry); feature 292's identity helpers in `fs5.cpp`
**Storage**: the Windows registry (what the user copies / moves); nothing of the product's own
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/above294_probe.ps1`; feature 292's
probe `alias292_probe.ps1` as regression
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, plug-in `regedt.spl`
**Performance Goals**: at most one extra key open per selected key whose target holds it - none
otherwise
**Constraints**: refuse before anything is written; never a cut path (heap-joined path); no new UI
strings (a run cannot refresh `.slt`); header-only shared code
**Scale/Scope**: `src/plugins/regedt/fs5.cpp` (the key check + one helper), `salregkeyid.h` (one
function), `saltests`

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no build change; header-only; no new library |
| II Backward compatibility | only Copy / Move that write into the source (Move: data lost) are now refused; every other result unchanged (probe controls FLATTEN, FLATCOPY, MOVE, MOVESELF; 292's probe) |
| III Incremental modernization | one check added beside 292's in `CopyOrMoveFromFS` |
| IV Windows commitment | WinAPI only |
| V Plug-in architecture | no `spl_*.h` change, no interface version change |
| VI UI consistency | existing message boxes only |

Gate: PASS (also after Phase 1).

## Project Structure

### Documentation (this feature)

```text
specs/294-regedt-move-above-parent/
├── spec.md  plan.md  research.md  data-model.md  quickstart.md
├── contracts/key-below.md
├── probe/above294_probe.ps1 (+ results)
├── fix-log.md
└── tasks.md
```

### Source Code

```text
src/common/salregkeyid.h          + SalRegKeyIdBelow (the path of one identity below another)
src/plugins/regedt/fs5.cpp        + SafeRegKeyHoldsPath helper; the key check of CopyOrMoveFromFS
src/saltests/saltests.cpp         + TestRegKeyIdBelow294
```

**Structure Decision**: existing layout; extends feature 292's header and check.

## Complexity Tracking

None.
