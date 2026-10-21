# Implementation Plan: Registry Editor - Move of a key and the "class name differs" question

**Branch**: `287-regedt-move-class-name` | **Date**: 2026-10-21 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/287-regedt-move-class-name/spec.md`

## Summary

The Registry Editor's Copy/Move of a key (`CopyOrMoveKey`, `src/plugins/regedt/fs5.cpp`) reads
the target key's class name through the **source** key's handle, so its "class name differs"
question never appears. The fix passes the target key's handle (`targetHKey`, opened with
`KEY_WRITE | KEY_READ` by `SafeCreateKey` just before). The buffer-size defect the item names in
`fs3.cpp` was fixed by feature 131 - recorded, not changed. A hidden-desktop probe drives Move of
a key with a Czech name and the class-name question in Czech and English, and is run on the build
before the fix (the question rows must FAIL there) and after.

## Technical Context

**Language/Version**: C++20, MSVC v143; the probe in Windows PowerShell 5.1 (pure ASCII source)
**Primary Dependencies**: the Registry Editor plug-in (`src/plugins/regedt`), the core's
`DialogQuestion` (`CHiddenOrSystemDlg`, `IDD_QUESTION3`: Yes / All / Cancel); the probe helpers of
`specs/098-long-path-overruns/probe/fix_probe_lib.ps1` and `specs/124-regedt-key-text/probe/shotocr_lib.ps1`
**Storage**: the Windows registry - only the probe's fixture key `HKCU\Software\TcProbe287` and the
product's key (backed up, restored, SHA-256 verified)
**Testing**: hidden-desktop probe `specs/287-regedt-move-class-name/probe/move287_probe.ps1`;
regression: `specs/129-regedt-wide-inserts/probe/wide_probe.ps1`; `saltests` (core unchanged, run
as a control); `tools/check_encoding.py --strict`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (plug-in DLL)
**Performance Goals**: none - one extra `RegQueryInfoKeyW` per key was already made (on the wrong handle)
**Constraints**: no new UI strings (no `.slt` refresh), no plug-in interface change, nothing stored
**Scale/Scope**: one argument in one function, one new probe

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | no new dependency, no project change | PASS |
| II. Backward compatibility | no stored data, no interface change. The only behaviour change is a defect fix, not a new feature: the question the code was written to ask (since Open Salamander) appears, and only in the one case where the target would otherwise silently lose the source's class name; Cancel copies and deletes nothing, Yes gives the old result. Not gated: nobody can rely on a check that compares a key with itself | PASS |
| III. Incremental modernization | a minimal change at the defect | PASS |
| IV. Windows commitment | Win32 registry API | PASS |
| V. Plug-in architecture | inside one plug-in; no `spl_*.h` change | PASS |
| VI. UI consistency | the existing question dialog and its translated text | PASS |

Re-checked after Phase 1: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/287-regedt-move-class-name/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/probe-rows.md   # what each probe row asserts
├── fix-log.md                # running log
└── probe/                    # move287_probe.ps1 and its results
```

### Source Code (repository root)

```text
src/plugins/regedt/fs5.cpp    # CopyOrMoveKey: the target's class name from targetHKey
```

**Structure Decision**: the change stays at its one site; no header under `src/common/` (the
decision "do the class names differ" is the existing `CompareStringW` call - nothing new to test
without the registry).

## Complexity Tracking

None.
