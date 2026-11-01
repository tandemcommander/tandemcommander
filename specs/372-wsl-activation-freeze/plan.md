# Implementation Plan: Switching back to the program never waits for a slow panel folder

**Branch**: `372-wsl-activation-freeze` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/372-wsl-activation-freeze/spec.md`

## Summary

Measured (fix-log): on every activation with a WSL folder in a panel the UI thread is blocked for
~400 ms by a fixed `Sleep(400)` + second listing in `CFilesWindow::ChangePathToDisk`, which runs on
every refresh of a monitored folder whose change notification failed (9P has none), and on a cold
distribution for ~2 s by the synchronous `CheckPath` in `CFilesWindow::Activate`. A common
~150 ms block of every activation (the idle clipboard check) does not wait for a panel folder and
is out of scope (Inbox item).

Approach: one small per-panel **background path check** (a worker thread that tests the folder's
accessibility exactly as the check-path thread does and posts the result back to the panel).
(1) `Activate` of a network folder starts it instead of the synchronous `CheckPath`; the result
leads to the same refresh messages as before. (2) The `Sleep(400)` + second listing becomes a
400 ms one-shot panel timer that starts the same check; only an inaccessible folder is refreshed
again. The decisions (route, what a result leads to) are a header-only rule
`src/common/salbkgndcheck.h` with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI only (threads, `PostMessage`, `SetTimer`)
**Storage**: none (no configuration value added or changed)
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/act372_probe.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand`)
**Performance Goals**: no UI-thread wait > 50 ms caused by a WSL panel folder after activation
**Constraints**: listing stays on the UI thread (rest of the program); plug-in ABI untouched; no UI
strings added (no `.slt` refresh needed)
**Scale/Scope**: 5 core files (`fileswn6.cpp`, `fileswn2.cpp`, `fileswnb.cpp`, `fileswnd.h`,
`salamdr5.cpp`, `consts.h`) + one header + saltests

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no dependency, no build change |
| II Backward compatibility | no configuration, registry or plug-in change; `DrvSpecRemoteDoNotRefreshOnAct` keeps its meaning; local folders unchanged |
| III Incremental modernization | a small local change in the refresh path, the rest of the refresh untouched |
| IV Windows commitment | WinAPI only |
| V Plugin architecture | no `spl_*.h` change, `LAST_VERSION_OF_SALAMANDER` unchanged |
| VI UI consistency | no new UI; the existing refresh and error handling run as before |

PASS (before and after design).

## Project Structure

### Documentation (this feature)

```text
specs/372-wsl-activation-freeze/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/background-path-check.md
├── fix-log.md
└── probe/act372_probe.ps1, results
```

### Source Code

```text
src/common/salbkgndcheck.h      # new: pure rule (route, result -> action, deferred verify)
src/saltests/saltests.cpp        # TestBkgndPathCheck372
src/consts.h                     # WM_USER_BKGNDCHECK_DONE (WM_APP + 421), IDT_AUTOREFRESHVERIFY (955)
src/fileswnd.h                   # panel members + RequestBkgndPathCheck / OnBkgndPathCheckDone
src/salamdr5.cpp                 # SalTestPathAccessible (extracted from ThreadCheckPathFBody) + worker thread
src/fileswn6.cpp                 # Activate: network folder -> background check
src/fileswn2.cpp                 # ChangePathToDisk: Sleep(400) + 2nd listing -> 400 ms timer
src/fileswnb.cpp                 # panel WindowProc: the timer and the result message
```

## Phase 0 / Phase 1

See [research.md](research.md), [data-model.md](data-model.md),
[contracts/background-path-check.md](contracts/background-path-check.md),
[quickstart.md](quickstart.md).

## Complexity Tracking

None.
