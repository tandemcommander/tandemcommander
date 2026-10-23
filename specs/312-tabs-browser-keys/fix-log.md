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
- Full build: `.\build.cmd full` -> `BUILD FAILED (exit code: 1)`: "8 pair(s) failed: czech/salamand
  ... spanish/salamand: import failed" (translator.exe killed after 30 s per language - the `.slt`
  files no longer match the module structure: 6 new strings, the new dialog `IDD_CFGPAGE_TABS`,
  the Appearance dialog without `IDC_PANELTABS`). Expected (rule 084): the two-stage `.slt`
  refresh (`translate.merge`, `--templates`) is owed - an autonomous run does not do it (it
  spends DeepL characters; stop-rules §3 #2). No translator process left behind; the tree
  unchanged by the full build.
- Not driven by the probe (owed to a person): the real keyboard in both modes (panel and command
  line); the menu labels as drawn (custom menus cannot be read from outside - covered by the
  label rule in saltests and by reading the code); the toolbar tooltips; the Tabs page in eight
  languages.

## Review

Review 1 (independent agent, refute-first): **no MUST**. It re-ran saltests (27343 / 0) and the
probe (33 PASS, registry identical) and checked the classic mode against the 0.1.10 code, the
accelerator tables, the plug-in key order, closed-tab lifetime, index bookkeeping (also the refusal
and out-of-memory paths), the page mapping and the standing rules.

- SHOULD 1 - Clear History left closed tabs reopenable (folder, focused and selected names).
  Fixed: `CFilesWindow::ClearHistory` empties `Tabs.Closed` (fileswn1.cpp); manual
  (`configuration_tabs.htm`, `windows_tabstrip.htm`, `configuration_history.htm`), changelog and
  data-model say so. Not driven by the probe: Clear History also clears plug-in histories, which a
  probe should not touch on the maintainer's machine; the change is one call.
- SHOULD 2 - the replace script wrote a UTF-8 BOM into `help/src/salamand.hhc`, `.hhk`, `.hhp`
  (none on main; HTML Help Workshop reads them as ANSI). Fixed: the three BOMs removed; every
  other changed file keeps the first bytes it has on main (checked file by file).
- NOTE - `TogglePanelTabs` had no guard against a running tab switch / locked UI. Fixed: it
  refuses then (paneltabs.cpp).
- NOTE (kept, recorded) - `IsSalHotKeyKeptAtLoad` also keeps a third-party plug-in's own default
  Ctrl+Shift+G (none of the shipped plug-ins has one); in the browser-like mode the program's key
  wins and the plug-in menu still shows Ctrl+Shift+G - the changelog limitation says so.
- NOTE (kept) - a configuration saved by 312 and then again by 0.1.10 keeps "Browser Tab Shortcuts"
  with a 0.1.10 page index: the page opens one step too low once (downgrade only).
- NOTE (kept) - SC-003 (selection, cursor, filter, view, history restored) holds by construction
  (the same `CPanelTab` object comes back); the probe measures location, order and sort only.

After the fixes: `.\build.cmd` BUILD SUCCEEDED; saltests 27343 checks, 0 failed; encoding guard
TOTAL: 0; probe 33 PASS / 0 FAIL / 0 NOT DRIVEN, registry identical (`probe/result_after.txt`).
No second review: review 1 had no MUST finding (SKILL.md step 7).

## Stopped (autonomous run, 2026-10-22)

Everything the item asks is implemented and verified on this branch except the translations: the
feature adds UI strings and changes two dialogs, so the two-stage `.slt` refresh (rule 084,
`translate.merge --templates`, DeepL) is required, and an autonomous run does not do it
(stop-rules §3 #2). Measured: `.\build.cmd full` fails for all eight languages (salamand module
import) until it runs. The run stops before closing the item.

What the maintainer does to finish (in this order):
1. On this branch: the two-stage `.slt` refresh for the salamand module (6 new strings 14176-14179,
   14190, 14191; dialog `IDD_CFGPAGE_TABS`; `IDD_CFGPAGE_APPEARANCE` without `IDC_PANELTABS`),
   `--templates` as in rule 084; pin texts in `translations/ui-overrides.json` if DeepL drifts
   (de/fr/nl/es register); `.\build.cmd full` -> BUILD SUCCEEDED.
2. Close the item as SKILL.md step 8 does: `BL remove panel-tabs-chrome-shortcuts-and-reopen-closed-tab --feature 312`,
   the FEATURE-HISTORY entry below (index row "User-facing features": add 312), closing report;
   the CHANGELOG entry is already under 0.1.11 — unreleased.
3. The person step `tabs-312-real-keyboard-and-eight-languages` (real keys in both modes, panel and
   command line; the Tabs page and the menus in eight languages).
4. `git merge --ff-only 312-tabs-browser-keys` (or a merge) into main.

Draft FEATURE-HISTORY entry:

- 312-tabs-browser-keys: panel tabs had only Chrome's keys with Shift added, a closed tab was lost
  and the tab settings were one Appearance checkbox - now Configuration > Tabs (after Appearance)
  holds *Show tabs in panels*, an opt-in *Browser-like tab shortcuts* (Ctrl+T / Ctrl+W /
  Ctrl+PgDn / PgUp for tabs, Ctrl+Shift+T Reopen, Ctrl+Shift+W Restore Selection, Ctrl+Shift+G Go
  to Shortcut; panel and command line; classic keys unchanged by default) and a list that follows
  the option; Reopen Closed Tab (10 per panel, memory only, the `CPanelTab` object itself with its
  history, emptied by tabs off and Clear History); Tabs in Options > Show and the toolbar menu.
  One pure key table in `saltabs.*` drives dispatch, labels (`LoadStrTabKeys`) and the page. Traps:
  the command line never ran the Ctrl+letter handler (classic Ctrl+T/W do nothing there - kept);
  `IsSalHotKey` also clears plug-in keys at load (`IsSalHotKeyKeptAtLoad` keeps Ctrl+Shift+G);
  closed tabs' histories hold plug-in FS pointers (`ClearPluginFSFromHistory` walks them); the
  page order is the remembered page index (`SalCfgPageIndexFrom311` when the new value is absent).
  From backlog item `panel-tabs-chrome-shortcuts-and-reopen-closed-tab`. Probe `tabs312_probe`
  33 PASS (new feature, classic rows as control); saltests +106; review 1 no MUST, 2 SHOULD fixed.

## Finished (maintainer session, 2026-10-23)

The maintainer asked for the blocked item to be finished and closed; the rules were changed the
same day so that a run does the `.slt` refresh itself (stop-rules §2.13). Done in this order:

- **Merged `main`** (313-320, 314 and the backlog closures) into the branch: `[312] merge main`.
  Conflicts only in the backlog files (taken from `main`), `.specify/feature.json` (the branch's)
  and `CHANGELOG.md` (both entries kept, `main`'s first). `main` (313) and 312 both changed
  `src/fileswn0.cpp` (313 the quick-search keys at ~2110-2236, 312 the tab keys at ~1711-1726) and
  `src/saltests/saltests.cpp`; git merged them without conflicts.
- **Review of the merge** (refute-first agent, read-only): no MUST, no SHOULD. The tab-key block
  runs before quick search; every route that changes the listing (`SwitchToTab`, close, reopen)
  ends the search first (`QFEndAtPathChange`), `NewTab` only reads (`CaptureActiveTab`,
  `QFWriteBackNow`); `saltests.cpp`: 140 registrations = 135 + 1 (312) + 4 (main), none twice.
  NOTEs only (one tab in the browser-like mode swallows Ctrl+W / Ctrl+PgUp/PgDn - the spec's
  limitation; a refused switch has already ended the search - since 078/244).
- **Translations** (stop-rules §2.13): entries = 6 new strings (14176-14179, 14190, 14191) and the
  new dialog `IDD_CFGPAGE_TABS` (caption, `IDC_PANELTABS` moved from Appearance,
  `IDC_TABS_BROWSERKEYS`, `IDT_TABS_KEYLIST`); no English changed. `.\build.cmd` -> BUILD
  SUCCEEDED; export 1/1; dry run `--formality prefer_more`: **10 unique gaps per language**, ~234
  characters; real merge `--budget 5744`: 1,832 DeepL characters, validation failures 0;
  duplicate accelerators 147 = the module's old baseline (148 at feature 123; string tables
  counted as one group), none in dialog 6286. Read back in all eight languages; 24 pins
  (`salamand`, `_feature_312` note):
  - meaning - panel tabs are not the Tab key: de "T&abulator-Tasten" / "Tabulator-Ta&stenkombinationen:",
    fr "Touches de t&abulation", hu "T&abulátorok", sk "Klávesy T&ab";
  - established terms: cs "karty" (078; the page said "Záložky"), hu "lap" (078; the page said
    "Fülek" / "Fülparancsok"), cs / sk "adresář / adresár" as the rest of the corpus;
  - accelerators: the core's menus are built from strings (menu4.cpp), which the merge cannot
    check - checked by script for the Tabs submenu (IDS_MENU_TAB_*) and Options > Show
    (IDS_MENU_OPT_VSB_*): cs / sk Reopen collided with Close Others / Close, cs / sk / hu Tabs with
    Text labels / Lock toolbars / Plugin bar, hu Reopen was moved onto Close's letter by the
    merge's string-table dedupe -> 0 collisions after the pins;
  - one register per list: de "Wechseln Sie ..." and ro "Intrați ..." next to infinitive / noun forms.
  Key names were left as translated (de "Strg+Bild auf/ab", fr / es local names): the German and
  French corpora name keys that way. Second merge: 0 gaps, 0 characters; `translate.slt
  --verify`: 298 files round-trip byte-exact; per language 23 + / 11 - lines (the new rows and the
  Appearance page moving up), no unrelated layout drift.
- **Checks**: `.\build.cmd full` -> BUILD SUCCEEDED (the eight core language modules rebuilt);
  `saltests: 27664 checks, 0 failed`; `check_encoding.py --strict` TOTAL 0; probe after the merge
  `probe/result_after_merge.txt` **PASS 33, FAIL 0, NOT DRIVEN 0**, registry restored identical.
- Owed to a person: `tabs-312-real-keyboard-and-eight-languages` (unchanged).
