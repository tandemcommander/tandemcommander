# Research - 424-webview-dpi-awareness

## R1 - Why the page is offset and scaled (GitHub #29)

- Decision: the cause is a DPI-mode mismatch between the program and the WebView2 browser
  process. Both are system aware, and each fixes its system DPI at its own start.
- Rationale: measured with `probe/dpi29_probe.ps1` at a44dfdf4. The browser gets
  `--embedded-browser-webview-dpi-awareness=1`, awareness 1, its own `GetSystemDpiForProcess`, and
  its windows are cross-process children of the viewer. The page's bounds code is trivially correct
  (`{0,0,cx,cy}`), so geometry in our code cannot produce an offset. The screenshot shows a larger
  font as well as the offset, which is a scale mismatch. A published WebView2 analysis
  (crushonme.github.io 2023-05-23) gives the same cause after a system-DPI change and the same cure
  (PerMonitorV2).
- Alternatives considered: `RasterizationScale` / `ShouldDetectMonitorScaleChanges` /
  `BoundsMode` in the host. They change only how the page rasterizes, not the placement of the
  browser's cross-process windows, which Windows virtualizes per process. Rejected.

## R2 - Where WebView2 takes the browser's DPI mode from

- Decision: from the calling thread's DPI awareness context at
  `CreateCoreWebView2EnvironmentWithOptions`.
- Rationale: experiment `probe/wv2dpi` (`summary.txt`). A system-aware host gives `=1`.
  Per-monitor v2 on the thread gives `=2`. Per-monitor v2 only around the call gives `=2`, and the
  controller is still created after the context was restored.
- Consequence: all environment creations in the process must use the same mode. The browser tree
  is shared per user data folder, and a second environment whose options differ from the running
  tree's fails (architecture 11, feature 085). Measured by the review for the DPI mode: the later
  environment is created, but its controller fails with `0x8007139F` (`ERROR_INVALID_STATE`),
  in both orders; two per-monitor environments work. Hence one scope in the shared code, used by both
  the host and the keeper.

## R3 - The viewer windows

- Decision: the viewer threads run per-monitor v2 for their whole life
  (`SetThreadDpiAwarenessContext` at the top of `CViewerThread::Body`).
- Rationale: child windows take the parent's DPI mode, so the controller's `Chrome_WidgetWin_0`
  follows the viewer window. A per-monitor viewer and a per-monitor browser share physical pixels
  on every monitor, whatever the start-time scaling. Windows runs a window procedure in its
  window's context, so code outside the window procedure (`Body`, `OpenFile`) must use the same
  context to avoid two coordinate spaces on one thread. Hence the whole thread.
- Alternatives: keep the viewer system aware and only make the browser per-monitor. That leaves a
  per-monitor child inside a virtualized parent: undefined placement in exactly the mismatched
  case. Rejected.

## R4 - The rectangle the core passes

- Decision: `ViewFile`'s `left/top/width/height` come from the core (system coordinates). They are
  mapped through the nearest monitor: its rectangle is read under a system-aware context and under a
  per-monitor context, and the rectangle is mapped linearly between the two
  (`SalDpiMapRect`, `src/common/saldpirect.h`). At an unchanged scaling both rectangles are equal,
  so the mapping is the identity.
- The remembered placement (`WindowPlacement`) is written and read on the viewer thread, so it
  stays in that thread's coordinates. No conversion (spec Clarifications).

## R5 - `WM_DPICHANGED`

- Decision: `SetWindowPos` to the suggested rectangle (Microsoft's documented handling). The Code
  Viewer re-creates its status font with `SystemParametersInfoForDpi(..., GetDpiForWindow)` and
  recomputes the status height, then `LayoutChildren`. The Markdown Viewer has no status bar. Its
  copy notice already uses `GetDpiForWindow`.
- Limit: the dark-theme owner-drawn menu (`darkmenu.cpp`, one cached font per module) keeps the
  start-scaling font on a monitor of another DPI. Cosmetic, and only there.
