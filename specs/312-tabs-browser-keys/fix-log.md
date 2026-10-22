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
