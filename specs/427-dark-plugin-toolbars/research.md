# Research - 427

## R1 - The black checkbox labels

- **Decision**: no change to checkbox drawing; the probe measures every label (guard); the reply
  asks the reporter for the Windows build; an Inbox item keeps the part.
- **Rationale**: on Windows 10.0.26300 all labels are light (core 6/6, PictView 6/6 on five pages,
  Batch Rename 8/8; contrast 8.58-13.77). The standalone experiment (`probe/chk_experiment.ps1`):
  a `DarkMode_Explorer` checkbox draws a light label on the main thread and on another thread,
  with and without `DWMWA_USE_IMMERSIVE_DARK_MODE`, in a top-level and in a child window; only the
  default and the classic theme give a black label. The reporter's screenshots show checkbox
  glyphs drawn differently from this machine (light boxes) also in the core's Configuration,
  whose labels are light there: the cause is specific to their Windows build. A fix without a
  reproduction would be a guess (CLAUDE.md *Measure first*).
- **Alternatives**: custom-drawing every checkbox label in Dark (changes every dialog of the
  program on every Windows build, untestable for the failing case here).

## R2 - Plug-in toolbar glyphs

- **Decision**: `ThemeDarkAdaptBitmap(HBITMAP, COLORREF key)` in a new header-only
  `src/common/themes_bitmap.h`, the exact loop of `ThemeAdjustBitmapForDarkMode` (028: 32-bit
  read, key colour and transparent pixels skipped, `ThemeDarkAdaptColor` per pixel, premultiplied
  PNG pixels handled); the core function becomes the Dark check plus that call. PictView calls it
  on the colour bitmap (key magenta) before the grey and mask bitmaps are made, so both image lists
  (normal = grey, hot = colour) are adapted. File Comparator calls it on the mapped toolbar bitmap
  with the mapped background as the key.
- **Rationale**: no interface change (the plug-ins have `IsDarkThemeActive`); one implementation
  for the core and the plug-ins; the same look as the core's Classic glyphs in Dark.
- **Alternatives**: a new interface function (ABI change, maintainer-owned); Fluent 2 artwork for
  ~30 plug-in buttons (the item's "or at least the Dark palette"; new artwork is a larger, separate
  piece of work).

## R3 - File Comparator chrome

- **Decision**: rebar `RB_SETBKCOLOR` / `RB_SETTEXTCOLOR` / `RB_SETCOLORSCHEME` with the theme's
  colours in Dark (the rebar is unthemed, so they apply - the core does the same for its top
  rebar); `(HBRUSH)(COLOR_BTNFACE + 1)` and `GetSysColorBrush(COLOR_WINDOW)` in `controls.cpp`
  become `GetThemeSysColorBrush(...)` (identical in Default); the band text gets the theme's text
  colour; `ThemeApplyToDialog(main window)` after the children exist gives the combo box and the
  views' scrollbars the core's dark control theming.
- **Rationale**: the measured light grey (70,781 px) is the rebar strip and these fills.
