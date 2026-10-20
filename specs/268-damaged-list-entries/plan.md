# Implementation Plan: A damaged viewer, editor or User Menu entry no longer erases the entries after it

**Branch**: `268-damaged-list-entries` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/268-damaged-list-entries/spec.md`

## Summary

Three start-up loaders read a numbered list with `while (OpenKey(listKey, buf, subKey))`:
`LoadViewers` and `LoadEditors` (`src/salamdr2.cpp`; viewers twice - `Viewers` and
`Alternative Viewers`) and the User Menu block of `CMainWindow::LoadConfig` (`src/mainwnd2.cpp`).
Each uses an entry only when its required values are readable and otherwise `else break;` - before
the advance (`itoa(++i, buf, 10)`) and the close (`CloseKey(subKey)`). The saves clear the list key
and rewrite it from what was loaded, so the entries after a damaged one are erased on exit. The fix
drops the `else break;` (a damaged entry falls through to the advance and the close, so it is
skipped) and adds `CloseKey(subKey)` before each low-memory `break`, which keeps ending the list.
The body for a readable entry is unchanged. In the User Menu a pure rule (`src/common/salumbalance.h`,
`CSalUMSubmenuBalance`, saltests checks) keeps the submenus balanced: a skipped damaged submenu
beginning takes its matching end along, a damaged end is loaded as a plain end (added after the
review, which found that a skipped beginning left a stray end).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: the core's registry worker (`OpenKey`, `GetValue`, `CloseKey`,
`src/regwork.cpp`)
**Storage**: `HKCU\Software\Tandem Commander\0.1\Viewers`, `\Alternative Viewers`, `\Editors`,
`\User Menu` - `<n>` subkeys; layout unchanged
**Testing**: hidden-desktop probe `probe/dmg268_probe.ps1` (16 cases, 64 rows); `saltests` checks of
the balance rule (`TestUserMenuBalance268`)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand.vcxproj`)
**Performance Goals**: none (start-up time unchanged)
**Constraints**: no new UI string; no registry layout change; the save code untouched; the low-memory
paths keep ending the list
**Scale/Scope**: three loops in two files

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | unchanged build; no new dependency |
| II. Backward compatibility | intact lists load exactly as before (probe CONTROL rows); old-version conversions untouched |
| III. Incremental modernization | minimal local change, same idiom as feature 250 |
| IV. Windows commitment | n/a |
| V. Plugin architecture | no plug-in interface touched; viewers of plug-ins are stored in the same list and load as before |
| VI. UI consistency | no UI change; the existing "Error Loading Configuration" message stays |

Gate: PASS (before and after design).

## Project Structure

### Documentation (this feature)

```text
specs/268-damaged-list-entries/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── fix-log.md
├── probe/dmg268_probe.ps1, result_before.txt, result_after.txt
└── tasks.md
```

### Source Code (repository root)

```text
src/salamdr2.cpp      LoadViewers, LoadEditors - the entry loops
src/mainwnd2.cpp      CMainWindow::LoadConfig - the User Menu loop
src/common/salumbalance.h   the User Menu submenu balance rule (header-only)
src/saltests/saltests.cpp   TestUserMenuBalance268; src/vcxproj/saltests/saltests.vcxproj lists the header
```

**Structure Decision**: edits in the core loaders only. No `contracts/` - nothing external changes
(the registry layout and the plug-in interface stay as they are). The skip itself is the loops' control
flow around registry calls, driven end to end by the probe (as in 250); the submenu balance is a pure
decision and lives in `src/common/salumbalance.h` with saltests checks.

## Complexity Tracking

None.
