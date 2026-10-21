# Implementation Plan: Registry Editor - Copy / Move of a key onto itself through another root name

**Branch**: `292-regedt-alias-move-self` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/292-regedt-alias-move-self/spec.md`

## Summary

The Registry Editor's Copy / Move decides "onto itself" by the root index and the key path text, so
the same key written under another root name (`HKEY_USERS\<SID>` for `HKCU`, `HKCR` for
`HKCU\Software\Classes`, `HKCC`, registry links) passes, and Move deletes the only copy. Both checks
of `CopyOrMoveFromFS` (target folder = panel folder; target key inside the source key) get a second
test by identity - the full internal name the registry reports for the opened key (research R1-R3)
- with the pure comparison in a new header `src/common/salregkeyid.h` checked by `saltests`. An
identity that cannot be established fails closed through the existing error boxes. No UI text, no
plug-in interface change.

## Technical Context

**Language/Version**: C++20 (MSVC v143), WinAPI
**Primary Dependencies**: advapi32 (registry), ntdll `NtQueryKey` / `RtlNtStatusToDosError` by `GetProcAddress`
**Storage**: the Windows registry (what the user copies / moves); nothing of the product's own
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/alias292_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, plug-in `regedt.spl`
**Performance Goals**: two to four extra key opens per operation / selected key - not measurable
**Constraints**: never delete a key whose identity was not established; no new UI strings (a run
cannot refresh `.slt`); header-only shared code (the plug-in cannot compile `src/common/*.cpp`)
**Scale/Scope**: `src/plugins/regedt/fs5.cpp` (one function + helpers), one new header, `saltests`

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no build change; header-only; no new library |
| II Backward compatibility | only operations that destroyed data or nested a key into itself are now refused; every other result unchanged (probe controls) |
| III Incremental modernization | changes limited to the two checks and new helpers in `fs5.cpp` |
| IV Windows commitment | WinAPI / ntdll only |
| V Plug-in architecture | no `spl_*.h` change, no interface version change |
| VI UI consistency | existing message boxes only |

Gate: PASS (also after Phase 1).

## Project Structure

### Documentation (this feature)

```text
specs/292-regedt-alias-move-self/
├── spec.md  plan.md  research.md  data-model.md  quickstart.md
├── contracts/key-identity.md
├── probe/alias292_probe.ps1 (+ results)
├── fix-log.md
└── tasks.md
```

### Source Code

```text
src/common/salregkeyid.h          new - the pure identity rule (header-only)
src/plugins/regedt/precomp.h      includes it
src/plugins/regedt/fs5.cpp        GetRegKeyIds / QueryRegKeyId helpers; the two checks
src/saltests/saltests.cpp         TestRegKeyId292
```

**Structure Decision**: existing layout; the rule follows `salregfind.h` (feature 257).

## Complexity Tracking

None.
