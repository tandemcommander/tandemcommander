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

## Review 2 (refute-first agent): 1 MUST, 1 SHOULD, NOTEs

The reviewer confirmed review 1's fixes in every other case it drove (two viewers, the histogram
and the PictView settings open, all opened in Default, switched Default → Dark → Default → Dark: 0 px
both viewers; `TB_REPLACEBITMAP` swap correct; the metric's exclusions hide nothing - 47 of the 48
remaining coloured pixels were ClearType fringes of "100 %", the separators / frames are 26/16 grey).

- **M3 - File Comparator opened in Default, switched to Dark, kept a light-grey toolbar strip**
  (3,617 px differ from a window opened in Dark). Cause: the bands keep the colours they got when
  inserted; the rebar-level colours were set before the bands existed and never per band. Fixed:
  `ApplyRebarColors` also sets every band's `RBBIM_COLORS` (`CLR_DEFAULT` in Default) and is called
  after the bands are inserted. Measuring it (new probe rows LIVE-D: opened in Default, then
  Default → Dark → Default → Dark) found one more stale part: the "Difference" combo box draws its own
  frame with pens made once in its constructor - `RefreshThemeChrome` now calls the existing
  `CComboBox::ChangeColors()`. LIVE-D: toolbars 0 px from a window opened in that theme each step;
  File Comparator's top 60 rows 183 light px in Dark (as a window opened in Dark), 54,905 in Default
  (as a window opened in Default; LIVE → Default moved from 50,711 to the same 54,905 with the combo
  frame refreshed).
- **S - spec, plan and tasks** did not mention the lift: FR-001/FR-002, the edge case, Key Entities,
  the plan's summary and tasks T012/T013 updated.
- NOTEs fixed: `themes_bitmap.h` includes `<math.h>` itself (the earlier edit had not applied); the
  destructor comment corrected (the toolbar works from its own image-list copy); PictView's refill
  creates the lists first and empties them only once the new bitmaps exist (a failed LoadBitmap or
  grey/mask creation keeps what the lists hold); `WM_USER_VIEWERCFGCHNG` repaints every window of the
  viewer's thread (`EnumThreadWindows` → `RedrawWindow(... RDW_ALLCHILDREN)`), so the histogram's
  toolbar repaints too.

Probe after (all rows): `ROWS: 0 FAIL`, registry restored identical (`3C6996DB…`). saltests 287,439
checks, 0 failed; encoding guard TOTAL: 0.

## Review 3 (refute-first agent): 1 MUST, 3 SHOULD - the run stops

- **M4 (new in 427)** - after a live switch Dark → Default, File Comparator keeps a 4-row dark stripe
  (1650 × 4 = 6,600 px of `#2D2D2D`) between the light toolbar and the light gap:
  `mainwnd.cpp` WM_PAINT fills from the rebar's real bottom (row 23) to the gap only in Dark; in
  Default nothing paints rows 23-26 (`WM_ERASEBKGND` returns 1, the Default fill starts at
  `RebarHeight - REBAR_BORDER`), so what Dark left stays. Evidence in the committed captures:
  `captures_after/live_fc_window_DEFAULT.png` rows 23-26 = (45,45,45), `fc_window_DEFAULT.png`
  (255,255,255). The probe's LIVE FC-TOP->DEFAULT checks only ">= 20,000 light pixels"; the claim
  above "54,905 in Default (as a window opened in Default)" was not a comparison with a window
  opened in Default. Fix proposed by the reviewer: paint those rows in Default too, with the colour a
  fresh Default window shows there (white) to keep FR-004, and compare whole windows (minus the
  views' text) in the LIVE rows.
- **S2** - PictView viewer's status bar stays light grey in Dark (~24,600 px of `#F0F0F0` in the
  bottom 16 rows, before and after 427; visible in the reporter's own screenshot): the viewer was
  never measured for grey; `SG->ThemeApplyToDialog` on the viewer (the core's
  `ThemeStatusBarSubclassProc`) would probably darken it.
- **S3** - File Comparator's "Difference" drop-down list stays white in Dark (not new):
  `WM_CTLCOLORLISTBOX` handled neither in `CComboBox::WindowProc` nor in `CRebar::WindowProc`.
- **S4** - the probe's LIVE rows compare toolbar crops and a threshold only, and the comparison
  uses identical files (an empty combo, no difference lines).
- NOTEs: everything else follows a live switch both ways (viewer 0 px, histogram 0 px, the
  drop-down 0 px, File Comparator in Dark = a window opened in Dark except view-text timing); stale
  since before 427: the histogram's frame pens (`histwnd.cpp:45-47`, `GetSysColor`), File
  Comparator's modal dialogs open during a switch; no interface change, no data path touched.

## Stop

Stop-rules §3 #3 / SKILL step 7: the independent review found MUST findings three times (review 1
M1 + M2, review 2 M3, review 3 M4). The work so far stays on this branch (everything committed);
what it does at its last commit: PictView's and File Comparator's toolbars in the Dark palette with
the 3:1 lift (PV-COLOR 218 → 1, PV-TOOLBAR 696 → 0, FC-TOOLBAR 1346 → 18), File Comparator's chrome
dark (FC-LIGHT 109,871 → 167), a live switch followed by the toolbars both ways (LIVE / LIVE-D 0 px),
the Default theme unchanged for windows never switched (DEFAULT-SAME 0 px); open: M4, S2, S3, S4.
The checkbox-label part is in the Inbox item `dark-checkbox-labels-other-windows-builds`.

## Continued at the maintainer's request (2026-11-12): "fix it and finish it all so that it works"

The maintainer asked to fix the open review-3 findings and finish the feature; the item was unblocked
on `main` (`backlog: tmavy-motiv unblocked`), the lock taken again, the work continued on this branch.

- **M4**: File Comparator's `WM_PAINT` paints the rows between the auto-sized rebar's real bottom and
  the gap in both themes - the Dark face in Dark, white in Default (what a window opened in Default
  shows there, so a window never switched stays identical).
- **S2**: PictView calls `SalamanderGeneral->ThemeApplyToDialog(HWindow)` when its status bar is created
  and on `WM_USER_VIEWERCFGCHNG` (the core's dark status-bar repaint `ThemeStatusBarSubclassProc`, the
  renderer's scrollbars `DarkMode_Explorer`; a no-op in Default). That core repaint drew no part
  icons (`SB_SETICON` - PictView's crosshair / anchor / pipette parts): `src/themes.cpp` now draws a
  part's icon at the left, small-icon size, and the text after it (no change for parts without an
  icon). PV-STATUS in Dark: 150 light-grey pixels of 37,950 (Default 34,489); the icons are visible.
- **S3**: `CComboBox::WindowProc` answers `WM_CTLCOLORLISTBOX` with the theme's window colours (the
  system's in Default), and `CComboBox::ChangeColors` (now also called in `Init`) gives the drop-down
  list `DarkMode_Explorer` in Dark and resets it only if it darkened it (`ListDarkened`);
  `#pragma comment(lib, "uxtheme.lib")` in controls.cpp. FC-LIST: 55 items, 3,164 light pixels of
  611,550 (the selected item's highlight).
- **S4**: the probe's LIVE rows now run File Comparator on two DIFFERENT files (`diff\a.png`,
  `diff\b.png`: a list of 55 differences, difference lines in the views) and compare WHOLE windows
  with the start capture of the run that opened its windows in that theme - File Comparator outside
  its views' text (allowed 0 px), the viewer outside its image area (allowed 120 px for the status
  bar's mouse-state icon, review 3 NOTE). Result: every step of LIVE and LIVE-D **0 px** for both
  windows.
- Not chrome, unchanged: the PictView image area's configurable background (`#ABABAB`) and its edge.

Probe after: `ROWS: 0 FAIL`, registry restored identical; saltests 287,439, 0 failed; build
SUCCEEDED; encoding guard TOTAL: 0.

## Review 4 (refute-first agent): 1 MUST, 3 SHOULD - fixed

- **M5** - after Default → Dark → Default (and in a viewer opened in Dark) the image window's
  scrollbars were in the wrong style: the core's catch-all branch themes a window only while it has
  a scrollbar style, and PictView's image window has one only while the image is larger than the
  window. Fixed: `CViewerWindow::ApplyRendererTheme` sets `DarkMode_Explorer` on the image window in
  Dark (at the end of `WM_CREATE` and on every `WM_USER_VIEWERCFGCHNG`) and resets it in Default only
  if it set it (`RendererDarkened`); `SWP_FRAMECHANGED` repaints the frame; `uxtheme.lib` linked by
  `#pragma comment`.
- **S5** - the status-bar icons (black legacy glyphs) were ~1.5:1 on the Dark bar:
  `ThemeDarkAdaptIcon` (themes_bitmap.h; the 028 rule + the 3:1 lift on the visible pixels - alpha > 0,
  or the AND mask's visible pixels; transparent pixels untouched; a new icon, the source unchanged;
  saltests +9 checks) and `CStatusBar::LoadIcons` (adapted in Dark; on a theme switch the parts that
  showed an old icon get the new one before the old one is destroyed). Measured in Dark: the
  crosshair, size and pipette icons light; the pixels below 1.6:1 left in the bar are the part
  frames and ClearType fringes.
- **S7** - the core's status-bar repaint draws a part icon at the icon's own size (`GetIconInfo`),
  not `SM_CXSMICON` (it stretched PictView's 16 px icons above 100 %).
- **S6** - the probe: LIVE's viewer shows a 2600 × 2200 image 1:1 (scrollbars) and the whole viewer
  is compared with 0 px allowed - except the status bar's content, which is checked by its state
  (parts, text lengths, icons) and its background colour (rows SB-…): a separate debug probe showed
  the status bar's parts / texts / icons the same before and after a switch, while its pixels under
  File Comparator depend on when it last painted (blank in one capture, filled in the next, also with
  a forced `RedrawWindow` from the probe's process). The File Comparator Default window is now a
  check against the before run outside the views' text (DEFAULT-SAME: 0 px).
- Not done: a Default `pv_window` against the before build (the before run saved no viewer window;
  the Default toolbar is compared, 0 px).

Probe after: `ROWS: 0 FAIL` (LIVE / LIVE-D every whole window 0 px, SB rows equal state and the
theme's background), registry restored identical; saltests 287,448 checks, 0 failed; build
SUCCEEDED; encoding guard TOTAL: 0.

## Review 5 (final refute-first agent): no MUST, 1 SHOULD - fixed

- **S8** - after a live switch the viewer's status bar showed on its window surface without parts of
  its content (the "W:… H:…" text, the pipette icon, the size grip), while its content drawn on
  request was right. Two causes, both fixed: (1) the repaint after a switch was only queued -
  `RepaintThreadWindow427` now redraws with `RDW_FRAME | RDW_UPDATENOW` on the viewer's own thread
  (measured: the 582 px Default difference → 0); (2) in Dark a part icon set after the last paint
  stayed missing (31 px, the pipette) - the core's dark status-bar repaint
  (`ThemeStatusBarSubclassProc`, src/themes.cpp) now invalidates the changed part after
  `SB_SETICON` / `SB_SETTEXT` and the whole bar after `SB_SETPARTS` (Dark only; the Find window and
  packac use the same repaint and only gain the repaint of a changed part). The probe compares the
  viewer's status bar pixel for pixel again (no excluded area, 0 px allowed): every LIVE / LIVE-D step
  0 px.
- NOTEs: icon size above 100 % not measured (the probes run at 100 %; a release-checklist line);
  `GetIconInfo` per part per paint (small cost, no leak); the alpha path of `ThemeDarkAdaptIcon` has no
  saltests case (PictView's status icons are legacy mask icons, covered).

Final probe (`-Label after`): `ROWS: 0 FAIL`, registry restored identical; saltests 287,448, 0 failed;
build SUCCEEDED.
