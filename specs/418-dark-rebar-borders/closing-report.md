# Closing report - 418-dark-rebar-borders
Backlog item: dark-theme-panel-tabs-look-lower-than-in-the-default-theme - Dark theme: panel tabs look lower than in the default theme
Outcome: closed

## What changed

- **Cause (measured):** the panel tab strip and the tabs were already the same size in both themes (29 px strip,
  26-px tabs, the title 11 px below the strip's top). Dark looked lower because feature 028 stripped the top
  rebar's `WS_BORDER | RBS_BANDBORDERS` in Dark (the classic rebar drew them in light system colours): the
  toolbar area lost its etched frame and the lines between band rows, was 8 px shorter (69 vs 77 px), and the
  strip had no frame line above it (11 px from the visible top edge to the title against 13 px).
- **`ThemeUpdateRebarStyle`** (`src/themes.cpp`): the rebar keeps both styles in both themes; in Dark its colour
  scheme (`RB_SETCOLORSCHEME`) is the Dark palette's `COLOR_BTNHIGHLIGHT` / `COLOR_BTNSHADOW` (464646 / 1A1A1A), so
  the frame and band borders are drawn dark exactly where the default theme draws A0A0A0 / FFFFFF; in the default
  theme `CLR_DEFAULT` (the system colours, unchanged). A scheme change repaints the frame and the bands.
- **Grips** (reviews 1 and 2): with grips shown (the default) Dark hid them (028) and gave each band a 2-px
  header, so every band's contents started ~9 px further left than in the default theme and the toolbars could
  not be dragged in Dark at all. Now the grips are inserted in both themes (`src/mainwnd1.cpp`); the colour scheme
  draws their edges dark, and `ThemeRebarCustomDraw` (`src/themes.cpp`, the rebar's `NM_CUSTOMDRAW` answered in
  `src/mainwnd3.cpp`) repaints the light middle comctl32 fills a grip with (the system face colour) with the band
  background after each band is drawn. Default: no item notifications, unchanged.
- Comments: `themes.h`, `mainwnd1.cpp`, `mainwnd3.cpp`, `SetThemeMode` (`themes.cpp`).
- `PRIVACY.md`: not affected (drawing only).

## Measurements (before / after, commands)

- Before (main `f574e83e`, `probe/measure_tabs.ps1`, `result_measure_before.txt`; the maintainer's screenshots):
  Default rebar 0-76 with etched pairs at 0-1, 25-26, 51-52, 75-76, strip 77-105; Dark rebar 0-68 without lines,
  strip 69-97; tabs and titles equal inside the strip.
- After (`probe/rebar418_probe.ps1`, `result_after.txt`): Dark rebar 77 px, strip 77-106 and directory line 106-129
  as in Default; 13838 line pixels of the Default rebar are the Dark pair at the same place in Dark; the 3 grips
  drawn alike; band contents from the same columns (menu 19 / 19, top toolbar 15 / 15); a grip drag moves the
  band in both themes.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools\check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED (no UI strings, resources or plug-in lists changed - no `full` needed).
- `saltests`: 286948 checks, 0 failed (+5: `TestDarkRebarEtchedPair418` - the Dark etched pair is darker /
  lighter than the face, far darker than the light lines, contrast >= 1.5).
- Probe `probe/rebar418_probe.ps1` (hidden desktop, registry restored and identical), **PASS 25, FAIL 0, NOT
  DRIVEN 0**: DARK, EXTRA (Plugins bar + second drive bar, two bands side by side) and NARROW (504 px wide) - rows,
  styles, lines, no light run (A0A0A0 / FFFFFF / F0F0F0) in the Dark rebar (the detector finds them on the Default
  one), grips drawn alike and contents at the same columns, title row; CLASSIC - the whole Default client area
  1714 x 1101 = the build of main, 0 px (the directory lines' free-space figures left out); SWITCH - Default -> Dark
  and back at run time = a fresh start, 0 px; DRAG - a posted drag of the top toolbar's grip moves the band in both
  themes alike, and a dragged band's grip stays dark while the drive bars are hidden (DRAG HIDDEN).
- Negative controls: the build of main (`result_negative_main.txt`) **12 FAIL** (DARK / EXTRA ROWS, STYLE, LINES,
  GRIPS, TITLE; DRAG MOVE and HIDDEN); the unfixed second form (`result_review3_before.txt`) DRAG HIDDEN FAIL; grips without a working repaint (`result_grips_attempt1.txt`) NOLIGHT and GRIPS FAIL
  (F0F0F0 middles).

## Reviews (findings and what was done)

- Review 1: MUST 0, SHOULD 1 (High Contrast on / off at run time not driven - code path traced, a release-checklist
  line), NIT 4 (grips - measured and fixed, above; the 413 entry amended; the function name kept; the saltests
  check guards the palette - accepted).
- Review 2 (the first grip form, the room without the grip): MUST 0, SHOULD 0, NOTE 4 - bands not draggable in Dark
  (fixed: the second form), a High Contrast switch did not re-insert the bands (moot: the insertion no longer
  depends on the theme), content columns of two bands only (DRAG adds a third), a theoretical flash (moot).
- Review 3 (the second form): MUST 0, SHOULD 1 - while a band was dragged with two drive bars shown, a hidden drive
  band (it keeps its old rectangle) was matched instead of the dragged band, whose grip kept its light middle during
  the drag; reproduced by the new row DRAG HIDDEN (FAIL before), fixed (the band by its id, hidden bands skipped);
  NOTE 4 (two stale comments corrected; the rest held or are accepted cosmetic edge cases).

## Owed to a person (the lines added to the release checklist)

3 lines added to `manual-checks-owed-before-the-next-release` (feature 418): Default and Dark side by side at
100-200 % (heights, dark lines, grips); toolbars moved by their grips with a real mouse in Dark (also with two
drive bars); High Contrast switched on and off with Dark selected.

## CHANGELOG entry (no `## [Unreleased]` section in CHANGELOG.md - versions are the maintainer's)

- **Dark theme: the panel tabs and the toolbar area now look the same as in the default theme** (feature 418).
  - **Before:** in the Dark theme the toolbar area had no frame and no lines between its rows, was 8 pixels lower,
    and the panel tabs sat higher with no line above them, so they looked lower than in the default theme; the
    toolbar grips were hidden, so the toolbars' contents started further left and the toolbars could not be
    moved.
  - **Now:** the Dark theme has the default theme's layout - the same frame and lines, drawn in dark colours, the
    tabs and everything below them at the same height, the toolbars' contents at the same place. The grips
    are shown in the Dark theme too, drawn dark, so the toolbars can be moved by them there as well.

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- Dark band contents started ~9 px further left than in the default theme with grips shown, and the toolbars could
  not be dragged in Dark (severity 4, review 2) - fixed: grips in both themes, the Dark repaint of their light
  middle (`ThemeRebarCustomDraw`).
- A probe flake: the directory lines' free-space figure changes between two starts when another program writes to
  the disk - the comparisons leave it out.

## New Inbox items (slug - title)

None.
