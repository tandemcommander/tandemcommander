# Implementation Plan: Disk Map closes safely while one of its loops is open

**Branch**: `143-diskmap-release-guard` | **Date**: 2026-10-14 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/143-diskmap-release-guard/spec.md`

## Summary

On the 0.1.10 build a normal exit (or an installer's close) while a Disk Map window has its
context menu or a shell command's window open crashes the program (measured, `research.md` R1).
The map window gets a `WM_CLOSE` case: inside one of its loops (menu, its own box, a shell
command) the request is deferred - the menu is ended, the plug-in's own boxes are cancelled, the
shell is left alone - and the window closes when the last loop returns. While a loop is open the
window withdraws its unattended-close declaration, and `Release` refuses an unattended close
while any map is in a loop. The decision is a header-only rule with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: WinAPI (user32 menus/dialogs, shell `IContextMenu`), plug-in interface 107
**Storage**: N/A (no registry change)
**Testing**: `saltests` (pure rule), GUI probe on the hidden desktop (`probe/release_guard_probe.ps1`), 118 probe regression
**Target Platform**: Windows 11 x64
**Project Type**: desktop application plug-in (`diskmap.spl`)
**Performance Goals**: a close inside a menu or own box ends within the 1 s `Release` already waits
**Constraints**: no new string, interface or registry value; Disk Map still loads in 103-106 cores (107 services guarded)
**Scale/Scope**: 4 Disk Map sources, 1 new shared header, `saltests`

## Constitution Check

| Principle | Status |
|---|---|
| I. Build reproducibility | PASS - no new dependency, header-only rule, built by `build.cmd` |
| II. Backward compatibility | PASS - no ABI change; behaviour on a normal close unchanged except that it no longer crashes; older cores keep loading the plug-in (107 calls guarded) |
| III. Incremental modernization | PASS - smallest change at the window; upstream structure kept |
| IV. Windows commitment | PASS |
| V. Plugin architecture preservation | PASS - uses interface 107 as documented (withdraw with FALSE) |
| VI. UI consistency | PASS - no new UI; the existing core question remains the only one |

Re-checked after design: unchanged.

## Project Structure

### Documentation (this feature)

```text
specs/143-diskmap-release-guard/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/close-in-loop.md
├── checklists/requirements.md
├── probe/release_guard_probe.ps1, probe/result_pre143.txt
├── fix-log.md            # running record
└── tasks.md              # /speckit-tasks
```

### Source Code

```text
src/common/salloopclose.h                       # new: the pure rule (Enter/Leave/CloseRequest)
src/saltests/saltests.cpp                       # TestLoopClose143
src/plugins/diskmap/DiskMap/GUI.MainWindow.h    # loop state, WM_CLOSE handling, About / Esc guarded
src/plugins/diskmap/DiskMap/GUI.MainWindow.cpp  # WM_CLOSE case; the loop helpers
src/plugins/diskmap/DiskMap/GUI.ShellMenu.h     # menu and shell command guarded
src/plugins/diskmap/DiskMapPlugin/DiskMapPlugin.cpp  # DiskMapLoopsOpen, declaration withdraw/restore, Release guard
```

**Structure Decision**: the rule is shared code under `src/common/` (header-only - plug-ins do
not compile `.cpp` files from there); the window keeps one `CSalLoopCloseState` and gives
`CShellMenu` a pointer to it at creation.

## Complexity Tracking

None.
