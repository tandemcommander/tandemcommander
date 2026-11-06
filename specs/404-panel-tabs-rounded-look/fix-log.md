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

## Implementation

- `src/common/saltabs.*`: `SalTabMix` (half to even, as the mockup's `Math.Round`; `rint` on
  doubles, so the IEEE results equal C#'s), `SalTabStripColorsGet`, `SalTabCloseColors`,
  `SalTabScaled`, `SalTabStripHeight` (29 at 96 DPI), `SalTabStripWidths`, `SalTabDragSlot`
  (centre over centre), `SalTabDragPosition`, `SalTabEaseOut`, `SalTabMenuCanMoveToOther`,
  `SalTabMenuCanNewAsOther`, `SalTabLocationKind`. `saltests`: `TestTabStrip404` (expected colours
  are pixels of the evidence images) -> 282506 checks, 0 failed.
- `src/tabwnd.*`: rewritten painting per the mockup's `PaintNew`; shapes through nanosvg into a DIB of
  the strip's size, coverage -> premultiplied BGRA -> `AlphaBlend` (nanosvg writes R,G,B,A and leaves
  the alpha premultiplied - a white fill makes the byte order irrelevant). Icon cache (folder =
  `SimpleIconLists` `symbolsDirectory`, archive = `LoadArchiveIcon`, drive = `GetDriveIcon` per
  (type, Windows drive), removable = generic id 28, plug-in FS = the plug-in's Change Drive menu icon
  or `IDI_PLUGINFS`). Live drag with a 16-ms timer, 150-ms ease-out, glide on release / cancel; Esc
  through `GetAsyncKeyState` in the timer; `SPI_GETCLIENTAREAANIMATION` off -> no glide. Close on
  release (`PressedClose`). `WM_PRINTCLIENT` paints into the given DC. Two context menu items.
- `src/paneltabs.*`, `src/fileswnd.h`, `src/fileswn1.cpp`: `IconKind` / `IconDriveType` /
  `IconPluginIndex` session fields (reset when the active tab's location changes in
  `DirectoryLineSetText`, resolved from the panel in `CaptureActiveTab`), `ResolveTabIconKind`,
  `MoveTabToOtherPanel`, `NewTabAsOtherPanel`, `HandleTabCommand` for 2885-2888.
- `src/resource.rh2` 2885-2888, `src/mainwnd3.cpp` the four `WM_COMMAND` cases, `src/texts.rh2` /
  `src/lang/texts.rc2` 14192-14193, `src/themes.*` `IsThemeHighContrast`.
- Manual: `help/src/hh/salamand/windows_tabstrip.htm` (icons, close on release, live drag, the two
  commands).

### Deviations and measured choices

- **The + glyph has butt caps reaching 0.25 px past its ends** instead of the mockup's round caps.
  Measured at (768,20) / (768,11), the tips of the vertical stroke: mockup (GDI+) 102 / 137 on the
  222 background (coverage 0.87 / 0.62 - GDI+ is not symmetric), nanosvg round cap 167 / 139
  (coverage 0.40 / 0.60, its round cap of radius 0.6 is a near-triangle), square cap 84 / 84 (1.0):
  the round cap failed the normal rows by 1 pixel (65 > 64), the square cap the hover rows (78).
  0.25 px butt caps: all 10 rows pass, maximum edge difference 46. At 1.2 px the cap shape is not
  visible.
- **WM_MOUSELEAVE without a cursor position keeps the hover.** On the hidden desktop
  `GetCursorPos` fails and `TrackMouseEvent` posts `WM_MOUSELEAVE` at once, so no hover state could
  be captured (the hover rows showed the normal strip). The strip now ignores a leave when
  `GetCursorPos` fails (no cursor to judge by; the next mouse message re-evaluates). On an input
  desktop `GetCursorPos` succeeds and a leave clears the hover as before.
- A refused leave in *Move to Other Panel* is NOT DRIVEN: no shipped plug-in refuses a leave
  (`CHPPFR_CANNOTCLOSEPATH`, feature 078 deviation); the code path is read: the other panel's new tab
  is removed after switching it back to its previous tab; if the other panel cannot leave it either,
  the tab stays in both panels (never in neither).
- An archive tab restored at start-up and never shown shows the folder icon until it is first shown
  (the kind of an archive comes only from the panel - no disk access for a remembered location).
- The middle button is ignored while a left-button gesture (drag, pressed X) runs.

## Probe after the change (`result_after.txt`)

`tabs404_probe.ps1 -Label after`: **PASS 25, FAIL 0, NOT DRIVEN 1** (REFUSED). LOOK-LIGHT and
LOOK-DARK: 10/10 images, 0 failing pixels, e.g. normal light exact 22543, edge-tolerated 251 (max 45)
of 22794; the folder and drive icons equal the evidence pixel for pixel. MOUSE: DRAG, CANCELMODE,
CAPLOST, NOTEAR, XPRESS (press on X: nothing closes, no switch), XRELEASE, XOFF PASS. MENU: MOVE (left
[A], right [R B] with B active), NOREOPEN, MOVE-SINGLE, NEWASOTHER PASS. Registry restored, identical.
Negative controls: the before run (above) fails XPRESS, XOFF, the four menu rows and the ten look rows.

Regression: `tabs312_probe` after the change -> **PASS 33, FAIL 0** (`result_tabs312_after.txt`).
The 078 driver was never committed (nothing to run).

## Translations (stop-rules §2.13)

- Entries (step 0): new `IDS_MENU_TAB_MOVETOOTHER` 14192 "&Move to Other Panel",
  `IDS_MENU_TAB_NEWASOTHER` 14193 "New Tab as Other &Panel"; no changed entry, no dialog change.
- `build_langs.cmd --export-templates --module salamand`; dry run: 2 unique gaps, ~43 chars per
  language (8 languages); merge `--formality prefer_more --budget 2688`: DeepL characters sent 328,
  validation failures 0.
- Read back: fr 'Passer à', hu 'Átváltás', es 'Desplazarse' meant "switch to"; de 'Reiter' (the
  module says 'Registerkarte') and 'Fenster'; ro 'Fila „Nou” ca alt panou' (the New tab); accelerators
  clashing with *Duplicate Tab* (sk/cs) or *Lap másolása* (hu). 16 pins under `_feature_404`
  (both strings, all 8 languages) with the corpus's "other panel" (cs/sk 'druhý panel', de 'anderes
  Fenster', fr "l'autre panneau", nl 'ander paneel', hu 'másik panel', ro 'celălalt panou', es 'el
  otro panel'); merge again: 0 gaps; `translate.slt --verify`: round-trip byte-exact (298 files).
  No re-laid-out controls (only the two string rows changed per language).
- `.\build.cmd full` -> BUILD SUCCEEDED.

## Checks

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` / `.\build.cmd full` -> BUILD SUCCEEDED (no warning in the changed files).
- `saltests.exe` -> 282506 checks, 0 failed.

## Findings fixed on the way

- None of severity 6 or more. The mockup's variant 0 port differs from the program in the plus box
  clamp at the strip's right edge (the 18 control pixels of the before run) - a property of the old
  mockup, nothing to fix.

## Owed to a person

5 lines added to `manual-checks-owed-before-the-next-release` (real-screen look, real-mouse drag and
Esc, close on release, 125 / 150 % and High Contrast, Move to Other Panel with an SFTP tab).

## Review

### Review 1 (refute-first agent, HEAD fb83b19b) - no MUST

Re-ran saltests (282506 / 0), `tabs404_probe` (25 / 0 / 1 NOT DRIVEN), `tabs312_probe` (33 / 0); a
negative control of the image comparison (evidence shifted 1 px right / down: 1420 / 1250 failing
pixels; the inactive capture against the normal evidence: 2173) - the look rows discriminate.

- **S1 Move to Other Panel lost a tab when the other panel fell back** (`SwitchToTab` returns TRUE
  when `ChangeDir` falls back to another place and rewrites the new tab's location; the source was
  then deleted). Fixed: after the other panel's switch the new tab's location is compared with the
  moved one (`TabLocationsSame`: ordinal case-insensitive, a trailing backslash ignored); when they
  differ the move is undone like a refused leave (`TakeTabBackFromOther`) and the tab stays here.
  New probe row FALLBACK MOVE-GONE (an inactive tab whose folder was deleted, through the real context
  menu): error box shown, left [A X], right [R] - PASS (before the fix the source X would have been
  removed: left [A], right [R R]).
- **S2 a drag armed after a switch that showed a dialog** (the button-up went to the dialog, the tab
  then followed a mouse with no button). Fixed: a `WM_MOUSEMOVE` without `MK_LBUTTON` while a drag is
  pending / running or the X is pressed cancels the gesture (`CancelGesture`: glide back, capture
  released). Not drivable on the hidden desktop (needs a dialog between down and up); the release
  checklist's drag line covers the real mouse.
- **S3 the probes did not prove the live drag or the context-menu path.** Added: MOUSE MIDDRAG (capture
  while A is held 1.2 tab widths to the right: the active-tab colour at the cursor, the strip colour at
  A's old place, after `WM_CANCELMODE` A back at its place) and MENU CTXMOVE / CTXNEWAS (right-click
  on the inactive tab A / on the empty strip, the menu's accelerator posted as `WM_CHAR` - the real
  `ContextTabIndex` path). REFUSED stays NOT DRIVEN (the feature-097 `refusedTooLong` path refuses the
  *target*, it does not make the source refuse its leave).
- NOTE fixed: SVG numbers formatted by the C runtime - a decimal comma (a locale set by someone else in
  the process) is turned into a dot before parsing (`AAShape`).
- NOTE fixed: a held drag with nothing moving repainted 60 times a second - `AnimStep` reports
  whether an offset moved; the timer paints only then.
- NOTE fixed: the pressed X is bound to its tab object (`PressedCloseTab`); a key that changes the tab
  set while the button is held closes nothing.
- NOTE recorded: `WM_MOUSELEAVE` ignored when `GetCursorPos` fails is a probe seam (no effect with an
  input desktop) - see Deviations. NOTE left: the plug-in icon cache is keyed by plug-in index
  (cosmetic, until the next colour change); a refused-leave undo re-lists the other panel's previous
  tab (a closed FTP connection reconnects); Esc during a drag also reaches the focused panel.

After the fixes: `build.cmd` BUILD SUCCEEDED; saltests 282506 / 0; encoding guard TOTAL 0;
`tabs404_probe` **PASS 29, FAIL 0, NOT DRIVEN 1** (`result_after.txt`); `tabs312_probe` 33 / 0.
