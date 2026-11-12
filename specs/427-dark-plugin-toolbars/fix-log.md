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
