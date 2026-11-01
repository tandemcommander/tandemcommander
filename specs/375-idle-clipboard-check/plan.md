# Implementation Plan: Switching back to the program never waits for a busy clipboard

**Branch**: `375-idle-clipboard-check` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/375-idle-clipboard-check/spec.md`

## Summary

Measured (fix-log): the ~140 ms block after an activation happens while another program keeps
the clipboard open; the only waiting code in the idle clipboard check is
`CFilesWindow::IsTextOnClipboard` (`src/fileswn9.cpp`), which retries `OpenClipboard` ten times
with `Sleep(10)` (~155 ms). The other three queries fail fast.

Approach: the idle check calls `IsTextOnClipboard` in a **no-wait** form (one attempt) that also
reports "the clipboard is busy". When the check found it busy, the main window starts a one-shot
timer (`IDT_CLIPCHECKRETRY`, 500 ms) that requests the check again; at most 10 looks in a row; a
check that finds the clipboard free, or any other trigger of the check, ends / restarts the
series. Opening a menu while a look is pending looks at once. The decision (next delay, counter)
is a header-only rule `src/common/salclipcheck.h` with `saltests` checks. `RestoreGlobalSelection`
(the user's command) keeps the waiting form.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI only (`OpenClipboard`, `SetTimer`)
**Storage**: none (no configuration value)
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/act375_probe.ps1` (rows FREE, HELD)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand`)
**Performance Goals**: no UI-thread wait >= 30 ms after an activation caused by the clipboard check
**Constraints**: same paste states as today for the same clipboard; plug-in ABI untouched; no UI
strings (no `.slt` refresh)
**Scale/Scope**: `fileswn9.cpp`, `fileswnd.h`, `mainwnd1.cpp`, `mainwnd3.cpp`, `salamdr1.cpp`,
`consts.h` + one header + saltests

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no dependency, no build change |
| II Backward compatibility | no configuration, registry or plug-in change; same paste states for a readable clipboard and for a busy one |
| III Incremental modernization | a local change of one query and a timer |
| IV Windows commitment | WinAPI only |
| V Plugin architecture | no `spl_*.h` change |
| VI UI consistency | no new UI |

PASS (before and after design).

## Project Structure

### Documentation (this feature)

```text
specs/375-idle-clipboard-check/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/idle-clipboard-check.md
├── fix-log.md
└── probe/ (act375_probe.ps1, clip_hold.ps1, clip_primitives.ps1, results)
```

### Source Code

```text
src/common/salclipcheck.h   new: SalClipCheckNextLook (pure rule)
src/fileswn9.cpp            IsTextOnClipboard(noWait, busy)
src/fileswnd.h              its declaration (defaults keep the other caller unchanged)
src/mainwnd1.cpp            the idle check: no-wait query, start / end the series
src/mainwnd3.cpp            WM_TIMER IDT_CLIPCHECKRETRY; WM_USER_ENTERMENULOOP looks at once
src/salamdr1.cpp, consts.h  the series' globals, IDT_CLIPCHECKRETRY (956)
src/saltests/saltests.cpp   TestClipCheck375
```

**Structure Decision**: core only, the pattern of 372 (pure rule header + saltests + probe).

## Complexity Tracking

None.
