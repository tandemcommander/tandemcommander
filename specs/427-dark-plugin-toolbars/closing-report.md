# Closing report - 427-dark-plugin-toolbars
Backlog item: tmavy-motiv - Dark theme: black checkbox labels and old toolbar icons in plug-in windows
Outcome: closed

## What changed

- **PictView** (Dark): the viewer's toolbar glyphs (normal and hot lists, also used by its menus and
  the histogram) get the core's Dark adaptation of legacy glyphs plus a 3:1 lift of low-contrast
  saturated colours; the status bar is dark (the core's dark status-bar repaint) with adapted light
  icons; the image window's scrollbars are dark; all of it follows a live theme switch (the image
  lists refilled in place, the status icons reloaded, the windows repainted at once).
- **File Comparator** (Dark): the toolbar glyphs adapted the same way (the bitmap keeps the system
  face colour as the toolbar's transparent colour - no solid squares for disabled buttons); the
  rebar, its bands, the "Difference" label, the gaps under the rebar, the splitter, the static edges
  of the captions and views, the combo box's frame and its dropped list, and the views' scrollbars
  use the Dark palette; `RefreshThemeChrome` rebuilds all of it on a live switch in both directions.
- **Core** (`src/themes.cpp`, `src/common/themes_bitmap.h`): the legacy-glyph adaptation moved to a
  header-only helper (`ThemeDarkAdaptBitmap`, unchanged behaviour), plus `ThemeDarkAdaptBitmapLift`
  and `ThemeDarkAdaptIcon` for plug-ins; the dark status-bar repaint draws part icons (at their own
  size) and repaints a part changed by `SB_SETICON` / `SB_SETTEXT` / `SB_SETPARTS`.
- No plug-in interface change; the Default theme unchanged for windows opened in it.
- The black checkbox labels did not reproduce here (see *New Inbox items*).

## Measurements (before / after, commands)

`probe/dark427_probe.ps1` through `tools/run_on_hidden_desktop.ps1` (`-Label before` on the build of
`b3770fa5`, `-Label after` on the branch; registry restored identical each run):

| Row | before | after |
|---|---|---|
| PV-TOOLBAR neutral glyph px darker than the strip (Dark) | 696 | 0 |
| PV-COLOR coloured glyph px below 1.6:1 (Dark) | 218 | 1 |
| FC-TOOLBAR (Dark) | 1,346 | 18 |
| FC-GREY / FC-LIGHT light px outside the views' text (Dark) | 68,099 / 109,871 | 77 / 167 |
| PV-STATUS light-grey px in the status bar (Dark) | (light grey, ~24,600 in the measure run) | 150 of 37,950 |
| FC-LIST light px in the dropped list of differences (Dark) | (white) | 3,164 of 611,550 |
| LIVE / LIVE-D whole windows after a switch (5 steps, both windows) | half-dark (reviews 1-5) | 0 px |
| DEFAULT-SAME toolbars, File Comparator window (Default) | - | 0 px |
| PV-LABELS / RN-LABELS lowest checkbox label contrast (Dark) | 13.77 / 13.77 | 13.77 / 13.77 |

Checkbox experiment (`probe/chk_experiment.ps1`): a `DarkMode_Explorer` checkbox draws a light label
on Windows 10.0.26300 in every case tried; black only with the default or the classic theme.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `build.cmd`: BUILD SUCCEEDED. `saltests`: 287,448 checks, 0 failed (+34: `TestDarkAdaptBitmap427`,
  the lift, `ThemeDarkAdaptIcon`). `check_encoding.py --strict`: TOTAL: 0 finding(s).
- Probe `dark427_probe.ps1 -Label after`: ROWS: 0 FAIL.

## Reviews (findings and what was done)

Five refute-first reviews (details in `fix-log.md`): review 1 M1 (live switch), M2 (navy glyphs,
lift), S1; review 2 M3 (window opened in Default switched to Dark: band colours, combo frame), NOTEs;
review 3 M4 (dark rows after Dark -> Default), S2 (PictView status bar), S3 (dropped list), S4 (probe
compared toolbars only) - the run stopped here (three reviews with MUST) and was finished at the
maintainer's request; review 4 M5 (image-window scrollbars), S5 (status icons), S6 (probe), S7 (icon
size); review 5 no MUST, S8 (status bar surface lag after a switch). All fixed and measured.

## Owed to a person (the lines added to the release checklist)

3 lines in `manual-checks-owed-before-the-next-release` (feature 427): the Dark look of both
plug-ins on a real screen; a live switch with both windows open; the status icons at 125 / 150 %.
GitHub #25: answer and close (draft in `specs/427-dark-plugin-toolbars/reply.md`, asks for the
reporter's Windows build for the checkbox part).

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- File Comparator's toolbar bitmap was never freed (now deleted in the destructor / after a swap).
- File Comparator's "Difference" band label was drawn in the DC's default black (a black block in Dark).
- The core's dark status-bar repaint dropped part icons and did not repaint a part changed after its
  last paint (also the Find window and packac use it; they set no icons, they gain the part repaint).

## New Inbox items (slug - title)

- dark-checkbox-labels-other-windows-builds - Dark theme: black checkbox labels in plug-in windows on some Windows builds

## CHANGELOG entry (no `## [Unreleased]` section in the tree - for the maintainer to add)

- **Dark theme: readable toolbar icons in PictView and File Comparator, no light-grey parts left**
  (feature 427, GitHub #25). The old toolbar icons get the dark adaptation of the program's own
  Classic icons - light outlines, lightened dark blues - also for disabled buttons; PictView's status
  bar is dark with light icons; File Comparator's toolbar strip, its list of differences, the strips
  under the toolbar, the scrollbars and the frames of the views are dark. Everything follows a switch
  between the Default and the Dark theme while the windows are open. Limits: the icons are still the
  old pictures; black checkbox labels reported on some Windows builds did not reproduce on Windows 11
  and stay open.
