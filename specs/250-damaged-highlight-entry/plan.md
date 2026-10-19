# Implementation Plan: A damaged highlighting entry no longer hangs the start-up

**Branch**: `250-damaged-highlight-entry` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/250-damaged-highlight-entry/spec.md`

## Summary

`CMainWindow::LoadConfig` (`src/mainwnd2.cpp`) reads the panel item highlighting list with
`while (OpenKey(hHltKey, buf, hSubKey))`; the advance (`itoa(++i, buf, 10)`) and the close
(`CloseKey(hSubKey)`) sit only at the end of the branch for a readable `Masks` value, and the low-memory
path `continue`s past them. The fix moves the advance and the close to the end of every round, so an
entry that cannot be used is skipped once; an intact list loads as before.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI registry through the core's registry worker (`OpenKey`, `GetValue`,
`CloseKey`, `src/regwork.cpp`)
**Storage**: `HKCU\Software\Tandem Commander\0.1\Colors\Panel Items Hilighting\<n>` - layout unchanged
**Testing**: hidden-desktop probe `probe/hlt250_probe.ps1` (6 rows); `saltests` run as a regression
check (no `src/common/` change)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand.vcxproj`)
**Performance Goals**: none beyond "the start-up ends"
**Constraints**: no new UI string; no registry layout change; the save code untouched
**Scale/Scope**: one loop in one function

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | unchanged build; no new dependency |
| II. Backward compatibility | intact lists load exactly as before (probe CONTROL row); a damaged list, which never started, now starts |
| III. Incremental modernization | minimal local change |
| IV. Windows commitment | n/a |
| V. Plugin architecture | no plug-in interface touched |
| VI. UI consistency | no UI change; the existing error message stays (at most once per entry) |

Gate: PASS (before and after design).

## Project Structure

### Documentation (this feature)

```text
specs/250-damaged-highlight-entry/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/hlt250_probe.ps1, result_before.txt, result_after.txt
└── tasks.md
```

### Source Code (repository root)

```text
src/mainwnd2.cpp      CMainWindow::LoadConfig - the highlighting-list loop
```

**Structure Decision**: a single edit in the core loader. No `contracts/` - nothing external changes
(the registry layout and the plug-in interface stay as they are).

## Complexity Tracking

None.
