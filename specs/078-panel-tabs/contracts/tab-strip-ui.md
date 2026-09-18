# Contract: the tab strip (`CTabWindow`)

**Feature**: 078 · **Files**: `src/tabwnd.h`, `src/tabwnd.cpp` (rewritten),
owner `CFilesWindow` (`src/fileswnd.h`) · **Research**: R6–R8, R10, R18

## 1. Placement and lifetime

- One strip per panel, child of the panel window, at the panel's top edge,
  above the Directory Line; created and destroyed by
  `CFilesWindow::ToggleTabStrip()` (modelled on `ToggleDirectoryLine`,
  `src/fileswn2.cpp:926-965`): class `CWINDOW_CLASSNAME2`,
  `WS_CHILD | WS_CLIPSIBLINGS`, created **without** `WS_VISIBLE`, child id
  `IDC_TABSTRIP`, forced panel `WM_SIZE`, then `ShowWindow`, then
  `MainWindow->LayoutWindows()`.
- Exists iff `Configuration.PanelTabs` is on; destroyed in the panel's
  `WM_DESTROY` with the `DestroyWindow(); delete; = NULL` sequence used for
  the Directory Line (`src/fileswnb.cpp:1112-1114`). `ooStatic`.
- Height: `GetNeededHeight()` = `2 + EnvFontCharHeight + 2` + a DPI-scaled
  2-pixel band (`GetScaleForSystemDPI()`); no hard-coded pixel sizes.
- Layout consequences: panel `WM_SIZE` stacks strip / Directory Line / list /
  Information Line; `CMainWindow::GetDirectoryLineHeight()` returns strip +
  Directory Line height (used by the Alt+F1 drive-menu anchor and the
  hot-paths popup); the Middle Toolbar offset adds the strip height.

## 2. Items

```
+-------------------------------------------------------------------+
| [ Work        ×] [ Photos ] [ Music ] [ + ]                   [ ▾ ]|   <- ▾ only when tabs are hidden
+-------------------------------------------------------------------+
```

| Item | Rule |
|---|---|
| Tab | Title = `SalTabTitleFromLocation(Location)`; text drawn wide (`SalU8ToWAlloc` + `DrawTextW`), measured with the same API; shortened with an ellipsis when narrower than its text. |
| Close glyph `×` | Drawn on the active tab and on the hovered tab; **never** on the only tab (FR-012). GDI lines with a `ThemeSysColor(COLOR_BTNTEXT)` pen. |
| `+` button | After the last visible tab; opens a new tab at the current location (FR-016). |
| Tab-list button `▾` | Right end; shown only when not all tabs fit; opens a `CMenuPopup` listing every tab of the panel (titles; the active one checked; full location as the item's hint where the menu supports it), anchored under the button with `MENU_TRACK_VERTICAL` and an exclude rect; `BeginStopRefresh`/`EndStopRefresh` around `Track`. Choosing an item activates that tab. |

**Widths**: `available = stripWidth − widthOf(+) − (widthOf(▾) if needed)`.
Tabs get equal widths clamped to `[minTabWidth, maxTabWidth]` where
`maxTabWidth` ≈ 20 average characters of `EnvFont` and `minTabWidth` ≈ 6
characters + glyph. When `count × minTabWidth > available`, only a
contiguous run that includes the active tab is shown (the run is chosen to
keep the active tab visible and otherwise to start at the first tab), and
the `▾` button appears. The strip never scrolls (Clarification Q3).

## 3. Colours and fonts

| Element | Source |
|---|---|
| Strip background | `HDialogBrush` (as the Directory Line) |
| Active tab, active panel | `HActiveCaptionBrush` fill, `CurrentColors[ACTIVE_CAPTION_FG]` text |
| Active tab, inactive panel | `HInactiveCaptionBrush` fill, `CurrentColors[INACTIVE_CAPTION_FG]` text |
| Background tab | `ThemeSysColorBrush(COLOR_BTNFACE)` fill, `ThemeSysColor(COLOR_BTNTEXT)` text |
| Hovered tab / hovered glyph | text in `CurrentColors[HOT_ACTIVE]` / `[HOT_INACTIVE]` per panel activity (the `PaintSecurity` idiom, `src/stswnd.cpp:838-863`) |
| Borders | `ThemeDrawEdge` (flat in the Dark theme) |
| Font | `EnvFont`; re-fonted from `CFilesWindow::SetFont()` |

"Active panel" = `FilesWindow == MainWindow->GetActivePanel() && MainWindow->CaptionIsActive`.
Repainted on `WM_NCACTIVATE`, `ChangePanel`, `FocusPanel`, `OnColorsChanged`,
theme change and after every tab-set change (`InvalidateAndUpdate`).

## 4. Mouse

All handlers start with `if (MainWindow->HasLockedUI()) break;`.

| Gesture | Behaviour |
|---|---|
| Left click on a tab | `CancelPanelsUI()`; if the panel is not active, `MainWindow->FocusPanel(panel)`; then `SwitchToTab(index)`. Focus never lands on the strip (FR-011, FR-013). |
| Left click on `×` | Close that tab (`CloseTab(index)`). |
| Left click on `+` | New tab at the current location, becomes active. |
| Left click on `▾` | Tab-list popup (§2). |
| Middle click on a tab | Close that tab (not the only one). |
| Left drag of a tab past the `SM_CXDRAG` threshold | Reorder with an I-beam insert mark (`CEditListBox` gesture, `src/edtlbwnd.cpp:993-1103`); commit on button-up, cancel on right button, `WM_CANCELMODE` or Escape; `WM_SETCURSOR` returns `TRUE` while captured. |
| Right click on a tab | Context menu (§6) for that tab. |
| Right click on strip background | Context menu with only *New Tab* enabled. |
| Hover | Hot tracking via `TrackMouseEvent` / `WM_MOUSELEAVE`; only the two changed items are repainted. |
| Any click while the application is in the background | Raises the main window (`SetForegroundWindow`) without moving the caret (the `CStatusWindow` `WM_RBUTTONUP` postlude). |

## 5. Tooltips

`WM_USER_TTGETTEXT` ids: `0` none, `1` = "+" (`IDS_TABS_TT_NEW`), `2` = list
button (`IDS_TABS_TT_LIST`), `100 + index` = the tab's full `Location`.
Answers are written with `CopyToolTipAnswer` (`src/gui.h:466`).
`SetCurrentToolTip(HWindow, 0)` while any mouse button is down;
`SetCurrentToolTip(NULL, 0)` on `WM_MOUSELEAVE`, `WM_CANCELMODE` and every
button-down.

## 6. Context menu (owned by the strip)

Local ids mapped to the panel's side-specific commands and **posted** as
`WM_COMMAND` to the main window; `ContextTabIndex` set for the duration so
*Close Tab* and *Close Tabs to the Right* act on the clicked tab.

| Item | Command | Enabled when |
|---|---|---|
| New Tab | `CM_{LEFT,RIGHT}_NEWTAB` | always |
| Duplicate Tab | `CM_{LEFT,RIGHT}_DUPTAB` | a tab was clicked |
| — | | |
| Close Tab | `CM_{LEFT,RIGHT}_CLOSETAB` | a tab was clicked and count > 1 |
| Close Other Tabs | `CM_{LEFT,RIGHT}_CLOSEOTHERTABS` | count > 1 |
| Close Tabs to the Right | `CM_{LEFT,RIGHT}_CLOSETABSRIGHT` | tabs exist right of the clicked one |

Carries the `export_mnu.py` comment block (`MENU_TEMPLATE_ITEM TabStripMenu[]`)
so the translator sees the strings.

## 7. Integration points that must know the strip

`CMainWindowsHitTestEnum` (+ `mwhteLeftTabStrip`, `mwhteRightTabStrip`),
`CMainWindow::HitTest`, `OnWmContextMenu` (returns for the strip — it owns
its menu), `MapClientArea` → `IDH_TABSTRIP`, `CFilesWindow::SetFont`,
`OnColorsChanged` (own unconditional branch), `LockUI` (`EnableWindow` on
the strip), the three activation repaint sites (§3), panel `WM_SIZE` /
`WM_ERASEBKGND`, main `WM_SIZE` (Middle Toolbar offset),
`GetDirectoryLineHeight`.

## 8. Accessibility / limits

No keyboard focus, no RTL mirroring (none exists in the core), system-DPI
scaling only (no `WM_DPICHANGED` in the application). Text is UTF-8 → UTF-16
end to end; unpaired surrogates render as the Directory Line renders them.
