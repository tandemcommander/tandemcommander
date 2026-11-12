# Fix log - 427 plug-in toolbars and chrome in the Dark theme

Backlog item `tmavy-motiv` (GitHub #25). Run started 2026-11-12 on `main` at `b3770fa5` (HEAD0).
Machine: Windows 10.0.26300, Debug x64 build of `b3770fa5` (`build.cmd`: BUILD SUCCEEDED; a first
attempt failed at link with LNK1168 - a transient lock, the second succeeded).

## Before the measurement

The probes refuse while any `tandemcommander.exe` runs (they share the registry key); the
maintainer's installed 0.3.0 ran until they closed it (~17:5x). The run waited with a bounded
background check (no wakeup), reading code meanwhile.

## Measurement at b3770fa5 (step 3) - `probe/dark_measure.ps1`, `probe/result_measure_before.txt`

Dark theme, Fluent 2 icon set, English core (`Set-Config`), registry restored identical:

- **Checkbox labels: not reproduced.** Core Configuration 6/6 light (`#CCCCCC` on `#2D2D2D`,
  8.58); PictView settings, all five pages, 6 checkboxes light (`#FFFFFF` on `#2D2D2D`, 13.77 -
  the Advanced page's four included); Batch Rename 8/8 light (13.77).
- **Standalone experiment** (`probe/chk_experiment.ps1`, `probe/result_chk_experiment.txt`, no
  program, no registry): a `DarkMode_Explorer` checkbox draws a LIGHT label on the main thread and
  on a second thread, with and without `DWMWA_USE_IMMERSIVE_DARK_MODE`, as a child of a top-level
  window or of a child window; the default theme and the classic theme (`SetWindowTheme(L"", L"")`)
  give a BLACK label. The reporter's screenshots show light checkbox boxes also in the core's
  Configuration (here they are dark): another Windows build draws `DarkMode_Explorer` checkboxes
  otherwise; their build is unknown.
- **Toolbars**: PictView's viewer toolbar shows its 16-colour glyphs (the blue arrows and dark
  outlines nearly invisible); File Comparator's toolbar its old glyphs on a light-grey strip.
- **Light grey**: File Comparator 70,781 px of `#F0F0F0` in Dark (whole window); none in the core's
  Configuration, PictView's settings or Batch Rename.
- How the probe opens the windows: View (742) after Change Directory to the image (F3 sent to the
  panel does nothing - accelerators run in the message loop); PictView settings `CMD_CFG` (112) in
  the viewer; Batch Rename Ctrl+Shift+R and File Comparator Ctrl+Shift+C with the hot keys set for
  the session (the method of probe 118).

## Probe before (T002) - `probe/dark427_probe.ps1 -Label before`, `probe/result_before_rows.txt`

| Row | Dark | Default |
|---|---|---|
| PV-TOOLBAR glyph px darker than the strip | 909 (strip `#2D2D2D`) | 1891 (strip `#F0F0F0`) |
| FC-TOOLBAR | 1400 (strip `#F0F0F0`) | 491 |
| FC-GREY light-grey px outside the views' text | 68,099 | 72,316 |
| PV-LABELS lowest contrast | 13.77 (6 boxes) | 19.95 |
| RN-LABELS lowest contrast | 13.77 (8 boxes) | 18.43 |

(The first version of the probe found no PictView toolbar - it is a core GUI toolbar, class
`WinLib Universal Window2` in the viewer's rebar - and counted the views' scrollbars as view
content; both fixed before this run.)

## Implementation (T003-T008)

- `src/common/themes_bitmap.h` (new, header-only): `ThemeDarkAdaptBitmap(HBITMAP, COLORREF key)` -
  the loop of `ThemeAdjustBitmapForDarkMode` moved verbatim (32-bit read, key colour and transparent
  pixels skipped, premultiplied pixels handled, `ThemeDarkAdaptColor` per pixel); plain
  `GetDC`/`ReleaseDC` (no `HANDLES`) and a NULL-DC check. `src/themes.cpp`:
  `ThemeAdjustBitmapForDarkMode` = the Dark check + the call (behaviour unchanged).
- saltests `TestDarkAdaptBitmap427` (+14 checks): a legacy strip (black → 220 grey, key kept,
  white kept, dark blue 0x60 → 0xAA, light colour kept, grey 128 → 147, the bitmap path equals the
  pure rule), an alpha strip (transparent kept, opaque black → 220, half-transparent black →
  premultiplied 220), NULL ignored. saltests: 287,428 checks, 0 failed (was 287,414).
- PictView `CViewerWindow::InitializeGraphics`: in Dark the colour bitmap is adapted before the grey
  and mask bitmaps are made, and the grey bitmap too (a saturated colour the rule keeps - e.g. a blue
  with a channel >= 120 - becomes a dark grey in the grey copy; measured: 857 → 213 without, → 0 with).
- File Comparator:
  - toolbar bitmap: magenta mapped to the SYSTEM face colour (the toolbar treats that colour of a
    `TB_ADDBITMAP` bitmap as transparent; mapped to the Dark face the disabled glyphs were solid
    squares), adapted in Dark with that colour as the key; identical in Default (both colours equal);
  - rebar `RB_SETBKCOLOR` / `RB_SETTEXTCOLOR` / `RB_SETCOLORSCHEME`, toolbar `TB_SETCOLORSCHEME`,
    in Dark only;
  - `SG->ThemeApplyToDialog(HWindow)` at the end of `CMainWindow::Init` (combo `DarkMode_CFD`, the
    views' scrollbars `DarkMode_Explorer`; a no-op in Default);
  - `controls.cpp` / `mainwnd.cpp`: `(HBRUSH)(COLOR_BTNFACE + 1)` and `GetSysColorBrush(COLOR_WINDOW)`
    → `SG->GetThemeSysColorBrush(...)` (identical in Default); the band text gets
    `GetThemeSysColor(COLOR_BTNTEXT)` (it was drawn in the DC's default black - a black block
    behind "Difference" in Dark);
  - in Dark the main window also fills the rows between the auto-sized rebar's real bottom and the
    gap (RebarHeight assumes 4 px more than the rebar takes; nothing painted those 4 rows - white);
  - `PaintDarkStaticEdge` (controls.cpp): after the default `WM_NCPAINT` of the caption windows and
    the views, the `WS_EX_STATICEDGE` 1-px edge is redrawn with the Dark bevel pair (system white /
    grey lines around the views in Dark).
- Tried and dropped: a `WM_ERASEBKGND` fill of the rebar - the white rows were not the rebar's (the
  rebar is 23 px, `fc child ReBarWindow32 0,0-1650,23`), the measurement did not change.

## Probe after (T010) - `probe/dark427_probe.ps1 -Label after`, `probe/result_after_rows.txt`

`ROWS: 0 FAIL`, registry restored identical:

| Row | before | after |
|---|---|---|
| PV-TOOLBAR neutral glyph px darker than the strip (Dark) | 696 | **0** |
| FC-TOOLBAR (Dark) | 1346 | **18** |
| FC-GREY `#F0F0F0` px outside the views' text (Dark) | 68,099 | **77** |
| FC-LIGHT light neutral px outside the text (Dark) | 109,871 | **167** (glyph highlights) |
| PV-LABELS / RN-LABELS lowest contrast (Dark) | 13.77 / 13.77 | 13.77 / 13.77 |
| DEFAULT-SAME toolbars (Default) | - | 0 / 0 px differ |

- The metric (refined during the run, recorded): only NEUTRAL glyph pixels are counted (the outlines
  and shading the Dark palette turns light); saturated colours with a channel >= 120 are kept by the
  029 rule exactly as the core's own Classic glyphs in Dark (52 such pixels in PictView, INFO), and
  the toolbar's chrome colours (Dark `COLOR_BTNSHADOW` 26,26,26 and `COLOR_3DDKSHADOW` 16,16,16 -
  separators and button frames, 161 px) are not glyphs. The before values are computed by the probe
  from the before run's saved captures with the same function.
- FC-LIGHT was added after the first passing FC-GREY: the 4 white rows below the rebar and the white
  static edges are not `#F0F0F0` and were missed by FC-GREY.
- Default `fc_window_DEFAULT.png` differs by 69-137 px between runs: all inside the right view's hex
  text (a byte drawn in one capture and not yet in the other while the comparison paints) - content
  timing, not chrome (bounding box 1110,1000-1285,1023).

## Deviation (stop-rules rule 14)

- The black checkbox labels do not reproduce on Windows 10.0.26300 (all light, before and after);
  no checkbox drawing was changed. Inbox item `dark-checkbox-labels-other-windows-builds`
  (leftover:427); the draft reply asks the reporter for the Windows build.
- Fluent 2 artwork for the plug-in toolbars was not made: the item's Expected allows "at least the
  Dark palette applied", which is what the core does for its legacy glyphs.

## Checks

- `build.cmd`: BUILD SUCCEEDED; saltests 287,428 checks, 0 failed; `check_encoding.py --strict`:
  TOTAL: 0 finding(s) (rerun before the commit of the close).
- Not driven (a person): the toolbars and File Comparator on a real screen (the probe captures via
  `PrintWindow`), and a live theme switch while a viewer / File Comparator is open (the open window
  keeps its glyphs until it is opened again - an existing limit).

## Review 1 (refute-first agent): 2 MUST, 1 SHOULD, NOTEs

- **M1 - a live theme switch left plug-in windows half-dark** (reproduced by the reviewer with its own
  hidden-desktop probe: a PictView viewer opened in Dark and switched to Default kept the lightened
  glyphs on the light toolbar; File Comparator kept a dark rebar and toolbar next to a white combo).
  Fixed: PictView `WM_USER_VIEWERCFGCHNG` (sent on `PLUGINEVENT_COLORSCHANGED`, which `SetThemeMode`
  raises) refills the existing image lists in place by `InitializeGraphics` (the toolbar, the menus
  and the histogram window keep their handles; `ReleaseGraphics` now NULLs them) and invalidates the
  toolbar; File Comparator `CC_COLORS` → `RefreshThemeChrome`: a new toolbar bitmap by
  `TB_REPLACEBITMAP` (the old one deleted after the swap; the current one now deleted in the
  destructor - before, it was never freed), `ApplyRebarColors(TRUE)` (`CLR_DEFAULT` in Default),
  `ThemeApplyToDialog` again (it undoes itself in Default), `RedrawWindow(... RDW_FRAME |
  RDW_ALLCHILDREN)` (the static edges repaint). Probe rows LIVE (Dark → Default → Dark with both
  windows open): the toolbars equal a window opened in that theme, 0 px differ, both ways; File
  Comparator's top 60 rows 50,711 light pixels after → Default, 183 after → Dark.
- **M2 - the blue PictView glyphs stayed nearly invisible and the probe could not see it** (the
  neutral-only metric). Fixed in the plug-in path only: `ThemeDarkAdaptBitmapLift` in
  `themes_bitmap.h` = the 028 adaptation, then every saturated pixel below 3:1 to the Dark face is
  mixed toward white in 5 % steps until 3:1 (WCAG 1.4.11); the core keeps `ThemeDarkAdaptBitmap`
  (Classic never restyled, 416). New probe rows PV-COLOR / FC-COLOR (coloured glyph pixels below
  1.6:1, the reviewer's measure; ClearType fringes of the zoom text "100 %" - the strip's colour in
  two channels - excluded on both sides): PictView 218 → **1**, File Comparator 0 → 0. saltests
  +11 checks (navy and (0,51,153) lifted to >= 3:1 and still blue; the key, neutral and light
  pixels as before; the core variant keeps navy): 287,439 checks, 0 failed.
- **S1 - which list the toolbar shows**: the viewer's toolbar shows the colour (hot) list in its
  normal state in these captures; the "grey bitmap 857 → 213 → 0" line above came from a capture of
  that colour list, so it measured the colour bitmap's adaptation, not the grey list. Both lists
  are adapted and lifted now; the menus (`MainMenu->LoadFromTemplate`, the histogram menu) use the
  same handles. Hover is not driven separately (it shows the same colour list).
- NOTEs: Default unchanged (re-diffed by the reviewer); the band text now `GetSysColor(COLOR_BTNTEXT)`
  in Default - identical with the standard scheme, a visible change only under custom / High
  Contrast colours (black before, the scheme's text colour now - accepted as a correction); no GDI
  leaks; ABI unchanged; the checkbox part handled honestly.
- The registry key's hash before the after-runs changed from `B94D…` (all runs before the review) to
  `3C69…` (the runs after it): the reviewer's own probe ran in between. Each run restored its own
  start state identical. Read afterwards: Theme Mode 0, Toolbar Icon Set 0, Language czech.slg; the
  Batch Rename and File Comparator menu items carry HotKey 0x352 / 0x343 - not the values this probe
  writes (0x10352 / 0x10343), told to the maintainer.
