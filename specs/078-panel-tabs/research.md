# Research: Panel Tabs (Phase 0)

**Feature**: 078 · **Date**: 2026-09-18 · **Inputs**: [spec.md](spec.md)
(clarified 2026-09-18, 7 decisions), [analysis.md](analysis.md) (four
architecture surveys), constitution v3.1.0, three targeted verification passes
over the source (tab-switch mechanics, strip and chrome precedents, commands /
configuration / persistence). Line numbers refer to commit `2c0cba9`.

Every open question the plan carries is resolved below; the decisions are
binding for [data-model.md](data-model.md), [contracts/](contracts/) and
`tasks.md`. Corrections to earlier documents are listed at the end.

## Where today's behaviour actually is

- A panel is `CFilesWindow` (`src/fileswnd.h:717`); the program owns exactly
  two (`CMainWindow::LeftPanel/RightPanel`, `src/mainwnd.h:418`). Everything
  that identifies a side compares pointers; the plugin ABI names panels with
  four constants (`spl_gen.h:246-249`). See `analysis.md` §2.
- Every path change funnels into `ChangePathToDisk/Archive/PluginFS/DetachedFS`
  (`src/fileswn2.cpp:1679/2051/2746/3255`) or the text-driven `ChangeDir`
  (`src/fileswn3.cpp:1959`). **All of them ask the current location to close
  (`PrepareCloseCurrentPath`, `fileswn2.cpp:1236`) before mutating any panel
  state, and on refusal return `CHPPFR_CANNOTCLOSEPATH` with the panel intact**
  (`fileswn2.cpp:2034-2036`, `2290-2297`, `2929-2937`, `3474-3480`). A disk
  location can always be closed (`fileswn2.cpp:1243-1247`); archives and plugin
  file systems decide (`CanCloseArchive`, `TryCloseOrDetach`).
- `ChangeDir` re-uses a detached plugin file system whose `IsPathFromThisFS`
  matches before opening a new one (`fileswn3.cpp:2070-2087`), and the
  Change Directory dialog seeds itself with the *external* location text
  (`GetGeneralPath(path, size, TRUE)`, `fileswn3.cpp:1987`) and replays it with
  `convertFSPathToInternal = TRUE`.
- Per-panel state that a tab must remember and where it lives:
  `Path`/`PanelType`/archive/FS (`fileswnd.h:479-505`, text form via
  `GetGeneralPath`, `fileswn1.cpp:142`), `ViewTemplate` (pointer into the
  shared `MainWindow->ViewTemplates`; index via `GetViewTemplateIndex()`,
  `fileswn2.cpp:1007`), `SortType`/`ReverseSort` (plain members,
  `fileswnd.h:781-782`), `Filter`/`FilterEnabled` (`CMaskGroup` **has** a deep
  `operator=`, `src/masks.h`), cursor (`GetCaretIndex()`, `Dirs`/`Files` split),
  `ListBox->GetTopIndex()/GetXOffset()`, `PathHistory` (`CPathHistory*`,
  no copy semantics, `src/salamand.h:163`), `TopIndexMem` (plain arrays,
  copyable, cleared by `ChangeDir`, `fileswn3.cpp:2010`),
  `UserWorkedOnThisPath` (`fileswnd.h:890`, decides whether the *leaving* path
  enters the global Working Directories list).
- Cursor/scroll restore after a listing: `CommonRefresh` resolves
  `suggestedFocusName` after the read (Dirs, then Files, exact then
  case-insensitive) and passes `suggestedTopIndex` to `RefreshListBox`
  (`fileswn1.cpp:2432-2476`); the top index is discarded when the name is not
  found (`fileswn2.cpp:4334-4336`); horizontal offset is always reset to 0
  (`fileswn1.cpp:2476`).
- Selection by name: `CNames` (`salamand.h:87`, `Add(isDir, name)`, `Sort()`,
  `Contains(isDir, name)`, no copy semantics), the `StoreSelection()` /
  `Reselect()` pair (`fileswn1.cpp:2093`, `:2118`) is the exact template.
- Per-panel persisted state: `SavePanelConfig` / `LoadPanelConfig`
  (`src/mainwnd2.cpp:1193-1218`, `2242-2314`) under `"Left Panel"` /
  `"Right Panel"`; loading is gated on the `Path` value existing; only disk
  paths are stored (`:3898`); the registry helpers `CreateKey/OpenKey/CloseKey/
  SetValue/GetValue/ClearKey/DeleteKey` (`src/consts.h:1828-1844`) go through
  the feature-004 wide facade (`src/regwork.cpp:115`, `:211`), so UTF-8 text
  round-trips.
- Panel chrome: `ToggleDirectoryLine` (`fileswn2.cpp:926-965`) is the creation
  template; panel `WM_SIZE` (`fileswnb.cpp:72-119`) stacks Directory Line,
  list, Information Line; main `WM_SIZE` offsets the Middle Toolbar by the
  taller Directory Line (`mainwnd3.cpp:5526-5540`); two popup anchors compute
  `panelTop + GetDirectoryLineHeight()` (`drivelst.cpp:2481-2489`,
  `mainwnd3.cpp:4056-4063`).
- An abandoned upstream strip skeleton exists: `src/tabwnd.{h,cpp}` — compiled,
  unreferenced, and it would not link (`DestroyWindow()` declared, never
  defined).

## Decisions

### R1 — Model: one panel object per side; a tab is remembered view state

**Decision**: Model A of `analysis.md` §3. `CFilesWindow` gains a `CPanelTabs`
member (ordered `CPanelTab` records + active index) and a `CTabWindow` strip
child. Switching tabs = snapshot the panel into the current record, apply the
target record, `ChangeDir(location)`, restore cursor/selection/scroll. No
second `CFilesWindow` per side is ever created.
**Rationale**: every command, dialog, plugin service and background mechanism
sees a tab switch as the path change it already handles; the plugin ABI, the
detached-FS model, the snooper, the icon threads, the layout and the 770
side-identity references stay untouched (`analysis.md` §3.2). Swap Panels
exchanges the two `CFilesWindow*` (`mainwnd3.cpp:4312-4350`), so a panel-owned
tab set swaps for free.
**Alternatives**: several panel windows per side (rejected — breaks the binary
panel identity, the FS ownership model, multiplies threads and watches);
caching listings in background tabs (deferred — possible later on top of
Model A, not needed for the spec).

### R2 — Location text: external form, replayed the way the Change Directory dialog does

**Decision**: a tab stores `GetGeneralPath(buf, 2 * SAL_MAX_PATH_UTF8, TRUE)`
(the *external* form for plugin file systems; unchanged text for disk and
archive) and is applied with
`ChangeDir(location, topIndex, focusName, 3, &failReason, TRUE /*convert to internal*/)`.
**Rationale**: that is the exact round trip the Change Directory dialog uses
every day (`fileswn3.cpp:1987` → `:2047-2051`), so no new conversion code and
no double conversion (verification risk #20). The external form is also what
the user recognises in the registry and in *Export Configuration*, and it
never contains a password (FR-027). `ChangeDir` accepts disk, UNC, archive and
`fsname:userpart` text uniformly (§1.2 of the verification) and re-attaches a
detached FS by path (`fileswn3.cpp:2070-2087`) — exactly the "re-use a kept
connection" behaviour of FR-019.
**Alternatives**: internal form + `convertFSPathToInternal = FALSE` (the
`OpenFocusedInOtherPanel` convention, `fileswn8.cpp:1500`) — rejected because
it is not what the registry should hold; storing the `CPluginFSInterface*` —
rejected (a background tab holds no FS, FR-019).

### R3 — What a tab record holds

**Decision**: persisted part (`CSalTabRecord`, POD, in `src/common/saltabs.h`):
location text, view template index, sort type, reverse flag, filter masks,
filter enabled. Session part (`CPanelTab`, core, `src/paneltabs.h`): focused
item name, top index, x offset, selected names (`CNames`), `TopIndexMem`
copy, `UserWorkedOnThisPath`, an owned `CPathHistory*`, and a `Visited` flag
(false for tabs restored from the registry until first activation).
**Not** carried per tab: `HiddenNames` (the *Hide* command) and `OldSelection`
(*Restore Selection*) — both are cleared by `CloseCurrentPath` on every real
leave (`fileswn2.cpp:1438-1439` and five more sites) and restoring hidden
names would force a second directory read. They stay "per visit", exactly as
they are when navigating away today; recorded in the spec Assumptions.
**Rationale**: FR-015 lists location, view, sort, filter, cursor, selection,
scroll and history; the extra session fields are what the verification showed
to be necessary to keep those promises (`TopIndexMem` is cleared by
`ChangeDir`, `UserWorkedOnThisPath` would otherwise credit one tab's activity
to another's path).

### R4 — Switch algorithm and its guards

**Decision** (`CFilesWindow::SwitchToTab(int target)`, core):

1. Refuse silently when `target == ActiveIndex`, when `FilesActionInProgress`
   (`fileswnd.h:762` — `ChangeDir` does not check it), when
   `MainWindow->HasLockedUI()`, when a switch is already in progress
   (`TabSwitchInProgress` latch, re-entrancy through message pumps in plugin
   prompts), or when the panel's history is executing a Back/Forward
   navigation (`CPathHistory::Lock`; a one-line `IsLocked()` accessor is added
   to `src/salamand.h` — swapping the history pointer mid-`Execute` would be
   use-after-swap, verification risk #2).
2. `CancelUI()`; `RefreshPathHistoryData()` (records the current cursor into
   the current tab's history, as every path change does).
3. Snapshot the current record: location (R2), view index, sort, filter,
   caret name (`GetCaretIndex()` + the `Dirs`/`Files` idiom), top index,
   x offset, selected names (`StoreSelection` loop shape into the tab's own
   `CNames`), `TopIndexMem`, `UserWorkedOnThisPath`.
4. Pre-set the fields that must be in place when the new listing is read and
   that do **not** touch visible state: `SortType`/`ReverseSort` (plain
   members, the `LoadPanelConfig` shape), `Filter.SetMasksString` +
   `PrepareMasks` (fallback `*.*`) + `FilterEnabled`. Select the view
   template in the pre-listing form
   `SelectViewTemplate(idx, FALSE, FALSE, VALID_DATA_ALL, FALSE, TRUE)`
   (`mainwnd2.cpp:2256`; `IsViewTemplateValid` first — the user may have
   blanked a template). Swap `PathHistory` to the target tab's object.
5. `ChangeDir(location, TopIndex, FocusName, 3, &failReason, TRUE)`.
6. On `CHPPFR_CANNOTCLOSEPATH` (the plugin refused, the user cancelled an
   archive update): put back sort/filter/view/history of the current tab,
   post `WM_USER_REFRESH_DIR` so icons that went "temporarily simple" recover,
   leave `ActiveIndex` unchanged — the strip and the panel agree (FR-020).
   Any other failure (location gone → `ChangeDir` already fell back to the
   nearest parent or the rescue path, FR-021) counts as success for the
   switch; the tab's location is re-captured from the panel.
7. On success: restore `TopIndexMem` (copy back — `ChangeDir` cleared it),
   re-select by names (`Reselect` shape over the tab's `CNames`), apply the
   x offset with `RefreshListBox(xOffset, ListBox->GetTopIndex(), FocusedIndex, FALSE, FALSE)`
   only when it was non-zero in Detailed view, set `UserWorkedOnThisPath`
   from the record, `ActiveIndex = target`, `Visited = TRUE`,
   `IdleRefreshStates = TRUE` (Back/Forward enablers now read the tab's
   history), repaint the strip.

**Rationale**: the order follows what the verification proved: nothing
visible is mutated before `ChangeDir` except the view template, which is
cheap to revert; the listing is read once with the right filter and sort; the
refusal path needs no new protocol. The history pointer is swapped *before*
`ChangeDir` so that `DirectoryLineSetText` (`fileswn1.cpp:1746-1766`) appends
the new location to the *target* tab's history. Implementation must verify
that `CPathHistory::AddPath` does not duplicate a path already at the top and
that `ChangeActualPathData` ignores a non-matching path (task with a
verification note); if either fails, `RemoveCurrentPathFromHistory` before
the swap is the one-call fix.
**Alternatives**: applying view/sort/filter after `ChangeDir` (second
directory read); a posted `WM_USER_*` switch message (would still need the
latch, and `lParam` lifetime issues — a tab can close before dispatch).

### R5 — New tab, duplicate, close, reorder, middle click

**Decision**:
- **New Tab** (`+`, command): a record copied from the *current* panel state
  (location, view, sort, filter), fresh history, no selection, appended at the
  end (FR-016), then `SwitchToTab(last)`. On disk the re-listing of the same
  path is a full re-read (no same-path optimisation exists for disk,
  `fileswn2.cpp:1789-1836`) — acceptable, it is a fresh tab.
- **Duplicate Tab**: same, inserted right after the original.
- **Close Tab i**: if `i` is active, `SwitchToTab(neighbour)` first
  (right, else left — FR-017); only when that succeeded is record `i` deleted
  (its history object freed). A background tab is deleted outright; it holds
  nothing (FR-019) and a detached connection stays in `DetachedFSList`
  (Clarification Q1).
- **Close Other Tabs / Close Tabs to the Right**: delete background records
  only; the active tab never moves.
- **Reorder**: move the record; `ActiveIndex` follows the moved record.
- **Middle click on a folder**: `CFilesBox` handles no `WM_MBUTTON*` today
  (`filesbx1.cpp:1277-1700`); add `WM_MBUTTONDOWN/UP` routed like
  `WM_RBUTTONDOWN` (`filesbx1.cpp:1505-1513`, with the `HasLockedUI()` check),
  hit-test with `GetIndex(x, y)` (returns `INT_MAX` on a miss,
  `filesbx1.cpp:1832`), dir test `index < Dirs->Count`, parent entry by
  `strcmp(Dirs->At(0).Name, "..") == 0`, and build the target location with
  the `OpenFocusedInOtherPanel` shape (`fileswn8.cpp:1437-1513`: disk/archive
  `GetGeneralPath` + backslash + name, UNC-root `..` → nethood, FS
  `GetFullName(*file, isDir, …)` with `isDir == 2` for `..`) — but in
  `SAL_MAX_PATH_UTF8`-sized buffers, not `2 * MAX_PATH` (risk #19). The FS
  branch yields the *internal* form; convert with
  `ConvertPathToExternal` to keep R2's single convention. Append a background
  record (FR-032, US5-1); no switch.
- **Middle click on a tab**: close (never the last).
**Rationale**: each operation is expressed through `SwitchToTab` + list
edits; the list rules are pure and unit-tested (R13).

### R6 — Strip window: rewrite `src/tabwnd.{h,cpp}`, owner-drawn, no focus

**Decision**: `CTabWindow : CWindow` (`ooStatic`, owned by `CFilesWindow`
like `DirectoryLine`), created by a `ToggleTabStrip()` modelled on
`ToggleDirectoryLine` (`fileswn2.cpp:926-965`: class `CWINDOW_CLASSNAME2`,
`WS_CHILD | WS_CLIPSIBLINGS`, no `WS_VISIBLE`, forced `WM_SIZE`,
`ShowWindow`, `MainWindow->LayoutWindows()`), child id `IDC_TABSTRIP`
(next to `IDC_DIRECTORYLINE 952` in `src/resource.rh2:318-320`). Painting:
double-buffered through the shared `ItemBitmap` cache (`Enlarge` in both
`WM_SIZE` and `WM_ERASEBKGND`, `stswnd.cpp:1806-1821`, `2325-2335`),
`EnvFont`/`EnvFontCharHeight`, colours via `ThemeSysColor*`/`ThemeDrawEdge`,
the active tab of the active panel in `HActiveCaptionBrush` +
`CurrentColors[ACTIVE_CAPTION_FG]`, the inactive panel's active tab in the
`INACTIVE_*` pair, hot tab text in `HOT_ACTIVE/HOT_INACTIVE` — the exact
`PaintSecurity` idiom (`stswnd.cpp:838-863`). Text through the wide path
(`SalU8ToWAlloc` + `DrawTextW`/`ExtTextOutW`, measured with the same API —
the `CMenuBar` style, `menubar.cpp:172-204`, `264-277`). Hot tracking with
`TrackMouseEvent`/`WM_MOUSELEAVE`, repainting only the two changed items
(`menubar.cpp:908-956`). Glyphs (`+`, `×`, `▾`) drawn with GDI using a
`ThemeSysColor(COLOR_BTNTEXT)` pen (`toolbar2.cpp:826` precedent) — no new
SVG resources (none exist for these shapes; `src/salamand.rc2:72-75`).
Height `GetNeededHeight()` = `2 + EnvFontCharHeight + 2` plus a scaled
2-pixel band, never a hard-coded 16 (the `stswnd.cpp:580-594` bug). Never
`SetFocus(strip)`, no `WS_TABSTOP`; a click does `CancelPanelsUI()` and, when
the panel is not active, `MainWindow->FocusPanel(panel)` (`mainwnd4.cpp:1263`)
before switching — the caret stays in the list (FR-011, FR-013). Honour
`MainWindow->HasLockedUI()` at the top of every mouse case
(`filesbx1.cpp:1430-1528` precedent) and add the strip to
`CFilesWindow::LockUI` (`fileswnb.cpp:1580`).
**Rationale**: the strip has no native precedent in the core (no
`SysTabControl32` anywhere); `CMenuBar` and `CStatusWindow` are the house
patterns and give theme, DPI, font and focus behaviour for free. Rewriting
the dead stub keeps the upstream file name (constitution III: keep upstream
names) without inheriting its defects.
**Alternatives**: a `CToolBar` subclass (buttons cannot shrink to variable
widths and its "adjustable" style only opens the Customize dialog,
`toolbar3.cpp:536-559`); the Win32 tab control (foreign look, takes focus,
no per-panel active/inactive colouring).

### R7 — Layout: strip above the Directory Line; two anchors corrected

**Decision**: panel `WM_SIZE` (`fileswnb.cpp:72-119`) places the strip at
`y = 0` with `GetNeededHeight()` and moves the Directory Line and list down;
the "no chrome" 3-pixel filler stays exactly one (`WM_ERASEBKGND`,
`fileswnb.cpp:121-135`). `CMainWindow::GetDirectoryLineHeight()`
(`mainwnd1.cpp:1271-1281`) changes meaning to "distance from the panel's top
edge to the bottom of the Directory Line" (strip height + Directory Line
height): both of its callers — the Alt+F1 drive-menu anchor
(`drivelst.cpp:2481-2489`) and the hot-paths popup (`mainwnd3.cpp:4056-4063`)
— want exactly that. The Middle Toolbar offset (`mainwnd3.cpp:5526-5540`)
uses the same sum.
**Rationale**: the only three places that assume the Directory Line starts
at the panel's top edge (verification §3); everything else derives
coordinates from the Directory Line's own `HWND`.

### R8 — Strip behaviour details

**Decision**: tabs share the strip width minus the `+` and list buttons;
equal widths shrink from a maximum (~20 average characters) to a minimum
(~6 characters plus glyph); titles are shortened with an ellipsis measured
with the drawing API. When even minimum-width tabs do not fit, the strip
shows a contiguous run that contains the active tab and a **tab-list button**
that opens a `CMenuPopup` of all tabs (current one checked) anchored under
the button (the `OpenDirHistory` shape, `fileswnb.cpp:1365-1390`, with
`BeginStopRefresh`/`EndStopRefresh` around `Track`) — Clarification Q3, no
scrolling. Close glyph on the active tab always and on the hovered tab; not
on the only tab (FR-012). Tooltip per tab = full location, ids `100 + index`
(`+` = 1, list button = 2), answered through `CopyToolTipAnswer`
(`src/gui.h:466`) — never `lstrcpyn`; `SetCurrentToolTip(HWindow, 0)` while
any button is down and `SetCurrentToolTip(NULL, 0)` on `WM_MOUSELEAVE`,
`WM_CANCELMODE` and every button-down (`stswnd.cpp:1957`, `2166`, `2195`,
`2236`). Drag-to-reorder copies the `CEditListBox` gesture
(`src/edtlbwnd.cpp:993-1006`, `1036-1062`, `1065-1103`, `1125-1133`:
`SetCapture` on button-down, `SM_CXDRAG/SM_CYDRAG` threshold, insert mark
while dragging, commit on `WM_LBUTTONUP`, cancel on `WM_RBUTTONDOWN` /
`WM_CANCELMODE` / Escape) with an I-beam insert mark drawn like
`CToolBar::DrawInsertMark` (`toolbar2.cpp:805-846`); `WM_SETCURSOR` returns
`TRUE` while captured. Right click opens the tab context menu (R10).
**Rationale**: every mechanism has a verified house precedent; the list
button replaces scrolling per the clarification.

### R9 — Commands, ids, menus

**Decision**: seven commands × three targets in the established
*active, left, right* order (`CM_ACTIVE_CHANGEDIR 862 / CM_LEFT_… 863 /
CM_RIGHT_… 864` pattern): `CM_ACTIVE_NEWTAB`, `CM_ACTIVE_CLOSETAB`,
`CM_ACTIVE_NEXTTAB`, `CM_ACTIVE_PREVTAB`, `CM_ACTIVE_DUPTAB`,
`CM_ACTIVE_CLOSEOTHERTABS`, `CM_ACTIVE_CLOSETABSRIGHT` and their `LEFT`/`RIGHT`
twins — 21 ids in the free block **2860-2889** at the `// FREESPACE` marker
(`src/resource.rh2:452`; the sub-3000 space is otherwise exhausted at
`CM_RIGHTMODE_10 2999`). Two popup ids `CML_LEFT_TABS`, `CML_RIGHT_TABS` in
5956-5998 (below `CML_LAST 5999`). Strings `IDS_MENU_TAB_*` (the `IDS_MENU_`
prefix gives the translator its "menu command" role) from **14212** in
`src/texts.rh2` / `src/lang/texts.rc2`, plus `IDS_TABS_*` for the strip
tooltips, the tab-list header and the "N tabs will be closed" confirmation.
A *Tabs* submenu is appended at the **end** of the *Left* and *Right* menus
(`src/menu4.cpp:21-47`, `225-251`) at skill level `MNTS_B | MNTS_I | MNTS_A`
(Clarification Q4). While tabs are off, the trailing separator + submenu are
removed in `WM_USER_INITMENUPOPUP` for `CML_LEFT`/`CML_RIGHT` with the
`RemoveItemsRange` idiom (`mainwnd3.cpp:4820-4844`, `CML_LEFT_GO`) and
re-inserted when on — `CMenuPopup` has no single-item remove and the spec
says "not offered", not "greyed". Inside the submenu, `EnableItem` greys
what cannot apply (only tab: no Close/Close Others/Close Right; no
right-hand tabs: no Close Right). Toolbar buttons: none (spec Assumptions).
**Rationale**: ids and strings follow the house allocation exactly; the
dynamic-range menu idiom already exists; the end-of-menu placement keeps
the range removal a two-item tail.

### R10 — Tab context menu

**Decision**: right click on a tab is handled inside `CTabWindow` with an
ad-hoc `CMenuPopup` (the `OnWmContextMenu` shape, `mainwnd1.cpp:2191-2208`,
`2433-2508`): small local ids mapped to the panel's `CM_LEFT_*`/`CM_RIGHT_*`
commands and **posted** as `WM_COMMAND` to the main window, never executed
inline; the clicked tab index is stored in the panel (`ContextTabIndex`) for
the duration so *Close Tab* / *Close Tabs to the Right* act on the clicked
tab, not the active one. The menu carries the `export_mnu.py` comment block
(`mainwnd1.cpp:2322-2358` convention) so the translator sees it. Right click
on the strip background opens the same menu with only *New Tab* enabled.
`CMainWindow::HitTest` gains `mwhteLeftTabStrip`/`mwhteRightTabStrip`
(`mainwnd.h:337-360`, `mainwnd1.cpp:2139-2168`) and `OnWmContextMenu` returns
early for them (the strip owns its menu); `MapClientArea`
(`mainwnd4.cpp:1515-1626`) maps them to a new `IDH_TABSTRIP` help id (free
range 143-490 at `resource.rh2:46`).
**Rationale**: keeps the strip self-contained and the main-window context
menu untouched (FR-033).

### R11 — Shortcuts: "Chrome's tab keys, plus Shift"

**Decision**: New Tab **Ctrl+Shift+T**, Close Tab **Ctrl+Shift+W**, Next Tab
**Ctrl+Shift+PgDn**, Previous Tab **Ctrl+Shift+PgUp**. All four are handled
in `CFilesWindow::OnSysKeyDown` (`src/fileswn0.cpp:1104`) *before* the
existing branches, guarded by `Configuration.PanelTabs`, posting the
`CM_ACTIVE_*` command; with tabs off the code falls through and every key
does exactly what it did (FR-003). Reservations added to `IsSalHotKey`
(`src/keyboard.cpp:601`, `:640`, `:81`, `:93` — new `case CONTROL_SHIFT:`
lines) so plugins cannot claim them. **Not** put in the accelerator tables
(`src/salamand.rc:61-129`): an accelerator is translated before the panel
sees the key, which would swallow it even with tabs off.
**Facts behind it** (verification §1): Ctrl+Shift+T and Ctrl+Shift+W do
nothing today — the letter branch (`fileswn0.cpp:1323-1333`) excludes
Ctrl+Shift, so `HandleCtrlLetter` (Ctrl+T = Go to Shortcut Target, Ctrl+W =
Restore Selection) is untouched. Ctrl+Shift+PgUp/PgDn are *undocumented
duplicates* of Shift+PgUp/PgDn (they fall through to the paging block,
`fileswn0.cpp:1954-2002`, `2108-2110`, minus the edge `forceSelect`); nothing
is lost because Shift+PgUp/PgDn keep doing it, and with tabs off the
duplicate returns. **Ctrl+Shift+Tab is not free**: the `VK_TAB` branch has no
modifier test (`fileswn0.cpp:1300-1304`), so Shift+Tab, Ctrl+Shift+Tab and
Alt+Tab-less combinations all switch panels; it is left alone. The manual's
keyboard page documents neither combination (`help/src/hh/salamand/
shortcuts_keyboard.htm`), so the help work is pure addition.
**Rationale**: one memorable rule ("Chrome's Ctrl+T / Ctrl+W / Ctrl+PgUp /
Ctrl+PgDn with Shift added"), zero documented shortcut changes meaning
(FR-031, Clarification Q2), and a symmetric next/previous pair. Corrects the
spec's parenthetical that named Ctrl+Shift+Tab (see *Corrections*).
**Alternatives**: Ctrl+Shift+Tab for Previous (rejected — it currently
switches panels, and there is no free partner for Next); letter pairs such as
Ctrl+Shift+N / Ctrl+Shift+P (free, but no relation to any convention).

### R12 — Configuration option

**Decision**: `int PanelTabs;` in `CConfiguration` next to `ShowPanelCaption`
(`src/cfgdlg.h:296`), default **`TRUE`** (`src/dialogs4.cpp:381` block —
Clarification Q1), registry value `"Panel Tabs"` (`CONFIG_PANELTABS_REG`)
under `Configuration`, saved next to `CONFIG_SHOWPANELCAPTION_REG`
(`mainwnd2.cpp:1630`) and loaded next to it (`:3170`) — a missing value keeps
the default, no `THIS_CONFIG_VERSION` bump (feature 071 precedent). Checkbox
`IDC_PANELTABS` (id **6235**, bump `_APS_NEXT_CONTROL_VALUE`, `src/lang/
lang.rh:711`) on `IDD_CFGPAGE_APPEARANCE` in the free 12-unit row at **y=75**
(`src/lang/lang.rc:1141-1168`; the page is otherwise packed), text
"Show &tabs in panels", bound with `ti.CheckBox` in
`CCfgPageAppearance::Transfer` (`dialogs5.cpp:2851`). `Validate`
(`dialogs5.cpp:2882`) gains the FR-005 confirmation: when the box is being
cleared and either panel holds more than one tab, a `SalMessageBox`
(`MB_YESNO | MB_ICONQUESTION`, text from a `LoadStrU8` template with the
count) and `ti.ErrorOn(IDC_PANELTABS)` on *No* — the `CCfgPageCmdShell::Validate`
refusal shape (`dialogs4.cpp:4460-4500`). Post-OK handling in
`WM_USER_CONFIGURATION` (`mainwnd3.cpp:1949-2034`): snapshot
`oldPanelTabs`, and when changed call `LeftPanel->SetTabsEnabled(...)` /
`RightPanel->…` (create or destroy the strip, drop background records) under
`LockWindowUpdate` + `LayoutWindows()` (the `CM_SWAPPANELS` shape) — a
`Repaint()` is not enough because the panel geometry changes.
**Rationale**: the Appearance page holds the two other "show … in Directory
line" switches; the shape of every piece has a verified precedent. Note
`CCfgPageAppearance::EnableControls()` is a no-op on this page (it references
controls of the title-bar page) — do not model on it.

### R13 — Pure logic in `src/common/saltabs.{h,cpp}`, tested in `saltests`

**Decision**: a new common module holds what needs no `CFilesWindow`:
`CSalTabRecord` (R3, POD), `SalTabTitleFromLocation()` (FR-007 rules: strip
a trailing separator; last `\`/`/` component; a drive root `C:\` and a UNC
root `\\server\share` are returned whole; for `fsname:userpart` the last
component of the user part, or the user part itself when it has no component),
`SalTabsIndexAfterClose(count, closed, active)` (FR-017), `SalTabsCycle(count,
active, forward)`, `SalTabsMove(count, from, to, &active)`, and
`SalTabRecordClamp()` (sort ∈ `[stName, stAttr]`, view index ≥ 1, empty
location = invalid). Added to `salamand.vcxproj` and
`saltests/saltests.vcxproj` exactly as `salshell.cpp` was
(`salamand.vcxproj:272-273`, `saltests.vcxproj:86-87`); `TestPanelTabs078()`
appended to `src/saltests/saltests.cpp` (`CHECK` macro, `main` call list).
The core module `src/paneltabs.{h,cpp}` (`CPanelTab`, `CPanelTabs`,
`CFilesWindow::SwitchToTab` helpers) uses it.
**Rationale**: `saltests` links only `src/common/` (`saltests.vcxproj:80-91`);
feature 071 set the precedent of lifting the testable core into
`src/common/`. Title derivation and index rules are exactly the parts that
would otherwise be tested only by hand.

### R14 — Persistence layout

**Decision**: under each of `"Left Panel"` / `"Right Panel"`:
`Active Tab` (REG_DWORD, absent → 0) and a subkey `Tabs` with `0`, `1`, …
subkeys, each holding `Path` (REG_SZ, R2 text), `View Type`, `Sort Type`,
`Reverse Sort`, `Enable Filter` (REG_DWORD) and `Filter` (REG_SZ) — the same
value names the panel uses today. `SavePanelConfig` (`mainwnd2.cpp:1193`)
writes the legacy values for the **active tab** unchanged (`Path` stays
`GetPath()`, a disk path), then `ClearKey(tabsKey)` and rewrites the list,
then `Active Tab`. `LoadPanelConfig` (`:2242`) reads the list **inside** the
existing `Path` gate; absent `Tabs` or an empty/invalid list → one record
from the legacy values (FR-029); `Active Tab` clamped; records fail closed
(`SalTabRecordClamp`). Written only from `SaveConfig` (Clarification Q5) —
no registry access on tab changes. At start-up the existing code
(`mainwnd2.cpp:3897-3926`) still applies the legacy disk `Path` of the active
tab (command-line `-l/-r/-a` still win via `leftPanelPathSet`); after the
initial listing the active record is re-captured from the panel, so an FS or
archive location that was active at exit is not reconnected (FR-028); other
records restore lazily (`Visited = FALSE`).
**Rationale**: no new value semantics, no version bump, export/import for
free (branch dump, `salamdr2.cpp:2893-2928`), an older build ignores the
subkey and reads the panel exactly as before (FR-029), and `ClearKey`
(`regwork.cpp:13-42`, recursive, wide APIs) guarantees no stale entries.

### R15 — Plugin file systems in tabs

**Decision**: leaving an FS tab (switch or close) is `PrepareCloseCurrentPath`
→ `TryCloseOrDetach` (`fileswn2.cpp:1364-1372`), unchanged; a kept connection
lands in `DetachedFSList` and `ChangeDir` re-attaches it by path on return.
Two tabs on the same FS path resolve to the same single interface (only one
panel can hold an FS at a time) — whichever is active owns it; documented in
the manual. Closing a background FS tab touches no connection
(Clarification Q1). `ClearPluginFSFromHistory` (`fileswn9.cpp:81`) and
`ClearHistory()` (`fileswn1.cpp:1571`) iterate **all** tabs' histories, not
only the panel's current pointer, so a closed FS interface is never matched
against a re-allocated one (risk #9).
**Rationale**: FR-019, Clarifications Q1/Q2; no plugin-facing change.

### R16 — Archive tabs

**Decision**: nothing new — leaving an archive tab runs today's
`PrepareCloseCurrentPath` archive branch (repack of edited files, update
prompt, `DiskCache.FlushCache`, `fileswn2.cpp:1279-1305`); returning reopens
by path. Recorded caveat: those side effects run even when the leave is then
refused (pre-existing behaviour, now reachable more often); a tab switch is
treated exactly like navigating away, which the manual says.

### R17 — Startup and active-panel interplay

**Decision**: `ChangeDir` resolves *relative* FS paths against the active
panel (`fileswn3.cpp:~2160`) and calls `CancelPanelsUI()` for both panels —
tabs always store absolute external text (R2), and a strip click on the
inactive panel focuses that panel first (FR-011), so a switch on an inactive
panel happens only through the *Left*/*Right* menu commands, with the same
side effects those commands have today.

### R18 — Repaint and state hooks

**Decision**: everywhere the Directory Line is repainted for an activation
change, the strip is too: `WM_NCACTIVATE` (`mainwnd3.cpp:5577-5594`),
`ChangePanel` (`mainwnd4.cpp:1226-1234`), `FocusPanel` (`:1263-1303`);
`CFilesWindow::SetFont()` (`fileswnb.cpp:1568-1576`) and
`OnColorsChanged()` (`fileswn0.cpp:3448-3471` — with its own unconditional
branch; the existing Directory Line branch is over-guarded on `ToolBar`) call
into the strip; `CM_SWAPPANELS` needs no tab code (panel-owned) but the
strip's active/inactive colours follow the `SetLeftPanel` re-stamp
implicitly through `GetActivePanel()`.

### R19 — Turning the option off at run time

**Decision**: `SetTabsEnabled(FALSE)`: destroy the strip window, delete every
record except the active one (their histories freed, nothing else touched —
detached connections remain listed), keep the active record so that turning
the option back on shows one tab without re-listing; relayout. With the
option off no strip exists, `SwitchToTab` is unreachable (commands hidden,
shortcuts fall through), persistence writes a one-entry list.

### R20 — Skill level, help, translations, changelog

**Decision**: all tab commands `MNTS_B | MNTS_I | MNTS_A` (Q4). Manual:
new `windows_tabstrip.htm` in the *Panel Components* chapter (after
`windows_dirline.htm`), `windows_panel.htm` mentions the strip,
`shortcuts_keyboard.htm` gains four rows modelled on the Ctrl+Shift+Left/Right
row (`:161`), `configuration_appea.htm` documents the option, `salamand.hhc`/
`.hhk` entries and an `[ALIAS]` line `IDH_TABSTRIP=hh\salamand\windows_tabstrip.htm`
(commit `66f9443` pattern; the help is authored, not shipped — feature 019).
Translations: add `tab tabs close closeothers closeright next previous other
others strip` to `uicontext._WORDS` (`tools/translate/uicontext.py:124`), use
`IDS_MENU_TAB_*` names, run the two-stage `.slt` refresh once after all
strings land (plain `build.cmd` until then), pin the *Tab* term per language
in `translations/ui-overrides.json` under a `_feature_078` note (cs "karta"
as Chrome-cs does, sk "karta", de "Registerkarte", fr "onglet", es "pestaña",
nl "tabblad", ro "filă" — verified against the machine output during the
refresh). Changelog *Added* entry states tabs are on by default and names the
option (constitution, Release Documentation); version 0.1.7 → 0.1.8, build
191 → 192 in `spl_vers.h`, `tandemcommander.iss`, `CLAUDE.md` in the ship-gate
task; interface version stays 106.

### R21 — Encoding guard and text sinks

**Decision**: all strip text is UTF-8 at rest and drawn wide; the
confirmation and tooltips are composed from `LoadStrU8` templates; the
strict `tools/check_encoding.py` rules (`mixed-composition`,
`utf8-to-legacy-sink`, `ansi-tooltip-handler`, …) stay at `TOTAL: 0`; tab
titles for names with unpaired surrogates render through the same WTF-8 →
UTF-16 path as the Directory Line (feature 066).

### R22 — Verification strategy

**Decision**: `saltests` for R13; the GUI matrix of [quickstart.md](quickstart.md)
for everything else (human step, as in 071/075): SC-001/SC-002 side-by-side
runs, the refusal cases with the local SFTP container and an edited archive,
Swap/Zoom/Drive Bars, restart and export/import, 20 tabs per side with a
file-system monitor, the encoding fixtures, all 8 languages. A committed
probe is not planned: the behaviours are observable in the running program
and the pure rules are unit-tested.

## Corrections to earlier documents (applied)

- **spec.md FR-031 and the Clarification Q2 bullet** named Ctrl+Shift+Tab as
  "verified free". It is not: any Tab combination reaching the panel switches
  panels (`fileswn0.cpp:1300-1304`). Corrected to the R11 set; the user's
  decision (keep every existing binding; free combinations) is unchanged.
- **analysis.md §2.6** listed Ctrl+Shift+Tab as free and Ctrl+Shift+PgUp/PgDn
  as "unreserved"; corrected to match R11.
- **spec.md Assumptions** gain the R3 limitation (hidden names and the
  Restore Selection memory are per visit).
- Feature 071's `Validate` lives in `src/dialogs4.cpp:4460`, and the
  `ShowPanelCaption` load is at `src/mainwnd2.cpp:3170` (analysis said
  `dialogs5.cpp` / `~3325`).
