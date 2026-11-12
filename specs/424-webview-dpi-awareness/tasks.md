# Tasks: Code Viewer and Markdown Viewer pages fill the window on every display scaling

**Input**: `specs/424-webview-dpi-awareness/` (plan.md, spec.md, research.md, data-model.md, contracts/webhost-dpi.md, quickstart.md)
**Tests**: requested by the working method: `saltests` for the pure rule, a hidden-desktop probe for the behaviour.

## Phase 1: Setup

- [X] T001 Make the measurement probe path-relative (dot-source `..\..\098-long-path-overruns\probe\fix_probe_lib.ps1` from `$PSScriptRoot`) in specs/424-webview-dpi-awareness/probe/dpi29_probe.ps1

## Phase 2: Foundational (blocks both stories)

- [X] T002 [P] Write the pure rule `SalDpiMapRect(const RECT& r, const RECT& from, const RECT& to)` (linear map between two monitor rectangles, rounded to the nearest pixel; an empty `from` or `to` returns `r` unchanged) in src/common/saldpirect.h (UTF-8 BOM, header-only)
- [X] T003 [P] Add `TestDpiRect424` (identity, 150 % and 125 % cases, an offset monitor at negative coordinates, the empty-monitor refusal, rounding) and call it from main in src/saltests/saltests.cpp
- [X] T004 Declare `CTcWebPerMonitorDpiScope`, `TcWebEnterPerMonitorDpiThread`, `TcWebSystemRectToPerMonitor`, `TcWebApplyDpiChanged` (COM-free) in src/common/webhost/webhost.h
- [X] T005 Implement them, and create the environment of `CTcWebHost::Create` inside a `CTcWebPerMonitorDpiScope`, in src/common/webhost/webhost.cpp
- [X] T006 Create the keeper's holder window and its environment inside a `CTcWebPerMonitorDpiScope` in src/common/webhost/webkeeper.cpp

## Phase 3: User Story 1 - the page fills the window after a scaling change (P1)

**Goal**: the browser and both viewer windows are per-monitor aware; nothing changes at an unchanged scaling.
**Independent test**: `dpi424_probe.ps1` rows AWARE and GEOMETRY for both viewers (quickstart.md).

- [X] T007 [US1] At the top of `CViewerThread::Body` call `TcWebEnterPerMonitorDpiThread()`. Map the core's `Left/Top/Width/Height` with `TcWebSystemRectToPerMonitor` when no saved placement is used, in src/plugins/codeview/viewer.cpp
- [X] T008 [P] [US1] The same in src/plugins/mdview/viewer.cpp
- [X] T009 [US1] Write the probe specs/424-webview-dpi-awareness/probe/dpi424_probe.ps1: for a `.txt` (Code Viewer) and a `.md` (Markdown Viewer) record the awareness of the program, the browser (switch + `GetDpiAwarenessContextForProcess`), the viewer and controller windows, the window and client geometry and the page window's rectangle relative to the client. Rows AWARE / GEOMETRY. Registry backup / restore.

## Phase 4: User Story 2 - another monitor's DPI, moving between monitors (P2)

**Goal**: a DPI change resizes the viewer to the suggested rectangle and re-lays out the page and the status bar.
**Independent test**: probe row DPICHANGED (synthetic `WM_DPICHANGED`).

- [X] T010 [US2] Code Viewer: a `CreateStatusFont()` from `SystemParametersInfoForDpi(SPI_GETNONCLIENTMETRICS, …, GetDpiForWindow)` that sets `StatusHeight`, used in `WM_CREATE`. `WM_DPICHANGED` → `TcWebApplyDpiChanged`, `CreateStatusFont`, `LayoutChildren`, in src/plugins/codeview/viewer.cpp and src/plugins/codeview/viewer.h
- [X] T011 [P] [US2] Markdown Viewer: `WM_DPICHANGED` → `TcWebApplyDpiChanged` in src/plugins/mdview/viewer.cpp
- [X] T012 [US2] Add row DPICHANGED to specs/424-webview-dpi-awareness/probe/dpi424_probe.ps1

## Phase 5: Polish & verification

- [X] T013 Add the per-monitor rule (the contract's points 1–4) to architecture/11-webview2-integration.md section 3, citing specs/424-webview-dpi-awareness/contracts/webhost-dpi.md
- [X] T014 Run the encoding guard, `build.cmd`, `saltests`, the probe after (and before as the negative control on the HEAD-a44dfdf4 measurement), and record them in specs/424-webview-dpi-awareness/fix-log.md

## Dependencies

T001 → T009. T002 → T003, T005. T004 → T005, T006 → T007, T008. T007/T008 → T009. T010, T011 after T004. T012 after T010, T011. T013, T014 last.

## Parallel examples

- T002 and T003 (different files) while T004 is written.
- T008 (mdview) beside T007 (codeview). T011 beside T010.

## Implementation strategy

MVP = Phases 1–3 (the reported defect: browser and viewers per-monitor, unchanged geometry). Phase 4
completes the multi-monitor behaviour. Both ship in this one feature.
