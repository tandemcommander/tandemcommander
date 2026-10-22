# Fix log - 312-tabs-browser-keys

Backlog item `panel-tabs-chrome-shortcuts-and-reopen-closed-tab` (feature request; maintainer
decisions of 2026-10-22 in the item). Autonomous run (`/tandem-backlog-implement`).

## Measurement at 4a7d5595 (before any change)

By reading the sites at HEAD (the item's Evidence lines still hold within a few lines):

- No browser-like option, no Reopen Closed Tab command, no Tabs page; *Show tabs in panels* is a
  checkbox of the Appearance page (`IDC_PANELTABS`, lang.rc).
- Panel (`CFilesWindow::OnSysKeyDown`, fileswn0.cpp): the 078 tab keys (Ctrl+Shift+T / W / PgDn /
  PgUp, guarded by `Configuration.PanelTabs`) are handled first; Ctrl+PgDn / Ctrl+PgUp go to
  `CtrlPageDnOrEnter` / `CtrlPageUpOrBackspace`; Ctrl+letter to `CMainWindow::HandleCtrlLetter`
  (Ctrl+T -> `CM_AFOCUSSHORTCUT`, Ctrl+W -> `CM_RESELECT`).
- Command line (`CEditLine::WindowProc` WM_KEYDOWN, editwnd.cpp): the `HandleCtrlLetter` call is
  commented out, so **Ctrl+T, Ctrl+W, Ctrl+Shift+T and Ctrl+Shift+W do nothing there today**
  (078's quickstart 8.4 "do what they did" = nothing). PgUp / PgDn with any modifier are forwarded
  to the panel's `OnSysKeyDown` (so Ctrl+Shift+PgDn / PgUp switch tabs and Ctrl+PgDn / PgUp enter /
  go up from the command line).
- Ctrl+Tab: accelerator `IDA_MAINACCELS2` (`VK_TAB` + CONTROL -> `CM_EDITLINE`), applied by the main
  loop before dispatch.
- Ctrl+Shift+G: no handler in the panel (the Ctrl/Shift+letter branch excludes Ctrl+Shift), none in
  `HandleCtrlLetter`, none in the command line, not reserved by `IsSalHotKey`. `IsSalHotKey` is
  also used by `CPluginData::HotKeysEnsureIntegrity`, which **clears** a plug-in hot key that it
  reports - reserving Ctrl+Shift+G there naively would drop a user's existing plug-in key at load.
- Key texts in the 078 menu strings stay English ("Ctrl+Shift+T") in all eight translations;
  German writes "Strg+T" / "Strg+W" in the two older strings (Restore Selection, Go to Shortcut).
- Closed tabs would keep their `CPathHistory`: `ClearHistory` (fileswn1.cpp) and
  `ClearPluginFSFromHistory` (fileswn9.cpp) walk only the open tabs - a closed tab's history must
  be walked too (a history entry keeps a plug-in FS interface pointer).

## Decisions

See spec.md *Clarifications* (autonomous run) and research.md R1-R8.

## Analyze

speckit-analyze: 0 CRITICAL, 0 HIGH; MEDIUM G1 accepted - FR-016 "all texts translated" needs the
two-stage `.slt` refresh, which an autonomous run does not do (stop-rules §3 #2): the run stops at
verification with the work on the branch. LOW I1, C1, U1, U2 fixed in research.md / tasks.md.

## Work

- Pure rules (`src/common/saltabs.h/.cpp`, the 078 module, already in `saltests`): the key table
  (10 rows, classic / browser-like action), `SalTabKeyDispatch` (classic: only the 078 tab keys;
  browser-like: every row but Ctrl+Tab; Alt never), `SalTabKeyRows` (+ the classic "no key ->
  Reopen Closed Tab" row), `SalTabKeyForAction`, `SalTabKeyText` (English 078 form),
  `SalTabLabelWithKey` (`\t` / " (...)" / append; refuses instead of cutting),
  `SAL_TABS_CLOSED_MAX` = 10, `SalTabsReopenIndex`, `SalCfgPageIndexFrom311`.
- Keys: the panel's 078 block now asks the table (`TabKeyCommand`, paneltabs.cpp); the command
  line dispatches the letter keys only in the browser-like mode (in the classic mode nothing
  changes there - Ctrl+T/W/Shift+T/Shift+W did nothing), PgUp / PgDn keep being forwarded to the
  panel. Restore Selection / Go to Shortcut run `CM_RESELECT` / `CM_AFOCUSSHORTCUT`, the commands of
  the classic keys.
- `IsSalHotKey` reserves Ctrl+Shift+G; `IsSalHotKeyKeptAtLoad` keeps a plug-in key on it in
  `HotKeysEnsureIntegrity` (Plugins Manager and the settings import still refuse it).
- Reopen Closed Tab: `CPanelTabs::Closed` (the `CPanelTab` objects themselves, detached, with
  `ClosedIndex`), `RemoveToClosed` in Close Tab (also middle click / close button, which call
  `CloseTab`), Close Other Tabs, Close Tabs to the Right; `ReopenClosedTab` inserts at
  `SalTabsReopenIndex` and switches; a refused switch puts it back with its old index; out of
  memory: back to the list. `SetTabsEnabled(FALSE)` empties the list. `ClearHistory` and
  `ClearPluginFSFromHistory` walk the closed tabs too. Commands `CM_*_REOPENTAB` 2881-2883 (op 7 of
  `HandleTabCommand`), in both Tabs submenus (main template + standalone) and the strip menu.
- Labels: `LoadStrTabKeys` (classic: the loaded string unchanged; browser-like: the table's key)
  at `WM_USER_INITMENUPOPUP` of the Tabs submenus, Edit (Restore Selection), Commands (Go to
  Shortcut, now at every skill level), the strip menu and New Tab tooltip, toolbar tooltips.
- Configuration: `PanelTabsBrowserKeys` (`Configuration\Browser Tab Shortcuts`, default 0); its
  absence at load maps `Last Focused Page` (>= 7 -> +1). Tabs page `IDD_CFGPAGE_TABS` /
  `CCfgPageTabs` inserted as page 07; `mode` constants 14/13/22/12/11 -> 15/14/23/13/12. Appearance
  lost the checkbox (groups up 12 DLUs) and its tabs-off question (now `ConfirmTabsOff`, shared).
- Tabs toggle `CM_TOGGLEPANELTABS` (2884): Options > Show (after Command Line, checked) and the
  toolbar context menu (item 13), with the 078 question.
- Strings (free slots of the bundle 14176-14191): `IDS_MENU_TAB_REOPEN`, `IDS_MENU_OPT_VSB_TABS`,
  `IDS_TABKEY_ENTER`, `_PARENT`, `_CMDLINE`, `_NONE`; dialog `IDD_CFGPAGE_TABS` (4 texts); the
  Appearance dialog lost one control. Reused: `IDS_PLUGIN_KEY`, `IDS_PLUGIN_COMMAND`, menu labels.
- Manual: new `configuration_tabs.htm` (hhp alias, hhc, hhk); `shortcuts_keyboard.htm`,
  `windows_tabstrip.htm` (+ Reopen Closed Tab section), `configuration_appea.htm`,
  `windows_panel.htm`.

## Checks

- Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Build: `.\build.cmd` -> `BUILD SUCCEEDED` (one compile error on the way: `CMenuPopup` undefined
  in paneltabs.cpp - `menu.h` included).
- saltests: `saltests: 27343 checks, 0 failed` (TestTabKeys312: 106 new checks; 27237 before).
  Negative control: `SalCfgPageIndexFrom311` returning the index unchanged -> `3 failed`
  (lines 2269-2271); restored, rebuilt, 0 failed.
- Probe `probe/tabs312_probe.ps1` on the hidden desktop (Debug build): **33 PASS, 0 FAIL, 0 NOT
  DRIVEN**, registry restored identical (`probe/result_after.txt`). The CLASSIC rows are the
  negative control of the BROWSER rows: the same keys with the option off keep the 0.1.10 meaning
  (Ctrl+PgDn enters A, Ctrl+T/W/Shift+G open no tab, the command line keys do nothing). A first run
  had 2 FAIL rows that were probe expectations, not the product: REOPEN-EMPTY was asked after
  earlier closes had legitimately filled the list (the 4th reopen brought back the tab closed by
  Ctrl+W, at index 1 - now row REOPEN-OLDER, and REOPEN-EMPTY runs before anything is closed);
  TABS-OFF pressed Backspace from R (the reopened tab) and so focused the wrong folder. No "before"
  run: a new feature - on a build without 312 the BROWSER rows fail by construction (the value is
  ignored), the CLASSIC rows are the 0.1.10 behaviour.
- Not driven by the probe (owed to a person): the real keyboard in both modes (panel and command
  line); the menu labels as drawn (custom menus cannot be read from outside - covered by the
  label rule in saltests and by reading the code); the toolbar tooltips; the Tabs page in eight
  languages.
