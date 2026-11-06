# Implementation Plan: A tab switch that shows a dialog never leaves the tab strip in drag mode

**Branch**: `405-tab-switch-dialog-drag` | **Date**: 2026-11-06 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/405-tab-switch-dialog-drag/spec.md`

## Summary

`CTabWindow::OnLButtonDown` (`src/tabwnd.cpp`, `case tspTab`) calls `FilesWindow->SwitchToTab(index)`
and then always arms a pending drag (`WaitForDrag`) and takes `SetCapture`. When the switch ran a modal
window (the FTP leave question, an error box), the button-up went to that window: the strip is left with a
capture and a pending drag with no button held. Feature 404 cancels it at the first `WM_MOUSEMOVE`
without `MK_LBUTTON`, but the capture stays until then, a press elsewhere goes to the strip, and a move
with that press held starts a drag of the switched tab (measured: probe `tabs405` RELEASED, the tab moved
to the end).

Fix: read the left button's synchronous state (`GetKeyState(VK_LBUTTON)`) when the press is handled and
again after `SwitchToTab` returns; arm the drag only when the pure rule
`SalTabArmDragAfterSwitch(downAtPress, downAfterSwitch)` allows it - it refuses exactly the case "held at
the press, no longer held after the switch". Additionally `OnLButtonDown` cancels any gesture still
pending before it handles a new press.

## Technical Context

**Language/Version**: C++20 (MSVC v143), pure WinAPI
**Primary Dependencies**: none new
**Storage**: none (no registry change)
**Testing**: `saltests` (new checks in `TestTabStrip405`), GUI probe `specs/405-tab-switch-dialog-drag/probe/tabs405_probe.ps1`, regression probe `specs/404-panel-tabs-rounded-look/probe/tabs404_probe.ps1 -Only MOUSE,MENU,FALLBACK`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `salamand`)
**Performance Goals**: n/a (two `GetKeyState` calls per click)
**Constraints**: posted-message probes must keep driving drags (their key state stays "up" throughout)
**Scale/Scope**: one handler in `src/tabwnd.cpp`, one rule in `src/common/saltabs.*`

## Constitution Check

- I. Build reproducibility: no new dependency, no build change - PASS.
- II. Backward compatibility: no setting, file or plug-in interface changes; a drag held from press to release behaves as in 0.2.0 - PASS.
- III. Incremental modernization: a local fix in the feature-404 code - PASS.
- IV. Windows commitment: WinAPI `GetKeyState` - PASS.
- V. Plugin architecture: no plug-in API change; the FTP plug-in is untouched - PASS.
- VI. UI consistency: no string or dialog change; behaviour matches the Windows convention that a drag needs the button held - PASS.

Re-check after design: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/405-tab-switch-dialog-drag/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── fix-log.md, closing-report.md
├── checklists/requirements.md
└── probe/tabs405_probe.ps1, result_before.txt, result_after.txt
```

### Source Code (repository root)

```text
src/common/saltabs.h / saltabs.cpp   SalTabArmDragAfterSwitch (pure rule)
src/saltests/saltests.cpp            TestTabStrip405
src/tabwnd.cpp                       CTabWindow::OnLButtonDown
help/                                no change expected (the manual describes drags with the button held)
```

**Structure Decision**: core only; the rule header-and-source pair already exists and is compiled into `saltests`.

## Complexity Tracking

None.
