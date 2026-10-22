# Research - 312 tabs browser keys

All sites read at 4a7d5595.

## R1 Key dispatch points

- Panel: `CFilesWindow::OnSysKeyDown` (`src/fileswn0.cpp`) handles the 078 tab keys first
  (`Configuration.PanelTabs && Ctrl && Shift && !Alt`, T / W / PgDn / PgUp, `SkipCharacter` for
  the letters, `PostMessage(WM_COMMAND, CM_ACTIVE_*TAB)`), later Ctrl+PgDn / Ctrl+PgUp
  (`CtrlPageDnOrEnter` / `CtrlPageUpOrBackspace`) and Ctrl / Shift + letter
  (`CMainWindow::HandleCtrlLetter`).
- Command line: `CEditLine::WindowProc` WM_KEYDOWN (`src/editwnd.cpp`) never calls
  `HandleCtrlLetter` (the call is commented out); PgUp / PgDn (any modifiers) are forwarded to the
  active panel's `OnSysKeyDown`; then `Plugins.HandleKeyDown`; then the edit control.
- Ctrl+Tab: accelerator `IDA_MAINACCELS2` (`VK_TAB`, CONTROL -> `CM_EDITLINE`) applied by the main
  message loop before dispatch; not touched.

**Decision**: replace the 078 block in `OnSysKeyDown` by a call to the pure table
(`SalTabKeyDispatch(vk, mods, browserLike)`), keep it at the same place (before quick search's Alt
branch, before paging and letters). In the command line add the same call right after the
`HasLockedUI` / dropped-list checks for the keys of the table except PgUp / PgDn (those keep being
forwarded to the panel, which dispatches them). Dispatched actions post `WM_COMMAND`: tab actions
`CM_ACTIVE_*TAB` / `CM_ACTIVE_REOPENTAB`, Restore Selection `CM_RESELECT`, Go to Shortcut
`CM_AFOCUSSHORTCUT` (the commands the classic keys run, so enablers and checks are the same).
Letter keys set `SkipCharacter` as 078 does.
**Alternatives**: accelerator tables (rejected by the item: mode-dependent, and the panel's own
handler runs first anyway).

## R2 What the table dispatches

In the classic mode the tab code dispatches only the 078 tab keys (Ctrl+Shift+T / W / PgDn / PgUp);
Ctrl+T, Ctrl+W, Ctrl+PgDn / PgUp stay with their existing code; Ctrl+Shift+G is not dispatched
(a plug-in key may hold it). In the browser-like mode it dispatches every key of the table except
Ctrl+Tab. One function answers "dispatch?" from the same rows the list shows (contract).

## R3 Labels and tooltips per mode

Strings naming a mode-dependent key: `IDS_MENU_TAB_NEW`, `_CLOSE`, `_NEXT`, `_PREVIOUS`, the new
`IDS_MENU_TAB_REOPEN`, `IDS_MENU_EDIT_RESELECT`, `IDS_MENU_CMD_FOCUSLNK`, `IDS_TBTT_RESELECT`,
`IDS_TBTT_FOCUSSHORTCUT`, `IDS_TABS_TT_NEW`. All 078 strings keep "Ctrl+Shift+..." in English in
every translation; German writes "Strg+T" / "Strg+W" in the two older strings.

**Decision**: one function `LoadStrTabKeys(resID)` returns `LoadStr(resID)` unchanged in the classic
mode (the 0.1.10 texts, translations included) and, in the browser-like mode, the text with its key
part replaced by the table's key text (`SalTabLabelWithKey`: after a `\t`, or inside a trailing
" (...)", or appended after `\t` when the label has none). Used where the texts are shown:
`WM_USER_INITMENUPOPUP` of `CML_LEFT_TABS` / `CML_RIGHT_TABS` / `CML_EDIT` / `CML_COMMANDS`
(`SetItemInfo` with `MENU_MASK_STRING` by command id), the strip's context menu and its New Tab
tooltip (`tabwnd.cpp`), and the toolbar tooltip texts (`toolbar4.cpp`, two `LoadStr(ToolTipResID)`
sites for tooltips). A label that would not fit the 300-byte work buffer keeps its original text.

## R4 Tabs page placement and the remembered page

`CConfigurationDlg` adds pages in a fixed order; `Configuration.LastFocusedPage` and the
constructor's `mode` constants are indexes of that order. **Decision**: insert the Tabs page as
`/*07*/` right after Appearance; constants for modes 1, 2, 3, 4, 6 (14, 13, 22, 12, 11) move by +1.
At load, when the new value `Browser Tab Shortcuts` is absent (a configuration written before 312),
`LastFocusedPage >= 7` is moved by +1 (`SalCfgPageIndexFrom311`, saltests). The value is always
written on save, so the mapping runs once. **Alternative**: appending the page at the end of the
tree (rejected: it would land after the Packers branch, far from Appearance).

## R5 Ctrl+Shift+G and existing plug-in hot keys

`IsSalHotKey` is used by Plugins Manager (refuses), the settings import (skips) and
`CPluginData::HotKeysEnsureIntegrity` (clears a plug-in key at load). **Decision**: add
`case 'G': CONTROL_SHIFT` to `IsSalHotKey`; in `HotKeysEnsureIntegrity` keep a Ctrl+Shift+G key
(`IsSalHotKeyKeptAtLoad`) so a user's existing assignment survives; in the browser-like mode the
core dispatch runs before `Plugins.HandleKeyDown` in both handlers, so the tab key wins there.

## R6 Closed tabs

`CPanelTab` is non-copyable and owns its `CPathHistory`. **Decision**: `CPanelTabs` gets
`Closed` (TIndirectArray, newest last) and each closed `CPanelTab` remembers `ClosedIndex`.
`CloseTab`, `CloseOtherTabs`, `CloseTabsToRight` use `RemoveToClosed(index)` (detach + push; the
oldest beyond 10 deleted). `ReopenClosedTab()` pops the newest, inserts it at
`SalTabsReopenIndex(count, closedIndex)` and `SwitchToTab`s to it; a refused switch detaches it
again and pushes it back. `SetTabsEnabled(FALSE)` empties `Closed`. Every walk over the tabs'
histories also walks `Closed`: `ClearHistory` (fileswn1.cpp) and `ClearPluginFSFromHistory`
(fileswn9.cpp) - the latter is a must: a history entry keeps a plug-in FS interface pointer.
The list lives in the panel object, so Ctrl+U (which swaps panel objects) carries it with the tabs.
Nothing of it is saved (`mainwnd2.cpp` saves `Tabs` only).

## R7 Turning tabs on / off from the menus

**Decision**: new `CM_TOGGLEPANELTABS` (2884) handled by `CMainWindow::TogglePanelTabs()`: when
turning off with background tabs, the 078 question (`IDS_TABS_CLOSECONFIRM`) first; then the same
apply as `RefreshAfterConfiguration` (`SetTabsEnabled` on both panels, `LayoutWindows`). The
question is a shared helper (`CMainWindow::ConfirmTabsOff(HWND)`) used by the Tabs page too.
Options > Show gets the item after *Command Line*, before *Bottom Toolbar* (checked in
`CML_OPTIONS_VISIBLE`); the toolbar context menu (main-window part, `OnWmContextMenu`) gets it at
the same place, item id 14.

## R8 Strings (free slots, rule 084)

Bundle 14176-14191 has free 14176-14179, 14190, 14191; bundle 14192-14207 has 14192-14194.
New: `IDS_MENU_TAB_REOPEN` "Reopen C&losed Tab", `IDS_MENU_OPT_VSB_TABS` "T&abs",
`IDS_TABKEY_ENTER` "Go into the focused folder or archive", `IDS_TABKEY_PARENT` "Go to the parent
folder", `IDS_TABKEY_CMDLINE` "Go to the command line", `IDS_TABKEY_NONE` "(none)". Reused:
`IDS_PLUGIN_KEY` "Shortcut Key", `IDS_PLUGIN_COMMAND` "Command" (list headers), the menu labels
(action names: text before `\t`, `&` removed). Dialog texts (`IDD_CFGPAGE_TABS`): caption "Tabs",
"Show ta&bs in panels", "&Browser-like tab shortcuts (Ctrl+T, Ctrl+W, Ctrl+Page Up/Down)",
"Tab shortcuts:". The toolbar context menu reuses `IDS_MENU_OPT_VSB_TABS`.
Translations need the two-stage `.slt` refresh (not done by an autonomous run).
