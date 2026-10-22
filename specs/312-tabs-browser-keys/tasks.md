# Tasks: Panel tabs - a Tabs settings page, opt-in browser-like shortcuts, Reopen Closed Tab

**Input**: `specs/312-tabs-browser-keys/` (plan.md, spec.md, research.md, data-model.md, contracts/tab-keys.md, quickstart.md)
**Tests**: saltests for the pure rules (FR-017) and the hidden-desktop probe (quickstart.md) are requested by the spec.

## Phase 1: Setup

- [X] T001 Start `specs/312-tabs-browser-keys/fix-log.md` with the measurement at 4a7d5595 (research R1-R8 findings, the command-line finding that Ctrl+T/W/Shift+T/W do nothing there)

## Phase 2: Foundational (blocks all stories)

- [X] T002 Add the pure rules to `src/common/saltabs.h` / `src/common/saltabs.cpp`: `CSalTabKeyAction`, `SAL_TABKEY_CTRL/SHIFT`, the row table, `SalTabKeysBrowserLike`, `SalTabKeyDispatch`, `SalTabKeyMeaning`, `SalTabKeyRows`, `SalTabKeyForAction`, `SalTabKeyText`, `SalTabLabelWithKey`, `SAL_TABS_CLOSED_MAX`, `SalTabsReopenIndex`, `SalCfgPageIndexFrom311` (contract tab-keys.md)
- [X] T003 Add `TestTabKeys312` to `src/saltests/saltests.cpp` (every row in both modes, dispatch set, Alt refusal, key texts, label replacement in the three shapes + empty key + too long, reopen index clamping, page mapping) and call it from `main`
- [X] T004 Add `Configuration.PanelTabsBrowserKeys` (default 0) in `src/cfgdlg.h` / `src/dialogs4.cpp` constructor; save / load `Browser Tab Shortcuts` in `src/mainwnd2.cpp` next to `Panel Tabs`; when absent at load map `Configuration.LastFocusedPage` with `SalCfgPageIndexFrom311`
- [X] T005 Add command ids `CM_ACTIVE_REOPENTAB` 2881, `CM_LEFT_REOPENTAB` 2882, `CM_RIGHT_REOPENTAB` 2883, `CM_TOGGLEPANELTABS` 2884 in `src/resource.rh2`; string ids in `src/texts.rh2` (free slots 14176-14179, 14190, 14191) and texts in `src/lang/texts.rc2`

## Phase 3: User Story 1 + 2 - classic stays, browser-like keys (P1)

**Goal**: one table drives the keys; classic unchanged; browser-like keys in the panel and the command line.
**Independent test**: probe rows classic-keys, browser-keys, browser-cmdline, tabs-off.

- [X] T006 [US2] Replace the 078 block in `CFilesWindow::OnSysKeyDown` (`src/fileswn0.cpp`) by `SalTabKeyDispatch` posting the command of the action (tab commands, `CM_RESELECT`, `CM_AFOCUSSHORTCUT`), `SkipCharacter` for letters; tab actions end a quick search through `SwitchToTab` as in 078
- [X] T007 [US2] Dispatch the table in the command line `src/editwnd.cpp` WM_KEYDOWN (letters; PgUp / PgDn keep being forwarded to the panel), before `Plugins.HandleKeyDown`
- [X] T008 [US2] Reserve Ctrl+Shift+G in `IsSalHotKey` (`src/keyboard.cpp`) and add `IsSalHotKeyKeptAtLoad`; keep such a key in `CPluginData::HotKeysEnsureIntegrity` (`src/plugins1.cpp`); declare in `src/salamand.h`
- [X] T009 [US2] `LoadStrTabKeys(resID)` in `src/paneltabs.cpp` (declared in `src/paneltabs.h`): mode labels by the table; use it in `WM_USER_INITMENUPOPUP` (`src/mainwnd3.cpp`) for `CML_LEFT_TABS` / `CML_RIGHT_TABS` / `CML_EDIT` / `CML_COMMANDS`, in the strip context menu and New Tab tooltip (`src/tabwnd.cpp`) and in the toolbar tooltips (`src/toolbar4.cpp`)
- [X] T010 [US1] Show *Go to Shortcut or Link Target* at every skill level (`src/menu4.cpp`)

## Phase 4: User Story 3 - Reopen Closed Tab (P1)

**Goal**: closed tabs come back with their state. **Independent test**: probe rows reopen-*; saltests.

- [X] T011 [US3] `CPanelTabs::Closed`, `CPanelTab::ClosedIndex`, `RemoveToClosed`, `ClearClosed` in `src/paneltabs.h` / `src/paneltabs.cpp`; Close Tab (also the strip's middle click and close button) / Close Other Tabs / Close Tabs to the Right push; `SetTabsEnabled(FALSE)` clears
- [X] T012 [US3] `CFilesWindow::ReopenClosedTab()` (`src/paneltabs.cpp`, declared in `src/fileswnd.h`): insert at `SalTabsReopenIndex`, switch, put back on refusal
- [X] T013 [US3] Commands: `HandleTabCommand` range + op 7 (`src/paneltabs.cpp`), `WM_COMMAND` cases (`src/mainwnd3.cpp`), menu templates (`src/menu4.cpp`: both Tabs submenus in the main templates and the standalone ones), enable state in `WM_USER_INITMENUPOPUP`, the strip context menu item (`src/tabwnd.cpp`)
- [X] T014 [US3] Closed tabs' histories in `CFilesWindow::ClearHistory` (`src/fileswn1.cpp`) and `ClearPluginFSFromHistory` (`src/fileswn9.cpp`)

## Phase 5: User Story 4 - Tabs page and toggles (P2)

**Goal**: the Tabs page, Appearance without the checkbox, Tabs toggles. **Independent test**: probe rows page-*, toggle-menus.

- [X] T015 [US4] Dialog `IDD_CFGPAGE_TABS` (DIALOGEX, `DS_SETFONT | DS_FIXEDSYS`, `FONT 8, "MS Shell Dlg"`, constitution VI) and control ids in `src/lang/lang.rc` / `src/lang/lang.rh` (+ DESIGNINFO); remove `IDC_PANELTABS` from `IDD_CFGPAGE_APPEARANCE` and move its groups up 12 DLUs
- [X] T016 [US4] `CCfgPageTabs` (`src/cfgdlg.h`, `src/dialogs5.cpp`): Transfer, Validate (the tabs-off question via `CMainWindow::ConfirmTabsOff`), list view filled from `SalTabKeyRows`, refresh on checkbox clicks, enable rules; remove the checkbox code from `CCfgPageAppearance`
- [X] T017 [US4] Insert the page as `/*07*/` in `CConfigurationDlg` (`src/dialogs4.cpp`), shift the `mode` constants and the index comments
- [X] T018 [US4] `CM_TOGGLEPANELTABS`: `CMainWindow::TogglePanelTabs` + `ConfirmTabsOff` (`src/paneltabs.cpp`, `src/mainwnd.h`), Options > Show item after *Command Line* + check mark (`src/menu4.cpp`, `src/mainwnd3.cpp`), toolbar context menu item (`src/mainwnd1.cpp`)

## Phase 6: Polish & cross-cutting

- [ ] T019 [P] Manual: new `help/src/hh/salamand/configuration_tabs.htm`; `help/src/salamand.hhp` / `.hhc` / `.hhk`; `shortcuts_keyboard.htm`, `windows_tabstrip.htm`, `configuration_appea.htm`
- [ ] T020 Build (`build.cmd`), saltests, encoding guard; record in fix-log
- [ ] T021 Probe `specs/312-tabs-browser-keys/probe/tabs312_probe.ps1` (quickstart rows): run before (main build) where meaningful and after; record
- [ ] T022 `CHANGELOG.md` entry under the unreleased section (step 8 of the run)

## Dependencies

T002 -> T003, T006-T009, T011-T012, T016. T004/T005 -> T006-T018. US3 (T011-T014) independent of US4. T020-T021 after all code.

## Parallel examples

T019 (help) with any code task; T010 with T006-T009.

## Implementation strategy

Foundation (pure table + tests), then keys (US1/US2), Reopen (US3), page (US4), then manual, build, probe.
