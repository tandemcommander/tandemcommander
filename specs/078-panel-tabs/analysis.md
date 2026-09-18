# Panel Tabs — Codebase Analysis and Implementation Preparation

**Feature**: `078-panel-tabs` · **Date**: 2026-09-18 · **Baseline**: Tandem
Commander 0.1.7 (build 191), plugin interface 106, `THIS_CONFIG_VERSION` 105

This document is the "detailed analysis" the request asked for. It records
how the two file panels work today, everything in the program that assumes
there are exactly two of them, and the design direction that lets tabs be
added without breaking that assumption. It is the input for `/speckit-plan`;
the user-facing behaviour it implies is specified in `spec.md`.

Sources: four independent read-only surveys of `src/` (panel architecture;
configuration and persistence; UI surfaces, shortcuts and menus; plugin and
cross-panel contracts), spot-checked by hand. Line numbers are as of commit
`2c0cba9` on `main`.

---

## 1. Summary

1. **A panel is one object, `CFilesWindow`, and the program knows exactly
   two of them** — `CMainWindow::LeftPanel` / `RightPanel`
   (`src/mainwnd.h:418`) plus `ActivePanel` (`:317`). Side identity is
   derived by *pointer comparison* (`this == MainWindow->LeftPanel`), not by
   a stored field. Roughly **770 direct references** in 38 non-plugin files
   (411 `LeftPanel`, 357 `RightPanel`), 186 `GetActivePanel()` and 32
   `GetNonActivePanel()` calls, 52 side-keyed command IDs, and 17 inlined
   `== LeftPanel ? PANEL_LEFT : PANEL_RIGHT` ternaries depend on it.
2. **The plugin ABI is binary about panels.** `PANEL_LEFT/RIGHT/SOURCE/TARGET`
   (`spl_gen.h:246-249`) are used by 49 SDK methods and 224 sites in bundled
   plugins; `GetSourcePanel()` can only answer LEFT or RIGHT; three
   `CPluginDataInterfaceAbstract` methods take a `BOOL leftPanel`; the COM
   automation plugin exposes a 2-slot `Salamander.LeftPanel/RightPanel`.
   None of this can widen without a vtable change (the only two ABI changes
   since 2023, versions 105 and 106, were pure appends).
3. **Consequently, "several `CFilesWindow`s per side" is the wrong model.**
   The right one is: *each side keeps its single panel object; a tab is the
   remembered view state of that panel; switching tabs = save the current
   state, then change the panel's path to the target tab's location
   (`ChangeDir`) and restore the target's state.* From the point of view of
   every command, dialog, plugin and background mechanism, a tab switch is an
   ordinary path change — the code path that runs a thousand times a day.
   Section 3 makes the case; section 4 lists the touch points.
4. **What exists already helps**: an abandoned upstream tab-strip skeleton
   (`src/tabwnd.{h,cpp}`, compiled, unreferenced), `CMenuBar` as a
   hot-tracking text-strip precedent, `CToolBar`'s insert-mark drag support,
   a per-panel registry key layout that can grow a `Tabs` subkey without a
   configuration-version bump (feature 071 precedent), a *Restore Selection*
   mechanism for re-selecting by name, and `ChangeDir`'s documented
   resolution order "active FS, then a detached FS, then a new FS" — which is
   exactly what returning to a plugin-file-system tab needs.
5. **What is genuinely new**: the strip window (paint, hit test, tooltips,
   drag-reorder), the per-panel tab model and its persistence, a dozen
   commands with IDs/strings/menu entries/shortcuts, a checkbox on the
   Appearance page with a "tabs will be closed" confirmation, help pages, and
   the two-stage translation refresh. Nothing in the plugin SDK, the snooper,
   the icon threads, the layout of the main window or the two-panel command
   handlers needs to change.

---

## 2. How the panels work today

### 2.1 Objects and lifetime

| Thing | Where | Note |
|---|---|---|
| `CFilesWindowAncestor : CWindow` | `src/fileswnd.h:476` | private core: path/type/archive/FS state |
| `CFilesWindow : CFilesWindowAncestor` | `src/fileswnd.h:717`; `fileswn0.cpp` … `fileswnb.cpp` (~28k lines) | the panel |
| `CMainWindow::LeftPanel, RightPanel` | `src/mainwnd.h:418` | created in main `WM_CREATE`, `src/mainwnd3.cpp:1128-1163` — **before** the configuration is read |
| `CMainWindowAncestor::ActivePanel` | `src/mainwnd.h:317` | "either LeftPanel or RightPanel" |
| Panel children | `src/fileswnb.cpp:1024-1091` | `ListBox` (`CFilesBox`), `StatusLine` and `DirectoryLine` (both `CStatusWindow`, distinguished by `blTop`/`blBottom`) |
| Destruction | `src/fileswnb.cpp:1093-1117`, `src/common/winlib.cpp:443` | panel objects are `ooAllocated`; winlib deletes them after `WM_NCDESTROY`; nothing ever `delete`s `LeftPanel` |
| Per-panel resources | `src/fileswn1.cpp:1374-1528` | **one icon-reader thread**, one `CIconCache`, four critical sections, `PathHistory`, `ContextSubmenuNew` per panel |

The panel window has no child ID (`NULL` menu) — everything addresses it by
`HWND` or pointer. Side identity is computed on demand:

```cpp
// src/fileswn9.cpp:72-76
int CFilesWindow::GetPanelCode()
{ return (MainWindow != NULL && MainWindow->LeftPanel == this) ? PANEL_LEFT : PANEL_RIGHT; }
```

and stamped into the Directory Line at creation
(`DirectoryLine->SetLeftPanel(MainWindow->LeftPanel == this)`,
`src/fileswnb.cpp:1051`), which selects the side's toolbar layout
(`Configuration.LeftToolBar` / `RightToolBar`, `src/cfgdlg.h:318-319`), the
Change Drive command (`CM_LCHANGEDRIVE` / `CM_RCHANGEDRIVE`) and the Zoom
command.

### 2.2 The state that defines "one view" (= one tab)

All of it lives on the panel object (`src/fileswnd.h`):

| Group | Members | Lines |
|---|---|---|
| Location | `Path`, `PanelType` (`ptDisk` / `ptZIPArchive` / `ptPluginFS`), `ZIPArchive` + `ZIPPath`, `PluginFS` (encapsulation), `PluginFSDir`, `ArchiveDir` | 479-505; text form via `GetGeneralPath()` (`fileswn1.cpp:142-215`) |
| Listing | `Files`, `Dirs`, `PluginData`, `SelectedCount` | 509-520 |
| View | `ViewTemplate` (pointer into the **shared** `MainWindow->ViewTemplates`), `Columns`, `ValidFileData`, `SortType`, `ReverseSort` | 720-784 |
| Filter | `Filter` (`CMaskGroup`), `FilterEnabled` | 843-844 |
| Cursor / scroll | `FocusedIndex`, `NextFocusName`, `TopIndexMem` (50-level stack), list box `TopIndex`/`XOffset` (`src/filesbox.h:125-149`) | 787-790, 853 |
| History | `PathHistory` (`CPathHistory*`, per panel, back/forward, **not persisted**) | 833 |
| Chrome | `DirectoryLine`, `StatusLine`, `HeaderLineVisible`, … | 768-774 |
| Watching | snooper registration keyed by `CFilesWindow*` (`src/snooper.h:22-26`), `DeviceNotification` | 799 |
| Transient UI | quick search, quick rename, drag state, `FilesActionInProgress`, `CanDrawItems`, refresh timers | 761-900 |

Persisted per side today (`SavePanelConfig`/`LoadPanelConfig`,
`src/mainwnd2.cpp:1193-1218` / `2242-2314`, keys `"Left Panel"` /
`"Right Panel"`, `:185-186`): `Path`, `View Type`, `Sort Type`,
`Reverse Sort`, `Directory Line`, `Status Line`, `Header Line`,
`Enable Filter`, `Filter`. Only **disk** paths are stored — comment at
`mainwnd2.cpp:3898`: "we don't store archives or FS paths". Loading is gated
on the `Path` value existing (`:2248`). Which side had focus is
`"Right Panel Focused"` (`:243`).

### 2.3 The "change path" surface

Everything funnels into a handful of `CFilesWindow` methods
(`src/fileswnd.h` / `fileswn2.cpp`, `fileswn3.cpp`):
`ChangePathToDisk` (`fileswn2.cpp:1679`), `ChangePathToArchive` (`:2051`),
`ChangePathToPluginFS` (`:2746`), `ChangePathToDetachedFS` (`:3255`), and the
text-driven **`ChangeDir(newDir, suggestedTopIndex, suggestedFocusName, …)`**
(`fileswn3.cpp:1959`) that the Change Directory dialog, the command line and
plugins' `ChangePanelPath` use. Leaving the current location is
`PrepareCloseCurrentPath` / `CloseCurrentPath` (`fileswn2.cpp:1236`, `:1416`):
an archive is closed (with the "update archive?" offer if edited files are in
the disk cache), a plugin FS is asked `TryCloseOrDetach` and either closed or
moved to the global `DetachedFSList` (`fileswn2.cpp:1520-1578`,
`FSE_DETACHED` fired with `GetPanelCode()`).

`ChangeDir` documents its FS resolution order at `fileswn3.cpp:2062`:
*"active FS, one of the detached FS, then new FS"* — i.e. entering an FS path
by text re-uses a detached connection whose `IsOurPath` matches before
opening a new one.

### 2.4 Configuration, dialog, persistence

- `CConfiguration` (`src/cfgdlg.h:178`), defaults in the constructor
  (`src/dialogs4.cpp:269`); registry value names in one table
  (`src/mainwnd2.cpp:165-541`); `SaveConfig` (`:1220`) / `LoadConfig`
  (`:2364`). Panel-appearance switches sit at `cfgdlg.h:292-299`
  (`ShowPanelCaption`, `ShowPanelZoom`).
- `THIS_CONFIG_VERSION = 105` (`src/mainwnd2.cpp:147`). **Feature 071 added
  three values without a bump** — a missing value keeps the constructor
  default (`specs/071-configurable-command-shell/contracts/command-shell-setting.md:22-25`);
  the constitution forbids a MINORB release from moving configuration.
- Export dumps the whole registry branch and strips only names ending in
  `.hidden` (`src/salamdr2.cpp:2893-2928`, `src/reglib/src/reginmem.cpp:606-630`)
  → new keys/values travel with *Export Configuration* automatically.
- The Configuration dialog is a tree of pages added in a fixed order
  (`src/dialogs4.cpp:683-741`); the **Appearance** page
  (`IDD_CFGPAGE_APPEARANCE`, `src/lang/lang.rc:1141-1168`,
  `CCfgPageAppearance::Transfer` at `src/dialogs5.cpp:2850`) holds the two
  existing "show … in Directory line" checkboxes and has room for a third.
  Adding a checkbox to an existing page does **not** touch the hard-coded
  page-index map that bit feature 071 (`dialogs4.cpp:685-694`).
- Post-OK handling that already re-lays panels out for changed appearance
  options: `WM_USER_CONFIGURATION` after `IDOK`, `src/mainwnd3.cpp:1949-1990`.
- Exit: `WM_USER_CLOSE_MAINWND` (`src/mainwnd3.cpp:6221-6823`);
  `if (Configuration.AutoSave) SaveConfig();` at `:6779`. Both panels are
  closed in a fixed order with rollback (`:6716-6756`).

### 2.5 Panel chrome, layout, painting

- Panel `WM_SIZE` (`src/fileswnb.cpp:72-120`) stacks Directory Line
  (`GetNeededHeight()`), list box, Information Line. **A strip above the
  Directory Line is one more height and one more `DeferWindowPos` here.**
- Main `WM_SIZE` (`src/mainwnd3.cpp:5448-5575`) positions the two panels and
  offsets the Middle Toolbar by the taller Directory Line (`:5526-5540`) —
  the one place main-window layout reads panel-chrome height; a strip must
  be added to that offset.
- `CStatusWindow::Paint` (`src/stswnd.cpp:872-1345`): owner-drawn,
  double-buffered, `EnvFont`, active/inactive caption brushes
  (`HActiveCaptionBrush` / `HInactiveCaptionBrush`,
  `CurrentColors[ACTIVE_CAPTION_*]` / `[INACTIVE_CAPTION_*]`,
  `src/consts.h:1281-1284`), text via `DrawTextSeg`/`DrawEllipsis` (wide
  path when the UTF-8 mirror is valid — the feature-010 convention). Theme
  helpers: `ThemeSysColor*`, `ThemeDrawEdge`, `IsDarkThemeActive()`
  (`src/themes.h`). DPI: system-aware only, no `WM_DPICHANGED`;
  `GetScaleForSystemDPI()` / `IconSizes[]`.
- Title derivation precedent: `CMainWindow::GetFormatedPathForTitle`
  (`src/mainwnd1.cpp:1763-1908`), mode `TITLE_BAR_MODE_DIRECTORY` = "last
  component only", already handles disk/archive/FS via
  `GetNextDirectoryLineHotPath`.
- Tooltips: one shared `CToolTip`; a control calls `SetCurrentToolTip` and
  answers `WM_USER_TTGETTEXT` (`src/stswnd.cpp:1826-1912`).
- Hit testing / context menus: `CMainWindowsHitTestEnum`
  (`src/mainwnd.h:337-360`), `CMainWindow::HitTest` (`src/mainwnd1.cpp:2139-2168`),
  `OnWmContextMenu` (`:2173-2660`, with the comment blocks the translator's
  `export_mnu.py` reads — keep in sync), `MapClientArea` (`src/mainwnd4.cpp:1570`)
  for Shift+F1.
- **Dead precedent**: `CTabWindow` in `src/tabwnd.h:9-26` / `src/tabwnd.cpp`
  (74 lines; `GetNeededHeight()` = `2 + EnvFontCharHeight + 2`, empty message
  handlers, a commented-out `CTabItem` array), compiled
  (`src/vcxproj/salamand.vcxproj:570, 870`) and referenced from nowhere.
  Upstream started a per-panel tab strip and abandoned it.
- Live precedents for a strip: `CMenuBar` (`src/menu.h:472`, `menubar.cpp` —
  variable-width text items, hot tracking, `HitTest`, theme colours) and
  `CToolBar` (`src/toolbar.h:14-200` — `InsertMarkHitTest`/`SetInsertMark`
  for drag-reorder, cached bitmap painting). No native `SysTabControl32`
  is used anywhere in the core.

### 2.6 Keyboard, menus, commands

Four layers: accelerator tables `IDA_MAINACCELS1/2` (`src/salamand.rc:61-129`,
skipped in `EditMode` / quick rename / inactive caption),
`CFilesWindow::OnSysKeyDown` (`src/fileswn0.cpp:1104-2146`),
`CMainWindow::HandleCtrlLetter` (`src/mainwnd4.cpp:1084-1196`), plugins last.
`IsSalHotKey` (`src/keyboard.cpp:14-1024`) is the declarative reservation
list that keeps plugins from stealing a shortcut — **every new shortcut must
be added there**. Menus are code templates (`MainMenuTemplate[]`,
`src/menu4.cpp:17-261`); the Left/Right menus (`:21-47`, `:225-251`) already
hold the per-panel chrome toggles under *Show*; check/enable state is set in
`WM_USER_INITMENUPOPUP` (`src/mainwnd3.cpp:4845+`). Adding a command:
`CM_*` in `src/resource.rh2`, `IDS_*` in `src/texts.rh2` (next free 14212)
+ text in `src/lang/texts.rc2`, template row, `WM_COMMAND` case in
`mainwnd3.cpp`, enabler, accelerator + `keyboard.cpp`, optional toolbar
button (`src/toolbar4.cpp`, `TBBE_*`, SVG icon).

**Shortcut inventory relevant to tabs** (verified in `keyboard.cpp`,
`salamand.rc`, `fileswn0.cpp`, `mainwnd4.cpp`):

| Shortcut | Status | Bound to |
|---|---|---|
| Ctrl+T | taken | `CM_AFOCUSSHORTCUT` — Go to Shortcut or Link Target |
| Ctrl+W | taken | `CM_RESELECT` — Restore Selection |
| Ctrl+Tab | taken | `CM_EDITLINE` — focus the command line |
| Ctrl+PgUp / Ctrl+PgDn | taken | parent directory / enter |
| Ctrl+1…9, Ctrl+0 | taken | hot paths (Ctrl+Shift+n assigns them) |
| Ctrl+N | taken | Smart Column Mode |
| Ctrl+U | taken | Swap Panels |
| Ctrl+Shift+Left/Right | taken | Open in other panel |
| **Ctrl+Shift+T** | **free** | — |
| **Ctrl+Shift+W** | **free** | — (`'W'` reserves NONE/CONTROL/ALT/SHIFT only) |
| Ctrl+Shift+Tab | taken (undocumented) | any Tab combination that reaches the panel switches panels (`fileswn0.cpp:1300-1304` has no modifier test); `keyboard.cpp` reserves only NONE/CONTROL |
| **Ctrl+Shift+N**, **Ctrl+Shift+Z** | free | — |
| Ctrl+Shift+PgUp/PgDn | unreserved | falls through to Shift+PgUp/PgDn (select + page) in `OnSysKeyDown` — undocumented side effect |
| **Middle click on an item** | **free** | `CFilesBox` handles no `WM_MBUTTON*` |

Decided in planning (research R11, "Chrome's tab keys with Shift added"):
Ctrl+Shift+T (new), Ctrl+Shift+W (close), Ctrl+Shift+PgUp (previous),
Ctrl+Shift+PgDn (next); the PgUp/PgDn pair replaces an undocumented
duplicate of Shift+PgUp/PgDn only while tabs are on.
Chrome's own keys cannot be used without displacing three existing commands;
decided (spec Clarifications, 2026-09-18): existing bindings stay, the tab
commands use the free set.

### 2.7 Plugin and cross-panel contracts (must not change)

- `CMainWindow::GetPanel(int)` (`src/mainwnd4.cpp:2082-2099`) maps the four
  `PANEL_*` constants to `LeftPanel` / `RightPanel` / active / non-active; all
  35 panel-taking `CSalamanderGeneral` exports funnel through it (34 call
  sites in `src/zip.cpp`).
- `GetSourcePanel()` (`zip.cpp:1356-1368`), `GetPanelWithPluginFS`
  (`:2743`), `PostRefreshPanelFS2` (`:2288-2320`), `IsFileEnumSourcePanel`
  (`src/salamdr6.cpp:108-142`) answer LEFT or RIGHT only.
- FS events `FSE_OPENED/DETACHED/ATTACHED/PATHCHANGED/ACTIVATEREFRESH/
  CLOSEORDETACHCANCELED` carry the side (`spl_fs.h:104-144`);
  `PLUGINEVENT_PANELACTIVATED` carries LEFT/RIGHT, `PLUGINEVENT_PANELSSWAPPED`
  nothing (`spl_base.h:451-456`).
- `SetupView(BOOL leftPanel, …)`, `ColumnFixedWidthShouldChange`,
  `ColumnWidthWasChanged` (`spl_com.h:760/777/785`) — a boolean.
- `CanCloseArchive(…, int panel)` (`spl_arc.h:133`); `DisconnectFS(…, BOOL
  isInPanel, int panel, …)` (`spl_fs.h:885`).
- `CCommandLineParams` in shared memory (`src/tasklist.h:68-88`: `LeftPath`,
  `RightPath`, `ActivePath`, `ActivatePanel`) — frozen for older instances.
- Automation plugin: 2-slot `m_apPanels`
  (`src/plugins/automation/salamanderaut.cpp:132-194`).
- Cross-panel commands resolve "the other panel" with `GetNonActivePanel()`
  or a `== LeftPanel ? RightPanel : LeftPanel` ternary: Copy/Move/Delete
  (`src/mainwnd3.cpp:3420-3500`), Create Directory (`:3769`), Pack/Unpack
  (`:3627/:3638`), Compare Directories (`:3912-3960`, `mainwnd5.cpp:1153`,
  `CCompareDirsDialog` with its own `LeftPanel/RightPanel` members), Change
  to other panel's path (`fileswn8.cpp:1516-1546`), Open in other panel
  (`:1437-1513`), Swap (`mainwnd3.cpp:4312-4350` — swaps the two **pointers**
  plus the two toolbar strings, re-stamps `SetLeftPanel`), Zoom
  (`:4520-4552`, `SplitPosition` 0/1), Alt+F1/F2 (`:3172-3203`), the
  disconnect dialog and drive list (`dialogs6.cpp:803-841`,
  `drivelst.cpp:1927-1972` with the `+ 2` allocation and
  `drvtPluginFSInOtherPanel`), free-space refresh with a one-hop recursion
  guard (`fileswn2.cpp:3484-3522`), Cut/Copy ghost mirroring
  (`shellsup.cpp:1850-1895`), drop-end refresh (`:655-706`), the
  `$(FullPathLeft)/$(FullPathRight)/$(FullPathInactive)` user-menu variables
  (`src/execute.cpp:88-90`), `DIRECTORY_COMMAND_LEFT/RIGHT` in every path
  dialog (`src/salamdr3.cpp:3706-3707`), the four per-side idle latches
  `ChangeLeft/RightPanelToFixedWhenIdle*` (`src/salamdr1.cpp:194-197`),
  `UpdateDefaultDir` writing both panel paths into `DefaultDir[26]`
  (`src/mainwnd1.cpp:520-553`).
- Asynchronous machinery keyed by panel *object* or `HWND`, not side (so it
  is indifferent to what the object currently shows): the snooper
  (`WindowArray`/`ObjectArray`, `src/snooper.cpp:12-13`, `AddDirectory`
  `:567-620`; `WaitForMultipleObjects` over the array with **no**
  `MAXIMUM_WAIT_OBJECTS` clamp, 4 reserved slots), the icon reader thread and
  `CIconCache` (one per panel), `FileNamesEnumSources` (by `HWND`),
  `DiskCache` (by lowercased archive name), `DetachedFSList` (global,
  unbounded), `PluginFSTimers` (by FS object), `WM_USER_REFRESH_DIR` (59
  sites, all to a panel `HWND`), `PostChangeOnPathNotification` fan-out
  ("non-active panel first" ordering comment at `mainwnd3.cpp:4607` is a
  real NTFS-timestamp dependency).

### 2.8 Tests

`src/saltests/` links only `src/common/` (`saltests.vcxproj:80-91`, no
project reference). `CFilesWindow`, `CMainWindow`, the snooper, the icon
cache and the plugin encapsulations are not linkable in tests. Panel
behaviour is reachable only through the running application — the GUI
matrix is a human step, as in features 071 and 075.

---

## 3. The central design decision

### 3.1 Two candidate models

**Model A — "tab = remembered view state; one panel object per side"**

Each side keeps its one `CFilesWindow`. The panel gains a `CPanelTabs`
member (ordered list of `CPanelTab` records + active index) and a
`CTabWindow` strip child. A `CPanelTab` holds: location text (as
`GetGeneralPath()` returns it — disk, `archive\inside`, or `fs:path`), view
template index, sort type + reverse flag, filter mask + enabled flag, focused
item name, selected item names, top index / x-offset, and its own
`CPathHistory`. Switching from tab *i* to tab *j*:

1. Refuse if the panel cannot leave its state (locked UI, action in
   progress) — the same guards `ChangePanel`/`ChangeDir` use; cancel quick
   search / quick rename via `CancelUI()` as any path change does.
2. **Snapshot** the panel into tab *i* (all fields above; `PathHistory`
   pointer is swapped, not copied).
3. **Apply** tab *j*: `SelectViewTemplate`, sort, filter; then
   `ChangeDir(location, suggestedTopIndex, suggestedFocusName)` — this runs
   `CloseCurrentPath` (archive close / FS detach with all their existing
   prompts) and lists the new location; a detached FS is re-used by
   `ChangeDir`'s own resolution order; then re-select by names the way
   *Restore Selection* does, restore the top index.
4. Commit: only if step 3 succeeded does the strip mark *j* active; on
   refusal/cancel the panel is still showing *i* (nothing was torn down —
   `ChangeDir` fails before it changes anything when leaving is refused) and
   the strip stays on *i*.

**Model B — "several `CFilesWindow`s per side, one visible"**

Each side owns N panel windows; the invisible ones keep their listings,
watches, threads and FS objects alive; switching shows/hides windows and
repoints `LeftPanel`/`RightPanel`.

### 3.2 Comparison

| Concern | Model A | Model B |
|---|---|---|
| `LeftPanel`/`RightPanel` identity (~770 refs, 17 side ternaries, `GetPanelCode`) | untouched — still exactly two objects | every site must be audited; repointing the pointers on each switch re-creates the `CM_SWAPPANELS` hazards N times |
| Plugin ABI (binary `PANEL_*`, `BOOL leftPanel`, `GetSourcePanel`, FS events) | untouched; plugins see one FS per side as today | a hidden panel holding an open FS is a third "panel" the ABI cannot name; `GetPanelWithPluginFS`/`PostRefreshPanelFS2` cannot address it |
| Detached-FS model (`DetachedFSList`, `drvtPluginFSInOtherPanel`, `+ 2` allocations) | untouched — a background FS tab *is* a detached FS, listed and closable in Alt+F1/F2 as today | breaks the "FS is either in a panel or detached" invariant |
| Snooper capacity (no `MAXIMUM_WAIT_OBJECTS` clamp) | 2 watches as today | 4 + 2N handles; must add a clamp and a policy above ~60 tabs |
| Threads / memory | 2 icon threads as today | 2N threads, 2N icon caches, 2N listings |
| View templates' per-side column slots (`LeftWidth/RightWidth`, `Left/RightSmartMode`) | naturally per side | N panels on one side fight over one slot |
| Swap Panels | free — the tab set is a panel member, so swapping the two pointers swaps the sets | must swap two collections and re-stamp N dir lines |
| Layout, zoom, split, hit test, drive bars, compare, bug report | untouched | all must learn about hidden windows |
| Switch cost | one directory read (like typing the path) | instant (listing kept) |
| Background freshness | re-read on activation (FR-018) | live, but with N watchers |
| Refusal handling (FS refuses to detach, archive update cancelled) | reuses the existing cancel path; no half state | would need a new "cannot hide this window" protocol |
| Persistence | one `Tabs` subkey per side; the legacy per-side values keep describing the active tab | same, plus N live objects to reconcile at load |
| Risk of breaking the program | **low** — the new behaviour is a new *caller* of existing paths | **high** — the new behaviour changes the *meaning* of `LeftPanel` |

### 3.3 Recommendation

**Model A.** It is the only model under which the request's principal goal
("nothing else breaks") is a *property of the design* rather than a promise:
with tabs off, no code runs that did not run before; with tabs on, the only
new thing the rest of the program can observe is a path change it already
knows how to handle. The price — a directory read on each switch and no
live background refresh — is the behaviour users of tabbed file managers
already know, and the spec states it (FR-018, FR-019, FR-026). Caching
listings for instant switching can be layered on later without changing the
model.

The one Chrome expectation Model A does not meet is "background pages stay
loaded"; for a file manager that would mean background directory watches and
open network connections, which is exactly the resource behaviour the spec
rules out.

---

## 4. Integration points for Model A

Each row is a place the feature touches; nothing outside this list needs to
change. Confirm line numbers at implementation time.

### 4.1 Tab model and switching (new code, panel-owned)

| Item | Where | Notes |
|---|---|---|
| `CPanelTab` / `CPanelTabs` | new files (e.g. `src/paneltabs.{h,cpp}`); pure parts (list rules, title derivation from a location string, persistence encode/decode) in `src/common/` so `saltests` can cover them | feature 071 precedent: `src/common/salshell.*` behind an injectable probe |
| Owner | `CFilesWindow` member (+ `CTabWindow* TabStrip`) | swap-panels then works unchanged (`mainwnd3.cpp:4312-4350`) |
| Snapshot sources | `GetGeneralPath()` (`fileswn1.cpp:142`), `GetViewTemplateIndex()`, `SortType`/`ReverseSort`, `Filter.GetMasksString()`/`FilterEnabled`, `FocusedIndex`→name, `GetSelItems`→names, `ListBox->GetTopIndex()/GetXOffset()`, `PathHistory` pointer | all public today |
| Apply | `SelectViewTemplate` (`fileswn2.cpp:1061`), `ChangeSortType` (`:556`), filter setters, **`ChangeDir(text, topIndex, focusName)`** (`fileswn3.cpp:1959`), re-select by names (model: `Reselect`/`OldSelection`, `fileswnd.h:894`), `RefreshListBox` | `ChangeDir` handles disk/archive/FS text uniformly and re-uses detached FS |
| Guards | `CancelUI()` (`fileswn5.cpp:2560`), `FilesActionInProgress`, `LockUI` state, `CanBeFocused()` | mirror `CMainWindow::ChangePanel` (`mainwnd4.cpp:1198-1262`) |
| Title | derive from the location text like `GetFormatedPathForTitle`'s directory mode (`mainwnd1.cpp:1844-1894`); update on every `DirectoryLineSetText` (`fileswn1.cpp:1729-1808`) | one hook in the path-changed path |
| Middle click → new background tab | `CFilesBox` `WM_MBUTTONDOWN/UP` (currently unhandled, `filesbx1.cpp`), hit-test to item, folder or `..` → append tab with the target path, no switch | resolve the folder path the way Ctrl+Shift+Left/Right does (`OpenFocusedInOtherPanel`, `fileswn8.cpp:1437`) but into a tab |

### 4.2 The strip window

| Item | Where |
|---|---|
| Class | resurrect `src/tabwnd.{h,cpp}` (`CTabWindow`), modelled on `CMenuBar` (`src/menubar.cpp`) for items/hot-track/hit-test and `CToolBar` for insert-mark drag reorder |
| Height | `GetNeededHeight()` idiom `2 + EnvFontCharHeight + 2` (+ margins), DPI via `GetScaleForSystemDPI()`; `SetFont()` re-fonted from `CMainWindow::SetEnvFont` (`mainwnd1.cpp:1507`) |
| Paint | cached bitmap; `ThemeSysColor*`/`ThemeDrawEdge`; active tab of the active panel in `HActiveCaptionBrush`/`CurrentColors[ACTIVE_CAPTION_FG]`, inactive panel in the `INACTIVE_*` pair (`stswnd.cpp:894-909`, `1129-1143`); text via the wide path (`DrawTextSeg`/`DrawEllipsis` convention, `stswnd.cpp:718-737`); `OnColorsChanged()` hook (`fileswn0.cpp:3452`) |
| Repaint on activation | same triggers as the Directory Line: `WM_NCACTIVATE` (`mainwnd3.cpp:5577-5594`), `ChangePanel`/`FocusPanel` |
| Layout | panel `WM_SIZE` (`fileswnb.cpp:72-120`): strip at y=0, Directory Line below; main `WM_SIZE` middle-toolbar offset (`mainwnd3.cpp:5526-5540`) adds the strip height; `WM_ERASEBKGND` gap fill (`fileswnb.cpp:122-135`) |
| Create/destroy/toggle | panel `WM_CREATE`/`WM_DESTROY` (`fileswnb.cpp:1024-1117`); toggle helper modelled on `ToggleDirectoryLine` (`fileswn2.cpp:926-966`) driven by the new option |
| Tooltips | `SetCurrentToolTip` + `WM_USER_TTGETTEXT` (`stswnd.cpp:1826-1912`) |
| Hit test / context menu / Shift+F1 | new `mwhteLeftTabStrip`/`mwhteRightTabStrip` in `CMainWindowsHitTestEnum` (`mainwnd.h:337-360`); `HitTest` (`mainwnd1.cpp:2139-2168`); `OnWmContextMenu` (`:2173-2660`) incl. the `export_mnu.py` comment block; `MapClientArea` (`mainwnd4.cpp:1570`) |
| Keyboard focus | none — the strip is not a focus stop; Tab keeps calling `ChangePanel` (`fileswn0.cpp:1300-1304`) |

### 4.3 Commands, menus, shortcuts

| Item | Where |
|---|---|
| IDs | `CM_LEFTNEWTAB/CM_RIGHTNEWTAB/CM_ACTIVENEWTAB` … (per-side + active variants, following the `CM_LEFT*/CM_RIGHT*/CM_ACTIVE*` pattern) in `src/resource.rh2` (free space markers at `:46`, `:452`) |
| Strings | `src/texts.rh2` (next free `14212`) + `src/lang/texts.rc2` |
| Menu | rows in `MainMenuTemplate[]` under *Left* and *Right* (`src/menu4.cpp:21-47`, `:225-251`), skill level to decide; check/enable in `WM_USER_INITMENUPOPUP` (`mainwnd3.cpp:4845+`); hidden/disabled while tabs are off |
| Handlers | `WM_COMMAND` cases in `src/mainwnd3.cpp`; enablers refreshed in `CMainWindow_RefreshCommandStates` (`mainwnd1.cpp:~3007`) |
| Shortcuts | accelerator rows in `src/salamand.rc:61-129` + reservations in `src/keyboard.cpp` `IsSalHotKey`; skip while tabs are off (the accelerator can stay in the table if the handler is a no-op when off — decide in planning; FR-003 requires *no effect*) |
| Toolbar | out of scope (spec Assumptions) |
| Middle click on a tab / drag reorder | inside `CTabWindow` |

### 4.4 Configuration option and dialog

| Item | Where |
|---|---|
| Field | `int PanelTabs;` next to `ShowPanelCaption`/`ShowPanelZoom` (`src/cfgdlg.h:292-299`); default **`TRUE`** (spec FR-002: on by default, decided 2026-09-18) in `CConfiguration::CConfiguration()` (`dialogs4.cpp:269`) — a configuration without the value therefore shows the strip after upgrade |
| Registry | `CONFIG_PANELTABS_REG = "Panel Tabs"` in the table (`mainwnd2.cpp:201+`); save near `CONFIG_SHOWPANELCAPTION_REG` (`:1630`), load near `:3325-3332` — missing value keeps the default, **no version bump** (071 precedent) |
| Dialog | checkbox on `IDD_CFGPAGE_APPEARANCE` (`src/lang/lang.rc:1141-1168`), `CCfgPageAppearance::Transfer` (`dialogs5.cpp:2850`); the "N tabs will be closed" confirmation in the page's validation (`IDOK` path) |
| Post-OK | `WM_USER_CONFIGURATION` after `IDOK` (`mainwnd3.cpp:1949-1990`): create/destroy strips, drop background tabs, relayout — same place the caption/zoom changes are applied |
| Help button | `IDD_CFGPAGE_APPEARANCE` already maps to `configuration_appea.htm` (`help/src/salamand.hhp` `[ALIAS]`) |

### 4.5 Persistence

Proposed layout under the existing per-side keys (all names final in
planning):

```
HKCU\Software\Tandem Commander\0.1\Left Panel
    Path, View Type, Sort Type, Reverse Sort, Enable Filter, Filter, …   ← unchanged, describe the ACTIVE tab
    Active Tab            REG_DWORD  (index; absent → 0)
    Tabs\0\Path           REG_SZ     (location text as GetGeneralPath gives it)
    Tabs\0\View Type      REG_DWORD
    Tabs\0\Sort Type      REG_DWORD
    Tabs\0\Reverse Sort   REG_DWORD
    Tabs\0\Enable Filter  REG_DWORD
    Tabs\0\Filter         REG_SZ
    Tabs\1\…
```

- Writer: `SavePanelConfig` (`mainwnd2.cpp:1193-1218`) gains a loop; the
  `Tabs` key is deleted and rewritten so stale entries never survive.
- Reader: `LoadPanelConfig` (`:2242-2314`) reads the list when `Tabs` exists;
  otherwise one tab from the legacy values (FR-029). The active tab's path is
  applied by the existing start-up code (`:3855-3932`) — unchanged.
- Archive/FS locations for **background** tabs are stored as text and
  resolved lazily on activation through `ChangeDir`; the active tab keeps
  today's disk-only rule (`:3898`).
- Export/Import: automatic (branch dump). `Save In Progress` guard and the
  7-step progress (`:1242`) unaffected.
- Turning the option off: background tabs are dropped from memory and, at
  the next save, from the registry; the legacy values keep describing the
  active tab, so an older build reads the configuration unchanged.

### 4.6 Text, translation, help

- New `IDS_*`/dialog controls break the positional `.slt` import until the
  two-stage refresh runs (`src/vcxproj/build_langs.cmd --export-templates
  --module salamand`, then `python -m translate.merge --module salamand`,
  `python -m translate.slt --verify`, `build.cmd full`); plain `build.cmd`
  (English) in between. Add `tab`/`tabs` to `uicontext._WORDS` if the
  symbol splitter needs it; pin the *Tab* term per language in
  `translations/ui-overrides.json` (cs "karta"/"záložka" is a deliberate
  choice — Chrome-cs uses "karta").
- Help (authored, not shipped — feature 019): new
  `help/src/hh/salamand/windows_tabstrip.htm` in the *Panel Components*
  chapter; updates to `windows_panel.htm`, `configuration_appea.htm`, the
  keyboard shortcuts page; `salamand.hhc`/`.hhk` entries, following commit
  `66f9443` (feature 071).

### 4.7 Release bookkeeping

`CHANGELOG.md` entry under *Added* — it must say that tabs are on by default
and name the option that turns them off; version bump `0.1.7 → 0.1.8` (build
192) in `spl_vers.h`, `tandemcommander.iss`, `CLAUDE.md` in the same change
(constitution, Release Documentation). Interface version stays 106. The
plan's constitution check records the default-on strip as a deliberate,
documented exception to principle II's opt-in rule (spec Clarifications).

---

## 5. Risk register

| # | Risk | Where it bites | Mitigation |
|---|---|---|---|
| R1 | A refused/cancelled leave (plugin `TryCloseOrDetach` cancelled, archive update cancelled) leaves strip and panel disagreeing | switch step 3 | commit the strip only after `ChangeDir` returns success; `ChangeDir` fails before altering the panel when leaving is refused (`PrepareCloseCurrentPath` runs first) — verify in the GUI matrix with FTP and an edited archive (SC-007) |
| R2 | Switch during a file action, quick rename, drag, or while `LockUI`d | `FilesActionInProgress`, `QuickRenameWindow`, `DragBox*`, `LockUI` | same guards as `ChangePanel`; strip clicks ignored while locked |
| R3 | Plugin prompts on every switch away from an FS tab (e.g. "close connection?") | FTP/SFTP `TryCloseOrDetach` | it is the plugin's existing leave behaviour and its own setting; document in the manual; measure annoyance in the matrix — if bad, a later "keep connection" hint is a plugin change, not a core one |
| R4 | Re-selecting by name after re-read is wrong for renamed items | apply step | best effort by name, as *Restore Selection*; spec says "for items that still exist" |
| R5 | Strip height not counted in the Middle Toolbar offset → overlap | `mainwnd3.cpp:5526-5540` | add strip height to `GetNeededHeight` sum; test with Middle Toolbar on |
| R6 | Accelerators fire while tabs are off | `salamand.rc` tables are translated before the panel sees keys | handler is a no-op when `!Configuration.PanelTabs`; `IsSalHotKey` reservation is unconditional (a plugin may not take the key even when tabs are off — acceptable, document) |
| R7 | New `IDS_*` rows break `build.cmd full` for all languages until the `.slt` refresh | translations | follow the 071 task order (plain `build.cmd` until the refresh) |
| R8 | Snooper / device notification confusion when the panel changes path rapidly | `ChangeDirectory` in `snooper.cpp:695` | already handled for any path change; no new code |
| R9 | The `LoadPanelConfig` gate on `Path` (`:2248`) skips tab loading when `Path` is missing | persistence | keep writing `Path` for the active tab; read `Tabs` inside the same gate |
| R10 | Directory Line caption/zoom/hot-path drawing assumes it is the top-most panel child | `stswnd.cpp` | it positions by the rect it is given; verify hot-track and drop target still hit-test correctly with the strip above |
| R11 | Non-ASCII titles drawn through the ANSI path | strip paint | use the wide path unconditionally (titles come from the UTF-8 location); include the feature-004/066 fixtures (SC-009) |
| R12 | `bugreprt.cpp` / crash dump reads panel state during a switch | rare | no new state visible to it; the panel is always in a consistent path state between `ChangeDir` calls |
| R13 | Turning tabs off with many FS tabs silently drops detached connections? | option off | dropping a background tab does not touch its detached FS — the connection stays listed in Alt+F1/F2 as today; document |
| R14 | A tab list restored from a hand-edited/imported configuration with an out-of-range `Active Tab` | load | clamp; empty list → one tab from legacy values |

---

## 6. Open points for planning (not user decisions)

1. Exact shortcut assignment for *Previous Tab* (Ctrl+Shift+PgUp/PgDn vs.
   Alt+Shift+Left/Right vs. a single cycling key) — verify each in
   `keyboard.cpp` and `OnSysKeyDown`.
2. Strip metrics: minimum/maximum tab width, close-glyph size, and the look
   of the tab-list button (overflow is decided: no scrolling, a button that
   opens a list of all tabs — spec Clarifications 2026-09-18, FR-009).
3. Whether tab commands appear in the *Left*/*Right* menus only or also
   under *Commands*. Skill level is decided: all levels (`MNTS_B`), unlike
   the Advanced-only chrome toggles (spec Clarifications, FR-030).
4. Whether the option, when off, keeps the accelerator rows in the table
   (handler no-op) or swaps tables — FR-003 requires *no observable effect*.
5. Where the pure tab-list logic lives so `saltests` can cover add/close/
   reorder/active-index rules and title derivation (FR-007) — `src/common/`
   per the 071 precedent.
6. Behaviour of *Duplicate Tab* history (fresh vs copied) — spec says fresh.
7. Whether restoring a background archive/FS tab lazily should show the
   Directory Line text of the remembered location before first activation
   (the strip title only, or also a "not yet opened" hint).
8. Skill-level and Customize-Toolbar exposure of the commands (out of scope
   for a toolbar button, but the enablers may be prepared).

---

## 7. Verification plan constraints

- **Unit**: only what moves to `src/common/` (tab list rules, title
  derivation, persistence encode/decode) is testable in `saltests`; target
  the same style as feature 071's 52 checks.
- **GUI matrix (human)**: the SC-001/SC-002 side-by-side runs, the
  cancel/refuse cases (SC-007) with FTP (`tandem-sftp` Docker server is
  available for SFTP; FTP needs a server), an edited archive, Swap/Zoom,
  both Drive Bars, restart/export/import (SC-004), 20 tabs per side with a
  file-system monitor (SC-006), non-ASCII fixtures (SC-009), all 8 languages
  (SC-008).
- **Encoding guard**: `tools/check_encoding.py` must stay green (strict
  `TOTAL: 0`); new drawing code goes through the wide path.
- **Build**: `build.cmd` (English) during development; `build.cmd full`
  after the `.slt` refresh; `build.cmd full release` before the ship gate.
