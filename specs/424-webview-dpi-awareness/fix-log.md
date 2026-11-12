# Fix log - 424-webview-dpi-awareness

Backlog item `remove-indentation-for-text-viewers` (GitHub #29): the Code Viewer and the Markdown
Viewer show the page shifted right and down, larger, cut off at the right and bottom.

## Measurements before the change (HEAD a44dfdf4, main)

Machine: one monitor 2560 x 1440 at 100 % (`AppliedDPI` 96). The symptom needs a different display
scaling and is **not driven** here: changing the scaling would change the maintainer's desktop.

1. `src/manifest.xml`: `<dpiAware>true</dpiAware>`, no `dpiAwareness`, so the program is system DPI
   aware. No `SetThreadDpiAwarenessContext` / `WM_DPICHANGED` anywhere in `codeview` / `mdview` /
   `src/common/webhost`. `webhost.cpp` gives the controller bounds `{0, 0, cx, cy}`, sets no
   `RasterizationScale` / `BoundsMode`. Nothing in the layout explains an offset.
2. Probe `probe/dpi29_probe.ps1` (hidden desktop, F3 on a text file -> Code Viewer;
   `probe/result_before.txt`):
   - program: awareness 1 (system), system DPI 96;
   - the browser process started by the program: `msedgewebview2.exe ...
     --embedded-browser-webview-dpi-awareness=1`, awareness 1, its **own** system DPI 96; its GPU
     process system aware too;
   - the viewer window tree: `Chrome_WidgetWin_0` (program) -> `Chrome_WidgetWin_1`,
     `Chrome_RenderWidgetHostHWND` (browser pid), `Intermediate D3D Window` (GPU pid): cross-process
     children, all awareness 1.
   - Registry restored, identical hash.
3. Mechanism: a system-aware process takes the primary display's scaling at **its own start** as
   its system DPI. The browser starts at the first view of a session (the keeper is armed in
   `ViewFile`), or again after it ended or crashed. When the scaling changed in between (Settings,
   docking, RDP), the program and the browser work in different coordinate spaces. The page is then
   scaled and placed wrongly: larger font, offset, cut off. That matches the screenshot of #29.
   Published analysis (crushonme.github.io, 2023-05-23, "Webview2 stop working after system DPI
   changed"): the same cause, fixed by PerMonitorV2.
4. Experiment `probe/wv2dpi/` (`wv2dpi.cpp`: a test host made system aware like the program,
   `summary.txt`), on the hidden desktop:
   - `system`: browser `--embedded-browser-webview-dpi-awareness=1`
   - `pmv2` (thread per-monitor v2 for the whole run): `=2`
   - `scoped` (per-monitor v2 only around `CreateCoreWebView2EnvironmentWithOptions`, restored right
     after; the controller is created later on a system-aware thread): `=2`, controller `S_OK`.

   WebView2 takes the browser's DPI mode from the **calling thread's** context at environment
   creation. The fix therefore stays in the shared host and the two viewers. The rest of the program
   stays system aware.

`BL verify` recorded: reachable at a44dfdf4.

## Decisions

- D1: the environment (host and keeper) is created inside a per-monitor-v2 scope, so the browser
  is per-monitor aware whichever creation comes first. A mixed state (one environment of each
  mode) would make the later creation fail (the WebView2 rule for environments sharing a folder).
- D2: the viewer threads run per-monitor v2 for their whole life (set at the top of `Body`). The
  viewer window, its status bar, the WebView2 controller window and the dialogs opened from it share
  one coordinate space. The browser's windows are per-monitor aware too, so the cross-process child
  placement no longer depends on any start-time scaling.
- D3: the rectangle the core passes to `ViewFile` is in the program's (system) coordinates. It is
  mapped to physical coordinates through the monitor that contains it (its rectangle read in both
  contexts). The pure mapping lives in `src/common/saldpirect.h` with saltests. Identical rectangles
  give the identity, so at 100 % nothing changes.
- D4: the saved window placement (`g_wndPlacement`) is read and written on the viewer thread, so it
  is now physical. At an unchanged scaling that is the same number as before. A value saved by an
  older version is kept visible by the existing `MultiMonEnsureRectVisible`. No conversion, no new
  stored data.
- D5: `WM_DPICHANGED` -> `SetWindowPos` to the suggested rectangle. The Code Viewer re-creates its
  status font for the new DPI (`SystemParametersInfoForDpi`) and recomputes the status height. The
  initial font also uses the window's DPI.

## speckit-analyze

0 CRITICAL, 0 HIGH. U1 (MEDIUM, quickstart GEOMETRY compared with a value the probe cannot see)
fixed: compared with the same probe run on the before build. Accepted: C1 (an older instance
holding the browser in system mode makes the new environment fail -> the existing
engine-unavailable path, feature 085; not driven); C2 (dark menu font on a monitor of another DPI,
a limit).
