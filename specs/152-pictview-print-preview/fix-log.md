# Fix log: 152 - PictView's print preview

Backlog: `specs/NEXT-WORK.md` A.6 (queue 104 entry 1, found by 120).

## Cause (by reading, confirmed by the control build)

`print.cpp CreatePreview` asked `PVSaveImage` for raw 32-bit rows scaled to the preview size (and
cropped to a printed selection). The WIC engine of feature 006 (`wicengine.cpp WicSaveImage`)
offers raw output only at the natural size, uncropped - `PVC_UNSUP_OUT_PARAMS`; the preview
bitmap was never made and the page stayed empty in every release since 006. The print itself draws
through `PVSetStretchParameters` + `PVDrawImage` and works.

## Measuring

The preview control answered only `WM_PAINT`; on the hidden desktop nothing is shown (120's
histogram rows were NOT DRIVEN for the same reason). Measured routes: `PrintWindow` of the control
(with or without `PW_CLIENTONLY`) returns FALSE; `PrintWindow` of the Print dialog (flags 0)
returns the dialog drawn, the preview control with it once it answers `WM_PRINTCLIENT`. So:

- step 1: `CPreviewWnd` answers `WM_PRINTCLIENT` (`Paint((HDC)wParam)`); this tree built as the
  control `Debug_x64_pre152`;
- step 2: the fix.

Probe `probe/print_preview_probe.ps1`, fixture `probe/mkfix152.py` (80x60, four colored quadrants).

| build | result |
|-------|--------|
| control (only `WM_PRINTCLIENT`) | `probe/result_pre152.txt`: 14 PASS, 7 FAIL - every PREVIEW row: the page, nothing of the picture |
| fix | `probe/result.txt`: 21 PASS, 0 FAIL |
| fix without the stretch given back (variant, not kept) | VIEWER rows FAIL: after the dialog the viewer showed a magnified red corner |

A finding of the negative control: the first VIEWER check compared only the picture's box and
PASSED on the variant - it now compares each color's count too.

`sel-part`: the posted drag of the select tool makes a 2x3-pixel selection in the red quadrant
(the dialog: 0.53 x 0.79 mm); the preview is red only in that shape (197x297). A selection over
several colors was not driven (the drag lands where the hidden desktop's cursor is) - by reading:
the arithmetic is the print's.

## Work

- `print.cpp CreatePreview`: the print's arithmetic (the full picture's size from the preview size
  and the selection, the selection corner's offset, the stretch signed by the mirror flags XOR a
  negative size), drawn through the engine into a 32-bit DIB; the viewer's stretch set back right
  after. The raw-output callbacks `PreviewWrite` / `PreviewSeek` removed.
- `CPrintParams::DisplayStretchX/Y` (`dialogs.h`; 0 in `Clear`, copied in `UpdateImageParams`,
  set in `render1.cpp` to the values the print restores). 0 = no preview drawn.
- `CPreviewWnd`: the cached preview is keyed on `bSelection` too (toggling *Print selected area* at
  an unchanged size - fit without keeping the aspect - kept the old picture); `WM_PRINTCLIENT`.

## Review (refute-first agent, 2026-10-14)

No critical finding. Confirmed: `SelectRect` is in the coordinates of the picture as shown
(mirrored), so the print's and the preview's crop agree in all four mirror / negative-size
combinations; the old "mirror before crop" conversion only served `PVSaveImage`. The engine pumps
no messages between setting and restoring the stretch; `DisplayStretch` is set on the only caller;
GDI objects freed on every path.

Taken over:
- (LOW, new exposure) the stretch given back is the one of the dialog's start; a resize while the
  modal dialog is open (a maximized viewer at a display change) set another - `render1.cpp` sets the
  live stretch again right after `Execute()` returns, whatever the result.
- (LOW) the comments calling the selection "image coordinates" (`dialogs.h`, `renderer.h`).

To `specs/NEXT-WORK.md` (print side, pre-existing): in Fit mode the print still mirrors by a
negative stored Width / Height while the preview (and the dialog) show it upright; the print's
`prevWidth * pvii.Width / selWidth` is unsigned 32-bit and wraps at a large scale of a big image.

## After

- Debug build clean; `check_encoding.py` TOTAL 0.
- `probe/result.txt` 21/0; 120's print-dialog and rotation rows (`tgt-shown-print`, `bk-rot`):
  `probe/regress_120_print_rot.txt` 4/0.
- Owed to a person: print once (a printer or *Microsoft Print to PDF*) and compare the paper with
  the preview - plain, mirrored, a selection.
