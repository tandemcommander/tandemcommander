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
  is now physical. On a monitor at the program's start scaling that is the same number as before.
  A placement saved by 0.3.0 on a monitor of another scaling opens once larger or smaller by that
  monitor's ratio (review 1, NOTE 1); `MultiMonEnsureRectVisible` keeps it on screen. A value saved by an
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

## Implementation

- `src/common/saldpirect.h` (new, header-only): `SalDpiMapRect` - a rectangle from one view of a
  monitor to the other (linear, nearest pixel, the size scaled on its own; an empty or inverted
  monitor rectangle -> unchanged). saltests `TestDpiRect424`: identity, 150 % there and back, a
  125 % monitor at negative coordinates, a rectangle past the monitor, rounding, empty/inverted
  monitor, 64-bit intermediate.
- `src/common/webhost/webhost.{h,cpp}`: `CTcWebPerMonitorDpiScope`,
  `TcWebEnterPerMonitorDpiThread`, `TcWebSystemRectToPerMonitor` (monitor nearest to the rectangle,
  `GetMonitorInfoW` under a system-aware and a per-monitor context), `TcWebApplyDpiChanged`.
  `CTcWebHost::Create` creates its environment inside the scope.
- `src/common/webhost/webkeeper.cpp`: holder window + environment inside the scope.
- `src/plugins/codeview/viewer.{h,cpp}`, `src/plugins/mdview/viewer.cpp`: `Body` enters
  per-monitor v2 first; the core's rectangle is mapped when no stored placement is used;
  `WM_DPICHANGED`. Code Viewer: `CreateStatusFont()` (`SystemParametersInfoForDpi` with
  `GetDpiForWindow`, releases the previous font after the control took the new one), used at
  `WM_CREATE` and on `WM_DPICHANGED`.
- `architecture/11-webview2-integration.md` section 3: the DPI-mode rule.

## Checks after the change

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.uild.cmd` -> `BUILD SUCCEEDED`.
- `saltests.exe` -> `saltests: 287267 checks, 0 failed`.
- Probe `dpi424_probe.ps1` (hidden desktop):
  - before (HEAD build, `probe/result_probe_before.txt`): PASS 3, FAIL 4. AWARE CV/MD: viewer 1,
    controller 1, browser `=1` awareness 1. DPICHANGED CV/MD: `sent ok`, the window kept its
    rectangle. That is the negative control.
  - after (`probe/result_after.txt`, `-Before` baseline): **PASS 7, FAIL 0**. AWARE: viewer 2,
    controller 2, browser `=2` awareness 2, main window and program 1. GEOMETRY identical to
    before: CV `window (570,160)-(2159,1278) client 1573 x 1059 status 21`, MD
    `window (398,40)-(2108,1330) client 1694 x 1231 status 0`; the page at (0,0) covering the
    client. DPICHANGED: the window takes exactly the suggested rectangle, the page still covers
    the client.
  - Probe trap: `WM_DPICHANGED` sent from another process is marshalled by Windows. A pointer into
    the program's memory is refused (`SendMessageTimeout` fails), so the rectangle must be in the
    sender's memory.
- Regression probes run from a copy under `%TEMP%	c424reg` (they write screenshots into their own
  folders): `copy408_probe` (clicks into the Markdown page) **19 PASS / 0 FAIL / 1 NOT DRIVEN**, as
  recorded by 408.

## Review

### Review 1 (refute-first, independent agent) - no MUST

- **S1, measured by the reviewer** (two test hosts on one folder): a system-mode browser running,
  then a per-monitor environment -> environment `S_OK`, controller `0x8007139F`
  (`ERROR_INVALID_STATE`); the reverse order the same; per-monitor + per-monitor both work. In the
  product: while 0.3.0 or older runs with its engine started, this version's F3 shows the
  engine-unavailable message and the viewer closes, and the other way round. No data is lost. It is
  rare (two versions at once, or the old engine still alive right after an upgrade). **Done:** the
  wording is corrected in `webkeeper.cpp`, the contract, research R2, architecture 11 and the spec
  edge case (the controller fails, not the environment); the limit is named in the changelog text
  (in `closing-report.md`; `CHANGELOG.md` has no `## [Unreleased]`) and the reply draft. A fallback (retry in system mode) would bring back the very mismatch this
  feature removes; not done.
- **S2 (fixed, severity 3):** the dark-theme owner-drawn menus used one font and
  `SM_CYMENU` / `SM_CXMENUCHECK` / `SM_CYMENUCHECK` of the start scaling. Now in both
  `darkmenu.cpp` (identical copies): a font per DPI (`SystemParametersInfoForDpi`, a table of 8
  under an SRW lock - every viewer has its own thread; a font is never deleted while the module
  runs, the table being full falls back to the first font), `GetSystemMetricsForDpi`,
  `DarkMenuMeasureItem/DrawItem(…, GetDpiForWindow(HWindow))`, and on `WM_DPICHANGED`
  `DarkMenuRemeasure` + `DrawMenuBar` (its first version re-set the type and did nothing -
  review 2). At 100 % the font is the one of before (same metrics). The probe got `-Dark`, a
  menu-bar height in its GEO line and a `MENU` line (owner-drawn bar items via
  `GetMenuItemInfoW`; `GetMenuState` packs a popup's item count into the same bits, a first
  version read 1 of 4 / 3 of 4 in the default theme). The remeasure at another DPI is not driven
  here (no other DPI); the release-checklist line of two monitors names the dark menus.
- **S3 (fixed):** the reply draft no longer claims what was not shown: "should fix it", the scaling
  cases are checked by hand before the release, please confirm.
- NOTE 1 (fixed in the wording): D4 holds on a monitor at the start scaling; a placement saved by
  0.3.0 on a monitor of another scaling opens once larger or smaller; the release-checklist line 3
  now says so.
- NOTE 2-5: no change (the keeper's helper windows are per-monitor and call no core UI; the math
  checked; closing documents come at the close).

### Checks after review 1

- Before build for the negative control: worktree of `a44dfdf4` under `%TEMP%\tc424neg`, its output
  folder seeded from this build's runtime data, the two viewer plug-ins compiled from the old
  sources (a first attempt reused the seeded new plug-ins - MSBuild saw newer outputs - and was
  discarded; `OPENSAL_BUILD_DIR` needs a trailing backslash).
- `dpi424_probe` before (`result_probe_before.txt`, `result_probe_before_dark.txt`): PASS 3 / FAIL 4
  each (AWARE and DPICHANGED fail); after (`result_after.txt`, `result_after_dark.txt`, against
  those baselines): **PASS 7 / FAIL 0 each**; GEO identical (CV `window (570,160)-(2159,1278) client
  1573 x 1059 status 21 menubar 19`, MD `window (398,40)-(2108,1330) client 1694 x 1231 status 0
  menubar 19`); MENU 0 of 4 default, 4 of 4 Dark, in both builds.
- Regression probes from copies under `%TEMP%\tc424reg`, on the build with S2: `pw314_probe` 16 / 0
  (as recorded), `cvtab262_probe` 16 / 0 (as recorded), `copy408_probe` 19 / 0 / 1 NOT DRIVEN (as
  recorded).

### Review 2 (refute-first, independent agent) - no MUST

- Re-ran `dpi424_probe` on both builds (after 7 / 0, before 3 / 4), saltests 287267 / 0, the guard 0.
- **S1 (fixed, severity 3): `DarkMenuRemeasure` did nothing.** The reviewer's test host
  (`probe/menutest/`, an owner-drawn bar of 3 popups x 4 items) counts `WM_MEASUREITEM`: after the
  first show nothing re-measures (`DrawMenuBar`, `SetWindowPos`, a second popup show - the sizes are
  cached), re-setting the unchanged `MIIM_FTYPE` (424's first version), toggling `MFT_OWNERDRAW` and
  re-setting `MIIM_FTYPE | MIIM_DATA` give +0 / +0; re-setting `MIIM_BITMAP` gives bar +3, popup +4.
  **Done:** `RemeasureMenu` (both `darkmenu.cpp`, identical) re-sets each owner-drawn item's own
  `hbmpItem` (`MIIM_BITMAP`). `probe/menutest` now holds the product's function verbatim as mode 0
  and the first version as mode 5 (`result.txt`): **mode 0 bar +3, popup +4; mode 5 +0 / +0**
  (the negative control), modes 1 / 3 +0 / +0, 4 +3 / +4.
- NOTE 1 (fixed): the changelog text is in `closing-report.md` (no `## [Unreleased]`), and it names
  the old/new-version limit.
- NOTE 2 (no change): dialogs opened from a viewer run per-monitor, also core code such as the dark
  radio glyph (`themes.cpp`, `GetDeviceCaps(LOGPIXELSY)`). Possible small dark-theme mismatches only
  on a monitor of another scaling. Cosmetic; the release-checklist line names Find / Go to line there.
- NOTE 3-4: the font table, status font, thread scope, rectangle mapping, keeper and callers were
  checked and found sound; no data path, no ABI change.

### Checks after review 2

- `.\build.cmd` -> `BUILD SUCCEEDED`; saltests `287267 checks, 0 failed`; guard `TOTAL: 0 finding(s)`.
- `dpi424_probe` after: default **7 / 0**, Dark **7 / 0** (against the before baselines; GEO
  identical; MENU 0 of 4 / 4 of 4).
- `probe/menutest` (hidden desktop): as above.
