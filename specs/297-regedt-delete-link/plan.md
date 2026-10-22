# Implementation Plan: Registry Editor - Delete / Move of a key holding a registry link

**Branch**: `297-regedt-delete-link` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/297-regedt-delete-link/spec.md`

## Summary

The delete recursion `CPluginFSInterface::DeleteKey` (`src/plugins/regedt/fs3.cpp`) and the Move's
recursion `CopyOrMoveKeyRec` (`fs5.cpp`, ending with `SafeDeleteKey`) open, enumerate and delete
every key by name, which follows a registry link standing at that name: the key the link points at
is emptied and deleted, the link stays (measured: 14 FAIL rows, the target `Jinde` lost in 7).

One shared test opens a key's name as a link (`REG_OPTION_OPEN_LINK`, `KEY_QUERY_VALUE`) and reads
its `SymbolicLinkValue` (type `REG_LINK` = a link) - the test feature 296 wrote inline in
`SafeCheckTargetLink`, moved into a helper that 296's check uses too (same results).

- **Delete**: at the start of each `DeleteKey` level, a link is removed as the link itself - opened
  with `REG_OPTION_OPEN_LINK` and `DELETE`, re-checked to be a link on that handle, deleted with
  `NtDeleteKey` (ntdll, by `GetProcAddress`, as 292's `NtQueryKey`); no enumeration, nothing below.
  Errors go through the existing "Unable to delete a registry key." / "Unable to open a registry key."
  box (Retry / Skip / Skip All / Cancel).
- **Move / drag and drop / Quick Rename**: at the start of each `CopyOrMoveKeyRec` level of a Move,
  before the source is opened for copying and before anything is written, a link source key is
  refused with the existing box `IDS_REMOVESOURCE` + `ERROR_NOT_SUPPORTED`; Retry checks again, Skip
  leaves the link (its parents then stay, as for any skipped key), Cancel stops.
- **Copy** and every key that is no link: unchanged.

No UI text, no plug-in interface change.

## Technical Context

**Language/Version**: C++20 (MSVC v143), WinAPI
**Primary Dependencies**: advapi32 (`REG_OPTION_OPEN_LINK`, `REG_LINK`), ntdll `NtDeleteKey` /
`RtlNtStatusToDosError` by `GetProcAddress` (precedent: 292's `NtQueryKey`)
**Storage**: the Windows registry (what the user deletes / moves); nothing of the product's own
**Testing**: hidden-desktop probe `probe/link297_probe.ps1` (real links under HKCU and the user's
classes hive); 296's, 294's and 292's probes as regression; `saltests` (no pure rule changes)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application, plug-in `regedt.spl`
**Performance Goals**: one extra key open (and value query) per deleted / moved key
**Constraints**: decide before anything of the key is enumerated, written or deleted; fails closed;
no new UI strings; names shown whole (the existing boxes)
**Scale/Scope**: `src/plugins/regedt/fs3.cpp`, `fs5.cpp`, `regedt.h`

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no build change; no new library (ntdll already used by 292) |
| II Backward compatibility | keys that are no links behave as before (probe DEL, MOVE, COPYTREE; 292 / 294 / 296 probes) |
| III Incremental modernization | one helper, reused by 296's check instead of a second copy |
| IV Windows commitment | WinAPI / native API only |
| V Plug-in architecture | no `spl_*.h` change, no interface version change |
| VI UI consistency | existing error boxes only |

Gate: PASS (also after Phase 1).

## Project Structure

### Documentation (this feature)

```text
specs/297-regedt-delete-link/
├── spec.md  plan.md  research.md  data-model.md  quickstart.md
├── contracts/source-link-handling.md
├── probe/link297_probe.ps1 (+ results)
├── fix-log.md
└── tasks.md
```

### Source Code

```text
src/plugins/regedt/fs5.cpp   + RegKeyIsLink (open as a link, read SymbolicLinkValue) - used by
                               SafeCheckTargetLink (296) instead of its inline test
                             + SafeRegKeyIsLink (RegKeyIsLink with the open-error box)
                             + SafeDeleteRegLink (OPEN_LINK + DELETE, re-check, NtDeleteKey; box)
                             CopyOrMoveKeyRec: a Move refuses a link source key first
src/plugins/regedt/fs3.cpp   DeleteKey: a link is removed as the link itself
src/plugins/regedt/regedt.h  declarations of the two Safe* helpers
```

**Structure Decision**: existing layout; extends feature 296 in the same files.

## Complexity Tracking

None.
