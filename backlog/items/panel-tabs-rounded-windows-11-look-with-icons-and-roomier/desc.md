---
title: Panel tabs: taller rounded look with icons and Chrome-like mouse handling
type: improvement
status: in-progress
severity: 3
area: panels-ui
source: manual
who: both
created: 2026-11-06
updated: 2026-11-06
verified: 2026-11-06 f2d2ca59
effort: L
feature: 404
related: [panel-tabs-078-release-pass-and-leak-watch]
depends-on: []
reason: -
---

# Panel tabs: taller rounded look with icons and Chrome-like mouse handling

## Problem

The panel tab strip (feature 078) looks like Windows 95 next to Windows 11, Explorer and the browsers. Each tab has a raised 3D edge (`DrawEdge(BDR_RAISEDINNER)`). Inactive tabs are `BTNFACE` boxes moved 2 px down. The close and plus glyphs are aliased 1-px GDI lines. Text sits only 4 px from the tab edge, so the strip looks cramped. There is no icon, so tabs can be told apart only by their names, which are often shortened. The maintainer compared six HTML mockups (A flat with accent, B rounded, C underlined, D flat with icons, E = B with icons and more padding, F = E with taller tabs) and chose **variant F** for the product.

Working with tabs by mouse also falls short of Chrome:
- **Dragging:** while a tab is dragged it does not move. Only a 2-px insert mark shows where it will land, and the strip jumps on release.
- **Closing:** a press on the close glyph closes the tab at once, on button *down*. A press that slips onto the X cannot be taken back.
- **No move:** a tab cannot be moved to the other panel.
- **No other-panel location:** a new tab cannot be opened at the location of the other panel.
The maintainer asked for this mouse handling in the same item.

## Evidence

Current drawing at 7ee0f43d, `src/tabwnd.cpp`:
- metrics: `TABSTRIP_PAD 4`, `TABSTRIP_GLYPH 8`, `TABSTRIP_BAND 2`, `TABSTRIP_MIN_CHARS 6`, `TABSTRIP_MAX_CHARS 20` (lines 25-29);
- `CTabWindow::GetNeededHeight` (line 95): `2 + EnvFontCharHeight + 2 + band`, which gives 21 px at 96 DPI with Segoe UI 9 pt;
- `CTabWindow::Layout` (line 138): equal tab widths;
- `CTabWindow::GetCloseRect` (line 226) and `CTabWindow::HitTest` (line 242);
- `CTabWindow::PaintTab` (line 335), `PaintPlus` (line 411) and `Paint` (line 445): draw on the shared `ItemBitmap`.

Current mouse handling at 7ee0f43d (by reading):
- `CTabWindow::OnLButtonDown` (`src/tabwnd.cpp:479`): `case tspClose:` calls `FilesWindow->CloseTab(index)` on the press (line 503). `case tspTab:` switches to the tab and arms a drag with `SetCapture` (lines 507-520).
- `OnMouseMove` (line 527): after `SM_CXDRAG` / `SM_CYDRAG` it computes only `InsertIndex`. `PaintInsertMark` (line 434) draws a 2-px bar. `OnLButtonUp` (line 572) calls `FilesWindow->MoveTab(from, to)` once (`src/paneltabs.cpp:529`).
- A drag is cancelled on `WM_CANCELMODE` / `WM_CAPTURECHANGED` (lines 819-840). The strip never takes the keyboard focus, so it receives no Esc today. Middle-click close already acts on `WM_MBUTTONUP` (`MButtonDownIndex`, lines 870-881).
- `CTabWindow::OpenContextMenu` (line 649) builds one menu for a tab and for the empty strip, listed again in the `TabStripMenu` comment for `export_mnu.py` (line 636):
  - New Tab;
  - Duplicate Tab;
  - separator;
  - Close Tab;
  - Reopen Closed Tab;
  - Close Other Tabs;
  - Close Tabs to the Right.

  The menu returns local ids 1-6 and posts `CM_LEFT_*` / `CM_RIGHT_*` (`src/resource.rh2:456-484`; the last tab id is 2884 `CM_TOGGLEPANELTABS`; no `CM_` id uses 2885-2889, but check other id kinds before taking them).
- `CFilesWindow::NewTab` / `DuplicateTab` / `CloseTab` (`src/paneltabs.cpp:409`, `430`, `448`) copy a `CSalTabRecord`, `Tabs.Add` it and `SwitchToTab`, removing the record again when switching fails. `CloseTab` refuses the last tab, may be refused by the leave rules of an archive or plug-in file system, and keeps the tab for Reopen (`RemoveToClosed`).

The mockup renderer is `evidence/TabMock.cs`, a C# program that calls GDI through P/Invoke:
- Its variant 0 is a line-by-line port of the current `PaintTab` / `Paint`. With the program's `EnvFont` (`SPI_GETICONTITLELOGFONT`), ClearType and `GetSysColor`, it reproduced a `PrintWindow` capture of the running 0.2.0 window with **0 differing pixels**: both panel strips (786x21 and 832x21) and the whole 1639x144 window crop, on Windows 11 default colours at 96 DPI.
- Its **variant 6 is F**. All of F's metrics and colours are in the code (`Variant >= 5`, `variant == 6` in `NeededHeight`, `Rounded`, `HasIcons`, `pad`/`closePad`/`iconGap`, `grow` in `PaintSeparators`). Variant 5 (E) is the same design 4 px lower.

Images of the strip alone, six tabs in the left panel, 786 px wide at 96 DPI:
- `evidence/variantF_light_{normal,inactive,hovertab,hoverclose,hoverplus}.png` and `evidence/variantF_dark_*.png`;
- for comparison, the current look `evidence/current_light_normal.png` and `current_dark_normal.png`.

The whole HTML page with window composites stayed in the session scratchpad. It holds a capture of the maintainer's file listing, so it is not kept here.

## Expected

The tab strip is drawn as variant F. At 96 DPI the values below are in pixels, at other DPI they are scaled with `TabStripScaled`:
- Height `2 + EnvFontCharHeight + 2 + 2 + 8` (29 px at 96 DPI; 21 px today). Text, icon, X and + stay vertically centred in the area from y = 3 to the bottom. The first tab starts 8 px from the left, so the active tab's foot has room. There is no baseline line.
- The strip background is `BTNFACE` mixed 22 % toward `BTNSHADOW` (50 % in the Dark theme), through `ThemeSysColor`.
- The active tab is a rounded tab with top-corner radius 6 and outward bottom "feet" of radius 6. It runs from y = 3 to the bottom and is filled with the panel's caption background: `ACTIVE_CAPTION_BK` in the active panel with the window active, otherwise `INACTIVE_CAPTION_BK`. Its text uses the matching caption foreground. It is painted last because the feet overlap its neighbours.
- Inactive tabs have no background. Their text is `BTNTEXT` mixed 38 % toward the strip background (30 % in Dark).
- On hover, an inactive tab shows a rounded rectangle (radius 5, inset 3 px left, 2 px right, y 4 .. H-3) filled with the strip background mixed 7 % toward `BTNTEXT` (10 % in Dark). Its text becomes `BTNTEXT`.
- A 1-px separator stands between two tabs that are neither active nor hot, at y 10 .. H-8 (8 + g .. H-6-g with g = (H-25)/2, so it grows with the height). Its colour is `BTNSHADOW` mixed 30 % toward the strip background; in Dark it is `BTNHIGHLIGHT`.
- **Padding:**
  - the icon (or the text) starts 10 px from the tab's left edge;
  - a 16-px icon is followed by a 6-px gap before the title;
  - the close glyph box (8 px) ends 8 px before the right edge;
  - the title ends 6 px before the glyph.
- Min/max tab width = 6/20 average characters + 2 x 10 + 8 + 16 + 6.
- Glyphs are anti-aliased:
  - the close glyph is an X with half size 3.5 and stroke 1.2, 25 % toward the background, full colour on hover;
  - on hover the close glyph gets a circle of diameter 16 filled 14 % toward the foreground (20 % in Dark);
  - the plus glyph has half size 4.5 in the inactive-text colour;
  - on hover the plus glyph gets a circle of diameter 18 in the hover colour.
- Icons show the tab's location: a drive icon for a root, a folder icon for a directory, the archive's icon for an archive path, the plug-in's icon for a plug-in file system. The UI thread never blocks on a slow or network path, so icons are cached or generic.
- At 96 DPI in the Default and Dark themes the strip matches `evidence/variantF_*.png`. Text and rectangles must match exactly. Anti-aliased edges may differ by a shade, because the mockup used GDI+ and the program uses nanosvg.
- These behave as before: hit-testing, drag reorder (insert mark), middle-click close, tooltips, the overflow list button, the context menu and *Show tabs in panels* off. The 078 GUI driver and `tabs312_probe` stay green. A capture probe compares the strip with the evidence images.
- The look holds at 125 % and 150 % DPI (icon size from the program's DPI icon size) and stays readable under Windows High Contrast.

**Mouse and menus (as in Chrome):**
1. **Live reordering.** Pressing a tab activates it, as today. Once the mouse passes the `SM_CXDRAG` / `SM_CYDRAG` threshold:
   - The grabbed tab follows the cursor horizontally, keeping the point where it was grabbed. It is drawn on top and clamped to the tab area of its strip.
   - When the dragged tab's centre crosses a neighbour's centre, the neighbour slides one slot aside with a short ease-out animation (about 150 ms). There is no insert mark.
   - On release the tab glides into its slot and the order changes once (`MoveTab`; persistence unchanged).
   - **Esc**, losing the capture or `WM_CANCELMODE` cancels the drag: the tabs glide back to their original order.
   - Moving the mouse above or below the strip keeps the tab in it (no tear-off).
   - With Windows *Animation effects* off (`SPI_GETCLIENTAREAANIMATION`), tabs jump instead of gliding.
   - With the overflow list button shown, dragging stays within the visible run.
2. **Close on release.** A press on the X never switches or drags the tab. It shows the X as pressed: the hover circle, darker. The tab closes only when the left button is **released over the same X**. Moving off the X shows it unpressed and releasing there does nothing; moving back presses it again, like a push button. Middle-click close stays on button up.
3. **Move to Other Panel** in a tab's context menu, right after *Duplicate Tab*. It closes the tab in this panel and opens it in the other panel as that panel's active tab, at the end of its tabs:
   - The tab's record (location, view, sort, filter) is copied, as `DuplicateTab` copies it.
   - The tab never disappears from both panels: the other panel opens it first. Only when that succeeds is it closed here.
   - If closing here is refused (by the leave rules of an archive or plug-in file system), the new tab in the other panel is removed again and both panels stay as they were.
   - A moved tab is not added to Reopen Closed Tab.
   - The item is greyed when this panel has a single tab (like *Close Tab*), on the empty strip, and when the other panel shows no tabs.
4. **New Tab as Other Panel**, right after *New Tab*. It opens a new tab in this panel at the **location the other panel shows now**: the other panel's active tab is captured first (`CaptureActiveTab`). The view, sort and filter are those *New Tab* gives.
   - The menu is shared by a tab and the empty strip, so the item appears in both. It does not depend on the clicked tab.
   - It is greyed when the other panel has no location to give.
5. Both new commands are `CM_LEFT_*` / `CM_RIGHT_*` (and `CM_ACTIVE_*` if the Tabs submenus of the Left / Right menus get them too) with new ids. The `TabStripMenu` comment is updated for `export_mnu.py`.
6. The new strings (*Move to Other Panel*, *New Tab as Other Panel*) go into free slots of an existing string bundle. The two-stage `.slt` refresh with pins for de / fr / nl / es runs in the same run (CLAUDE.md, rule 084).
7. A probe drives all this on the hidden desktop with posted mouse messages: the order after a drag, the cancel by losing the capture, no close on a press without release, close on release, both menu commands (the context menu itself through its commands), and refused leave rules leaving both panels unchanged. Esc during a drag and the feel of the animation need a real keyboard and mouse. They are recorded as NOT DRIVEN and as a person's step.

## Approach

- The core has no GDI+. Draw the anti-aliased shapes (tab outline with feet, hover pills, circles, X and +) with the vendored nanosvg (`src/svg.cpp`, `nanosvgrast`): rasterize a path into a 32-bit premultiplied DIB and `AlphaBlend` it onto `ItemBitmap`. The fixed glyphs can be SVG resources like `SVGArrowDropDown`.
- Text stays GDI `DrawTextW` with `EnvFont`.
- `Layout` and `HitTest` keep equal widths. Only the metrics change.
- Measure first: capture the strip on the hidden desktop and compare it with the evidence images, for example by porting `TabMock.cs`'s compare loop.
- Icons:
  - find what the core already has for drives, folders, archives and plug-in file systems: the drive bar, `CPluginData` icons, the icon reader thread;
  - for a remembered tab that is not shown, prefer a generic icon from its location type to a shell call.
- Live drag:
  - keep a per-tab drawn x offset;
  - animate with a window timer, roughly 60 fps, that stops when every offset reaches its slot;
  - paint the dragged tab last.
- The strip never has the focus, so Esc during a drag must be seen another way: a check of `GetAsyncKeyState(VK_ESCAPE)` in the drag timer, or a hook of the panel's key handling while `Dragging`. Choose one and record it.
- Pure parts go to `src/common/saltabs.*` under `saltests`:
  - slot from the cursor, threshold crossing, target index;
  - the order after a drag and after a cancel;
  - enabling rules of the two menu items.
- Move to Other Panel can be built from the existing pieces:
  - `CaptureActiveTab` on the source if the tab is active;
  - copy the `CSalTabRecord`;
  - `other->Tabs.Add` + `other->SwitchToTab`, removed again on failure;
  - then the source's `CloseTab` path without `RemoveToClosed`;
  - on refusal, remove the target tab and switch the other panel back to its previous active tab.

## Notes

- Mockups were reviewed in this session on 2026-11-06. The maintainer first chose E and asked for the item first in *Next*. They then chose F (E with the strip 29 px instead of 25 px high) to be implemented instead.
- The strip is 8 px higher than today, so a panel shows about half a list row less. The maintainer accepted this by choosing F.
- `who: both`: a person judges the final look on a real screen (hover with a real mouse, Dark theme, 125/150 % DPI, High Contrast).
- Not decided: whether the classic look stays as an option (constitution principle *UI consistency*). Ask before closing if the implementation finds a reason to keep it.
- Not verified: how archive and plug-in file-system icons can be obtained without a blocking call.
- 2026-11-06, the maintainer added the mouse and menu part (Expected, *Mouse and menus*):
  - from the Chrome list: live reordering only;
  - not wanted: dragging a tab onto the other panel's strip, keeping tab widths while closing with X, double-click on the empty strip for a new tab;
  - their own wishes: close on release, *Move to Other Panel*, *New Tab as Other Panel*.
- Assumed, not stated by the maintainer (ask if the implementation finds them wrong):
  - a moved tab goes to the **end** of the other panel's tabs and becomes active there;
  - which panel is active afterwards is left to the existing `SwitchToTab` rules;
  - *New Tab as Other Panel* copies only the location, and also shows in a tab's menu because the menu is shared.
- Not verified: opening the same plug-in file-system location in both panels (for example SFTP) works as *Duplicate Tab* does within one panel, with a second connection.
- **One feature, never split** (maintainer decision 2026-11-06). Everything in this item is implemented in **one** feature on one branch: the look, the icons, the mouse handling, both commands and the translations. A run must not end with the outcome `split` or create part items, even though the item is large (`/tandem-backlog-implement` step 3, row *larger than one feature*, does not apply). Order of work inside the feature: look first, then icons, then the mouse handling and the commands.

## Log

- 2026-11-06 — created (source manual)
- 2026-11-06 — body written: variant E specification from the 2026-11-06 mockups, renderer and strip images in evidence/
- 2026-11-06 — moved to Next position 1
- 2026-11-06 — maintainer decision 2026-11-06: implement variant F (variant E with a 29 px strip) instead of E; evidence images and renderer replaced
- 2026-11-06 — maintainer decision 2026-11-06: add Chrome-like live reordering, close on release, Move to Other Panel and New Tab as Other Panel
- 2026-11-06 — maintainer decision 2026-11-06: the whole item is one feature; a run never splits it into several items
- 2026-11-06 — verified at f2d2ca59: still present at f2d2ca59: tabwnd.cpp unchanged since 7ee0f43d - DrawEdge 3D tabs, 21 px strip, aliased glyphs, no icons, close on WM_LBUTTONDOWN, insert-mark drag, no other-panel commands
- 2026-11-06 — run started, feature 404
