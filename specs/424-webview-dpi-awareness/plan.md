# Implementation Plan: Code Viewer and Markdown Viewer pages fill the window on every display scaling

**Branch**: `424-webview-dpi-awareness` | **Date**: 2026-11-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/424-webview-dpi-awareness/spec.md`

## Summary

Both WebView2 viewers draw their page in a browser process. That process inherits the program's
*system* DPI mode and fixes its own scaling when it starts. After a display-scaling change between
the program's start and the browser's start, the two processes use different coordinate spaces, and
the page comes out larger, offset and cut off (GitHub #29). The fix (measured in `fix-log.md`,
experiment `probe/wv2dpi`):

1. The shared host creates every WebView2 environment (viewer and keeper) under a per-monitor-v2
   thread context, so the browser runs per-monitor aware.
2. The viewer threads of both plug-ins run per-monitor v2. The core's requested rectangle is mapped
   into the viewer's coordinates, and `WM_DPICHANGED` is handled (suggested rectangle, the Code
   Viewer's status font and height).

The rest of the program stays system aware.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: Win32 (per-monitor DPI APIs of Windows 10 1703+ / Windows 11), vendored WebView2 SDK (`src/common/dep/webview2`)
**Storage**: none new (`WindowPlacement` of both plug-ins unchanged in format)
**Testing**: `saltests` (pure rectangle mapping), hidden-desktop probe `probe/dpi424_probe.ps1` (awareness of processes and windows, geometry before/after, a synthetic `WM_DPICHANGED`)
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core + plug-ins)
**Performance Goals**: no change in time to first paint
**Constraints**: architecture 11 binding (one host in `src/common/webhost/`, never copied); plug-in ABI untouched; no new UI strings; plug-in glue stays COM-free
**Scale/Scope**: `src/common/webhost/{webhost.h,webhost.cpp,webkeeper.cpp}`, a new header `src/common/saldpirect.h`, `src/plugins/codeview/viewer.{h,cpp}`, `src/plugins/mdview/viewer.cpp`, `src/saltests/saltests.cpp`

## Constitution Check

| Principle | Check | Result |
|---|---|---|
| I. Build reproducibility | No new dependency, no NuGet; same projects | PASS |
| II. Backward compatibility | Stored placement unchanged in format, identical numbers at an unchanged scaling; plug-in ABI untouched; older plug-ins unaffected (the change is inside two plug-ins and the shared host) | PASS |
| III. Incremental modernization | Only the WebView2 viewers become per-monitor aware; the core stays system aware | PASS |
| IV. Windows commitment | Per-monitor v2 APIs of Windows 11, no fallback needed | PASS |
| V. Plugin architecture | No `spl_*.h` change; shared host stays the one host | PASS |
| VI. UI consistency | No visual change at an unchanged scaling (probe compares geometry) | PASS |

Re-checked after design: unchanged, PASS.

## Project Structure

### Documentation (this feature)

```text
specs/424-webview-dpi-awareness/
├── plan.md, research.md, data-model.md, quickstart.md, contracts/webhost-dpi.md
├── fix-log.md
├── probe/  dpi29_probe.ps1 (measurement at HEAD), dpi424_probe.ps1, wv2dpi/ (experiment), results
└── tasks.md
```

### Source Code

```text
src/common/saldpirect.h                 # new: pure rectangle mapping between two monitor rectangles
src/common/webhost/webhost.h            # new: CTcWebPerMonitorDpiScope, TcWebEnterPerMonitorDpiThread,
                                        #      TcWebSystemRectToPerMonitor, TcWebApplyDpiChanged
src/common/webhost/webhost.cpp          # environment created inside the scope; helpers' bodies
src/common/webhost/webkeeper.cpp        # holder window + environment created inside the scope
src/plugins/codeview/viewer.{h,cpp}     # thread per-monitor, rect mapping, WM_DPICHANGED, status font per DPI
src/plugins/mdview/viewer.cpp           # thread per-monitor, rect mapping, WM_DPICHANGED
src/saltests/saltests.cpp               # TestDpiRect424
```

**Structure Decision**: the existing layout. Shared code lives in `src/common/webhost/` (contract
11), the pure rule in a header under `src/common/` (working method), and the plug-ins only call it.

## Complexity Tracking

None.
