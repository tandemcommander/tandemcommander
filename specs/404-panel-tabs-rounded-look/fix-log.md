# Fix log - 404 panel tabs, variant F look, icons, live drag, close on release, other-panel commands

Backlog item `panel-tabs-rounded-windows-11-look-with-icons-and-roomier` (one feature, never split -
maintainer decision 2026-11-06).

## Measurement at f2d2ca59 (main, before the feature)

- `git log --oneline 7ee0f43d..HEAD -- src/tabwnd.cpp src/tabwnd.h src/paneltabs.cpp` -> empty: every
  *Evidence* site of the item stands as written.
- Reading `src/tabwnd.cpp`: `GetNeededHeight` = `2 + EnvFontCharHeight + 2 + TabStripScaled(2)`
  (21 px at 96 DPI); `PaintTab` fills `BTNFACE` and calls `ThemeDrawEdge(BDR_RAISEDINNER)`; glyphs
  are `CreatePen` 1-px lines; no icon; `OnLButtonDown` `case tspClose:` -> `CloseTab(index)` on the
  press; the drag paints only `PaintInsertMark`; `OpenContextMenu` has ids 1-6, no other-panel item.
- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED.
- The probe's before run (T003) is below.

## Decisions (spec *Clarifications* / *Assumptions*)

- Comparison with the evidence: pixel may differ only where the evidence's 3x3 neighbourhood is not
  uniform, by at most 64 per channel.
- Esc during a drag: `GetAsyncKeyState(VK_ESCAPE)` in the drag timer.
- Press on X then capture lost: forgotten, nothing closes.
- Moved tab: end of the other panel, active there.
- Classic look not kept as an option; new commands only in the strip's context menu.
- Evidence images copied to `probe/evidence/` (the item folder is deleted when the item closes).
- The 078 GUI driver (`drive.ps1`) was never committed; `tabs312_probe` is the regression probe.

## T003 probe before the change (build of f2d2ca59 = branch before any code change)

`tabs404_probe.ps1 -Label before` on the hidden desktop (`result_before.txt`, `result_before_mouse.txt`;
the first MOUSE run failed in the probe itself - `$S` and `$s` are one PowerShell variable - fixed):

- LOOK-LIGHT / LOOK-DARK: all 10 variant F rows FAIL (`size 786x21, evidence 786x29`).
- CONTROL (old look vs `current_*_normal.png`): 16488 of 16506 pixels exact, 18 failing, all in the
  plus glyph at x 774: the program clamps the plus box to the strip's right edge (`PlusRect.right >
  limit`), the mockup's port does not (its plus is 1 px to the right). Capture and comparison method
  confirmed; the item's "0 differing pixels" was measured on a wider window. Variant F at 786 px
  needs no clamp (plus box 754..783).
- MOUSE: DRAG, CANCELMODE, CAPLOST, NOTEAR PASS on the old build too (regression rows - the old
  insert-mark drag gives the same order); XPRESS FAIL (the press on X closed B at once), XOFF FAIL
  (press on X, move off, release: D closed).
- MENU: MOVE, NOREOPEN, MOVE-SINGLE, NEWASOTHER FAIL (ids 2885 / 2887 unknown -> nothing happens);
  REFUSED NOT DRIVEN (no shipped plug-in refuses a leave).
- Registry restored, identical (SHA-256 1D52D842...).
