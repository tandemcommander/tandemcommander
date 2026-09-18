# Tasks: Panel Tabs

**Input**: Design documents from `/specs/078-panel-tabs/`
**Prerequisites**: plan.md, spec.md (5 user stories), research.md (R1–R22), data-model.md, contracts/ (3), quickstart.md (14 sections), analysis.md

**Tests**: Included for the pure common module only — plan decision R13 makes `saltests` coverage of `src/common/saltabs.*` part of the design (title derivation, index rules, record clamping). Everything in the main application (strip, switching, plugins, persistence, keyboard, mouse) is verified through the manual matrix in quickstart.md; those verification steps are explicit tasks so a ticked box means "checked", not "written" (lesson recorded in feature 070).

**Organization**: Phases 3–7 map 1:1 to spec user stories US1–US5 (P1, P1, P2, P2, P3). Each phase ends with a verification task against quickstart.md and an entry in `fix-log.md` (the running record this project keeps in the specs directory).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelizable (different files, no dependency on an incomplete task)
- **[Story]**: US1–US5 per spec.md
- Paths are repository-relative

## Path Conventions

- Core application: `src/*.cpp`, `src/*.h`; shared library: `src/common/`; language resources: `src/lang/` (+ `src/texts.rh2`, `src/resource.rh2`); tests: `src/saltests/saltests.cpp`; projects: `src/vcxproj/`
- Translations: `translations/<lang>/salamand.slt`, tooling under `tools/translate/`
- Manual: `help/src/` (HTML Help project + `hh/salamand/*.htm`)

---

## Phase 1: Setup

**Purpose**: bookkeeping, file scaffolding and resource ids so every later task lands in a registered file

- [x] T001 Create the running log `specs/078-panel-tabs/fix-log.md` (sections: Status checklist per task, Decisions taken while implementing, Verification results, Deviations from the plan) and keep it updated by every task below
- [x] T002 [P] Create empty `src/common/saltabs.h` and `src/common/saltabs.cpp` (UTF-8 BOM, licence header as `src/common/salshell.cpp`) and register `common\saltabs.cpp` as `<ClCompile>` in `src/vcxproj/salamand.vcxproj` (next to `common\salshell.cpp`, line ~272) and in `src/vcxproj/saltests/saltests.vcxproj` (next to `..\..\common\salshell.cpp`, line ~86); confirm `build.cmd` still links
- [x] T003 [P] Create empty `src/paneltabs.h` and `src/paneltabs.cpp` (UTF-8 BOM, `#include "precomp.h"`) and register `paneltabs.cpp` as `<ClCompile>` and `paneltabs.h` as `<ClInclude>` in `src/vcxproj/salamand.vcxproj`
- [x] T004 [P] Rewrite `src/tabwnd.h` and `src/tabwnd.cpp` into a compilable skeleton: keep the SPDX header, `class CTabWindow : public CWindow` with `CFilesWindow* FilesWindow`, a constructor `CTabWindow(CFilesWindow*)` (`ooStatic`), `int GetNeededHeight()`, `LRESULT WindowProc(...)`, remove the undefined `DestroyWindow()` declaration and the commented-out block; add `#include "tabwnd.h"` where `CFilesWindow` is defined (`src/fileswnd.h` forward declaration + include in `src/fileswnb.cpp`/`src/fileswn2.cpp` as the Directory Line does with `stswnd.h`)
- [x] T005 [P] Add `tab tabs strip close closeothers closeright next previous other others` to `_WORDS` in `tools/translate/uicontext.py` (line ~124 blob, keep longest-first order) so the new `IDS_MENU_TAB_*` / `IDS_TABS_*` / `IDC_PANELTABS` symbols split into readable context words (research R20)
- [x] T006 [P] Add ids in `src/resource.rh2`: the 21 commands in the free block at the `// FREESPACE` marker (line ~452) exactly per contracts/commands-and-shortcuts.md §1 (`CM_ACTIVE_NEWTAB 2860` … `CM_RIGHT_CLOSETABSRIGHT 2880`, order active/left/right), `CML_LEFT_TABS 5956`, `CML_RIGHT_TABS 5957` (below `CML_LAST 5999`), `IDC_TABSTRIP 953` (next to `IDC_DIRECTORYLINE 952`, line ~320 — verify 953 is unused), `IDH_TABSTRIP` in the free range at line ~46 (e.g. 143); add `IDC_PANELTABS 6235` to `src/lang/lang.rh` and bump `_APS_NEXT_CONTROL_VALUE` to 6236; add `IDS_MENU_LEFT_TABS`, `IDS_MENU_RIGHT_TABS`, `IDS_MENU_TAB_NEW`, `IDS_MENU_TAB_DUPLICATE`, `IDS_MENU_TAB_CLOSE`, `IDS_MENU_TAB_NEXT`, `IDS_MENU_TAB_PREVIOUS`, `IDS_MENU_TAB_CLOSEOTHERS`, `IDS_MENU_TAB_CLOSERIGHT`, `IDS_TABS_TT_NEW`, `IDS_TABS_TT_LIST`, `IDS_TABS_CLOSECONFIRM` from 14212 in `src/texts.rh2` after `IDS_CMDSHELL_ERREXEC 14211`
- [x] T007 [P] Add the English strings to `src/lang/texts.rc2` with the exact texts of contracts/commands-and-shortcuts.md §3 (`&New Tab\tCtrl+Shift+T`, `&Close Tab\tCtrl+Shift+W`, `Ne&xt Tab\tCtrl+Shift+Page Down`, `&Previous Tab\tCtrl+Shift+Page Up`, …, `%d tab(s) will be closed when tabs are turned off. Continue?`); accelerators unique inside the *Tabs* submenu
- [x] T008 [P] Add `CONTROL "Show ta&bs in panels",IDC_PANELTABS,"Button",BS_AUTOCHECKBOX | WS_TABSTOP,1,75,169,12` to `IDD_CFGPAGE_APPEARANCE` in `src/lang/lang.rc` (after `IDC_PANELZOOM`, line ~1157; accelerator `b` — `T` is taken by `&Thumbnails`); build the language DLL with plain `build.cmd` to confirm the template compiles

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the pure rules + tests, the option, the tab model, the switch algorithm, the strip window with its layout, and the start-up wiring — everything every story needs

**⚠️ CRITICAL**: no user story can be demonstrated until this phase is complete

- [x] T009 Declare the public API in `src/common/saltabs.h` per data-model.md §1 and §3: `struct CSalTabRecord { char Location[2 * SAL_MAX_PATH_UTF8]; int ViewTemplateIndex; int SortType; BOOL ReverseSort; BOOL FilterEnabled; char FilterMasks[MAX_GROUPMASK]; }` (include the size constants from `src/common/salpath.h`; if `MAX_GROUPMASK` lives in a core header, define `SAL_TAB_FILTER_MAX` locally and `static_assert` equality where both are visible), `void SalTabTitleFromLocation(const char* location, char* title, int titleSize)`, `int SalTabsIndexAfterClose(int count, int closed, int active)`, `int SalTabsCycle(int count, int active, BOOL forward)`, `void SalTabsMove(int count, int from, int to, int* active)`, `BOOL SalTabRecordClamp(CSalTabRecord* rec, int maxSortType)` (returns FALSE when the record must be dropped)
- [x] T010 Implement `src/common/saltabs.cpp` per data-model.md §1 "Derived" and §3 "Operations": title = last `\`/`/` component after stripping a trailing separator; a drive root (`X:\`) and a UNC root (`\\server\share`) returned whole; `fsname:userpart` → last component of the user part or the whole user part; byte-wise UTF-8/WTF-8 safe (never split a multi-byte sequence, use `SalU8TrimIncompleteTail` when truncating to `titleSize`); `IndexAfterClose`: `closed < active` → `active - 1`; `closed == active` → `closed` if `closed < count - 1` else `closed - 1`; `Cycle` wraps; `Move` shifts and keeps `*active` on the moved record; `Clamp`: sort into `[0, maxSortType]`, view index `< 1` → 2, empty location → FALSE
- [x] T011 Add `TestPanelTabs078()` to `src/saltests/saltests.cpp` covering quickstart.md §1's list: titles for `D:\Work\Reports`, `D:\Work\`, `D:\`, `\\server\share`, `\\server\share\sub`, `C:\x\a.zip`, `C:\x\a.zip\sub`, `ftp://user@server/dir/sub` and `ftp://user@server`, `sftp:host/path/`, a non-ASCII name (`G:\Můj disk\Nový projekt` → `Nový projekt`), a name with the WTF-8 bytes of an unpaired surrogate, truncation to a small `titleSize`; `IndexAfterClose` for closed left/at/right of active and the last-tab case; `Cycle` both directions incl. wrap; `Move` forward/backward with active following; `Clamp` sort/view/empty; register the call in `main()` after `TestCommandShell071();`, run `saltests.exe` → `0 failed`
- [x] T012 [P] Add `BOOL IsLocked() const { return Lock; }` to `class CPathHistory` in `src/salamand.h` (public section, next to `HasForward()`), research R4 step 1
- [x] T013 [P] Add `int PanelTabs;` to `struct CConfiguration` in `src/cfgdlg.h` next to `ShowPanelCaption` (line ~296); default `PanelTabs = TRUE;` next to `ShowPanelCaption = TRUE;` in `CConfiguration::CConfiguration()` in `src/dialogs4.cpp` (line ~381); add `const char* CONFIG_PANELTABS_REG = "Panel Tabs";` to the name block in `src/mainwnd2.cpp` (next to `CONFIG_SHOWPANELCAPTION_REG`, line ~285); write it in `CMainWindow::SaveConfig` next to `CONFIG_SHOWPANELCAPTION_REG` (line ~1630) and read it in `LoadConfig` next to it (line ~3170) — `GetValue` result ignored so an absent value keeps the default (contracts/persistence-and-option.md §1)
- [x] T014 Declare `class CPanelTab` and `class CPanelTabs` in `src/paneltabs.h` per data-model.md §2–§3: `CPanelTab : public CSalTabRecord` with `char FocusName[SAL_FIND_NAME_U8]; int TopIndex; int XOffset; CNames Selection; CTopIndexMem TopIndexMem; BOOL UserWorkedOnThisPath; CPathHistory* PathHistory; BOOL Visited;` (constructor allocates `PathHistory`, destructor deletes it; copy constructor and `operator=` deleted); `CPanelTabs` with `TIndirectArray<CPanelTab> Tabs; int ActiveIndex; int ContextTabIndex; BOOL SwitchInProgress;` and methods `Add(const CSalTabRecord&, int afterIndex)`, `Remove(int)`, `Count()`, `Active()`, `At(int)`, `Move(from, to)` delegating index rules to `saltabs.h`
- [x] T015 Add to `class CFilesWindow` in `src/fileswnd.h`: `CPanelTabs Tabs;`, `CTabWindow* TabStrip;` (next to `DirectoryLine`), and the method declarations `void CaptureActiveTab(); BOOL SwitchToTab(int index); void NewTab(); void DuplicateTab(int index); BOOL CloseTab(int index); void CloseOtherTabs(int keepIndex); void CloseTabsToRight(int index); void MoveTab(int from, int to); void OpenIndexInNewTab(int itemIndex); void SetTabsEnabled(BOOL on); void ToggleTabStrip(); void UpdateTabStrip();`; in `CFilesWindow::CFilesWindow` (`src/fileswn1.cpp:1374-1528`) create record 0 with the panel's freshly created `PathHistory` (record 0 owns it; the panel pointer refers to it) and `TabStrip = NULL`; in `~CFilesWindow` (`:1530-1569`) delete no history twice (the tab set owns them)
- [x] T016 Implement `CFilesWindow::CaptureActiveTab()` in `src/paneltabs.cpp` (research R4 step 3): `GetGeneralPath(rec.Location, sizeof, TRUE)`, `GetViewTemplateIndex()`, `SortType`, `ReverseSort`, `Filter.GetMasksString()`, `FilterEnabled`, caret name via `GetCaretIndex()` with the `index < Dirs->Count ? Dirs->At(index) : Files->At(index - Dirs->Count)` idiom (empty when out of range), `ListBox->GetTopIndex()`, `ListBox->GetXOffset()`, selected names with the `StoreSelection` loop shape into `tab.Selection` (`Clear`, `SetCaseSensitive(IsCaseSensitive())`, `Add`, `Sort`), `TopIndexMem` copy, `UserWorkedOnThisPath`, `Visited = TRUE`
- [x] T017 Implement `CFilesWindow::SwitchToTab(int target)` in `src/paneltabs.cpp` exactly per research R4 steps 1–7: guards (`target == ActiveIndex`, `FilesActionInProgress`, `MainWindow->HasLockedUI()`, `Tabs.SwitchInProgress`, `PathHistory->IsLocked()`), `CancelUI()`, `RefreshPathHistoryData()`, `CaptureActiveTab()`, pre-set `SortType`/`ReverseSort`, `Filter.SetMasksString` + `PrepareMasks` (fallback `"*.*"`) + `FilterEnabled`, `IsViewTemplateValid` → `SelectViewTemplate(idx, FALSE, FALSE, VALID_DATA_ALL, FALSE, TRUE)`, swap `PathHistory` to the target's object, `ChangeDir(rec.Location, rec.TopIndex, rec.FocusName, 3, &failReason, TRUE)`; on `CHPPFR_CANNOTCLOSEPATH` revert sort/filter/view/history and post `WM_USER_REFRESH_DIR` (`MyTimeCounter++`), return FALSE; on success restore `TopIndexMem`, re-select by names (`Reselect` shape over `tab.Selection`, then `RepaintListBox(DRAWFLAG_DIRTY_ONLY | DRAWFLAG_SKIP_VISTEST)` + `PostMessage(HWindow, WM_USER_SELCHANGED, 0, 0)`), `RefreshListBox(rec.XOffset, ListBox->GetTopIndex(), FocusedIndex, FALSE, FALSE)` only when `XOffset != 0 && GetViewMode() == vmDetailed`, `UserWorkedOnThisPath = rec.UserWorkedOnThisPath`, `ActiveIndex = target`, `Visited = TRUE`, re-capture the location when `ChangeDir` fell back, `IdleRefreshStates = TRUE`, `UpdateTabStrip()`. **Verify first** (record in fix-log): `CPathHistory::AddPath` in `src/salamdr3.cpp` does not append a path equal to the top item and `ChangeActualPathData` ignores a non-matching path; if either is false, call `RemoveCurrentPathFromHistory()` on the old history before the swap
- [x] T018 [P] Make `CFilesWindow::ClearPluginFSFromHistory` (`src/fileswn9.cpp:81`) and `CFilesWindow::ClearHistory()` (`src/fileswn1.cpp:1571`) iterate every tab's `PathHistory` (research R15); keep the panel's own pointer in the loop exactly once
- [x] T019 Implement the strip window in `src/tabwnd.cpp` per contracts/tab-strip-ui.md §1–§3: `GetNeededHeight()` = `2 + EnvFontCharHeight + 2 + MulDiv(2, GetScaleForSystemDPI(), 100)`; `WM_SIZE`/`WM_ERASEBKGND` with `ItemBitmap.Enlarge` (both, the `CStatusWindow` shape); `Paint()` into `ItemBitmap.HMemDC` + `BitBlt`: background `HDialogBrush`, tab widths per §2 (equal widths clamped to `[minTabWidth, maxTabWidth]` measured from `EnvFont`, visible run containing the active tab), tab fills/text colours per §3 (`HActiveCaptionBrush`/`HInactiveCaptionBrush`, `CurrentColors[ACTIVE_CAPTION_FG/INACTIVE_CAPTION_FG/HOT_ACTIVE/HOT_INACTIVE]`, `ThemeSysColorBrush(COLOR_BTNFACE)`/`ThemeSysColor(COLOR_BTNTEXT)`, `ThemeDrawEdge`), titles via `SalU8ToWAlloc` + `DrawTextW` (measure with `DT_CALCRECT` using the same API; `DT_END_ELLIPSIS`), GDI glyphs `+`, `×`, `▾` with a `ThemeSysColor(COLOR_BTNTEXT)` pen; `HitTest(x, y, &item, &part)` (part = tab / close glyph / plus / list button / none) with rects cached at paint time; hot tracking (`WM_MOUSEMOVE` + `TrackMouseEvent` + `WM_MOUSELEAVE`/`WM_CANCELMODE`, repaint only the two changed items); `InvalidateAndUpdate(BOOL)`, `Repaint()`, `SetFont()`, `OnColorsChanged()`; every mouse case starts with `if (MainWindow->HasLockedUI()) break;`; no `SetFocus`, no `WS_TABSTOP`
- [x] T020 Wire creation, layout and lifetime: `CFilesWindow::ToggleTabStrip()` in `src/fileswn2.cpp` modelled on `ToggleDirectoryLine` (`:926-965`: `CWINDOW_CLASSNAME2`, `WS_CHILD | WS_CLIPSIBLINGS`, no `WS_VISIBLE`, `(HMENU)IDC_TABSTRIP`, forced `WM_SIZE`, `ShowWindow`, `MainWindow->LayoutWindows()`); `CFilesWindow::SetTabsEnabled(BOOL)` in `src/paneltabs.cpp` per contracts/persistence-and-option.md §3 (on: ensure ≥ 1 record via `CaptureActiveTab`, create strip; off: delete all records except the active one, destroy strip; idempotent); panel `WM_SIZE` in `src/fileswnb.cpp:72-119` gains `tsHeight = TabStrip && TabStrip->HWindow ? TabStrip->GetNeededHeight() : 0`, strip at `(0, 0, width, tsHeight)`, Directory Line at `y = tsHeight`, list at `y = tsHeight + dlHeight`, `windowsCount++`; `WM_ERASEBKGND` (`:121-135`) keeps exactly one 3-pixel filler; `WM_CREATE` (`:1024-1091`) creates `TabStrip = new CTabWindow(this)` (`ooStatic`, window created later by `SetTabsEnabled`) and `WM_DESTROY` (`:1093-1117`) does `TabStrip->DestroyWindow(); delete TabStrip; TabStrip = NULL;` before the Directory Line; main `WM_SIZE` Middle Toolbar offset (`src/mainwnd3.cpp:5526-5540`) adds each panel's strip height; `CMainWindow::GetDirectoryLineHeight()` (`src/mainwnd1.cpp:1271-1281`) returns strip height + Directory Line height (verify the Alt+F1 anchor `src/drivelst.cpp:2481-2489` and `CM_OPENHOTPATHS` `src/mainwnd3.cpp:4056-4063` now land under the Directory Line); call `LeftPanel->SetTabsEnabled(Configuration.PanelTabs); RightPanel->SetTabsEnabled(...)` after the start-up path application in `CMainWindow::LoadConfig` (`src/mainwnd2.cpp` after line ~3932) and in the `!LoadConfig` defaults branch of `src/salamdr1.cpp` (`:4439-4460`)

**Checkpoint**: `build.cmd` green (encoding guard `TOTAL: 0`), `saltests.exe` `0 failed` with the new checks; the application starts with a one-tab strip above each Directory Line (tab titled by the directory, `+` painted), the Middle Toolbar and Alt+F1 menu sit below the Directory Line; `reg add … /v "Panel Tabs" /t REG_DWORD /d 0` → no strip, layout identical to 0.1.7

---

## Phase 3: User Story 1 - Several directories in one panel (Priority: P1) 🎯 MVP

**Goal**: with tabs on (the default) a user opens tabs with `+`, switches by clicking, closes with `×`, sees the directory name as the title, reaches hidden tabs through the list button, and turns the whole thing off (with the confirmation) or on again in Configuration ▸ Appearance without restart

**Independent Test**: quickstart.md §3 (first start, default on), §4 steps 1–7 (basic tab work) and §11 (option semantics)

### Implementation for User Story 1

- [x] T021 [US1] Implement the tab-set operations in `src/paneltabs.cpp` per research R5: `NewTab()` (record from `CaptureActiveTab` of the current panel state, fresh session state, appended, then `SwitchToTab(last)`), `DuplicateTab(i)` (copy of record `i` inserted after it, then switch), `CloseTab(i)` (if `i == ActiveIndex`: `SwitchToTab(SalTabsIndexAfterClose(...))` first and abort when it returns FALSE; then `Tabs.Remove(i)` and fix `ActiveIndex`; refuse when `Count() == 1`), `CloseOtherTabs(keep)`, `CloseTabsToRight(i)`, `MoveTab(from, to)`; every operation ends with `UpdateTabStrip()`
- [x] T022 [US1] Implement the strip interactions in `src/tabwnd.cpp` per contracts/tab-strip-ui.md §4: left click on a tab → `MainWindow->CancelPanelsUI()`, `FocusPanel(FilesWindow)` when it is not the active panel, `FilesWindow->SwitchToTab(index)`; click on `×` → `CloseTab(index)`; click on `+` → `NewTab()`; the `×` glyph is painted on the active tab and the hovered tab only and never when `Tabs.Count() == 1`; raise the main window when the application is in the background (the `CStatusWindow` `WM_RBUTTONUP` postlude); `WM_SETCURSOR` arrow
- [x] T023 [US1] Keep titles current: at the end of `CFilesWindow::DirectoryLineSetText()` (`src/fileswn1.cpp:1729-1808`) refresh the active record's `Location` (`GetGeneralPath(..., TRUE)`) and call `UpdateTabStrip()` (repaint only); implement `UpdateTabStrip()` in `src/paneltabs.cpp` as `if (TabStrip && TabStrip->HWindow) TabStrip->InvalidateAndUpdate(FALSE)`
- [x] T024 [US1] Implement the tab-list button in `src/tabwnd.cpp` per contracts/tab-strip-ui.md §2: shown only when not all tabs fit; click → `BeginStopRefresh()`, `CMenuPopup` filled with every tab's title (`MENU_STATE_CHECKED` on the active one, ids `1 + index`), `Track(MENU_TRACK_RETURNCMD | MENU_TRACK_VERTICAL, …)` anchored under the button with an exclude rect (the `OpenDirHistory` shape, `src/fileswnb.cpp:1365-1390`), `EndStopRefresh()`, then `SwitchToTab(cmd - 1)`
- [x] T025 [US1] Activation and state hooks (research R18): repaint the strip wherever the Directory Line is repainted for activation — `WM_NCACTIVATE` (`src/mainwnd3.cpp:5577-5594`), `CMainWindow::ChangePanel` (`src/mainwnd4.cpp:1226-1234`), `CMainWindow::FocusPanel` (`:1263-1303`); add `TabStrip->SetFont()` to `CFilesWindow::SetFont()` (`src/fileswnb.cpp:1568-1576`), an unconditional `TabStrip->OnColorsChanged()` branch to `CFilesWindow::OnColorsChanged()` (`src/fileswn0.cpp:3448-3471`), and `EnableWindow(TabStrip->HWindow, !lock)` to `CFilesWindow::LockUI` (`src/fileswnb.cpp:1580`)
- [x] T026 [US1] Configuration page per contracts/persistence-and-option.md §2: `ti.CheckBox(IDC_PANELTABS, Configuration.PanelTabs)` in `CCfgPageAppearance::Transfer` (`src/dialogs5.cpp:2851`); in `CCfgPageAppearance::Validate` (`:2882`) when the box is unchecked, `Configuration.PanelTabs` is on and `MainWindow->LeftPanel->Tabs.Count() + MainWindow->RightPanel->Tabs.Count() > 2`, show `SalMessageBox(HWindow, <IDS_TABS_CLOSECONFIRM composed with LoadStrU8 and the number of tabs that will close>, LoadStr(IDS_QUESTION), MB_YESNO | MB_ICONQUESTION)` and `ti.ErrorOn(IDC_PANELTABS)` on `IDNO`; in `WM_USER_CONFIGURATION` (`src/mainwnd3.cpp:1949-2034`) snapshot `BOOL oldPanelTabs = Configuration.PanelTabs;` before the dialog and after `IDOK`, when changed, run `LockWindowUpdate(HWindow); LeftPanel->SetTabsEnabled(Configuration.PanelTabs); RightPanel->SetTabsEnabled(Configuration.PanelTabs); LayoutWindows(); LockWindowUpdate(NULL);`
- [x] T027 [US1] Run `build.cmd` (guard `TOTAL: 0`) + `saltests.exe`, then execute quickstart.md §3, §4 steps 1–7 and §11 (incl. the `D:\`, `\\server\share`, `a.zip`, `a.zip\sub` titles, the inactive-panel click, F5 to the right panel's active tab, the 3-tab confirmation and the on/off round trip); record every result in `specs/078-panel-tabs/fix-log.md`

**Checkpoint**: US1 delivers the whole request; with one tab per panel the program is 0.1.7 plus the strip

---

## Phase 4: User Story 2 - Nothing else changes (Priority: P1)

**Goal**: with tabs off nothing differs from 0.1.7; with tabs on every command, dialog, plugin service and background mechanism acts on the active tabs and background tabs are invisible; leaving a tab is exactly leaving that location today, and a refused leave keeps the tab

**Independent Test**: quickstart.md §5 (a) and (b) — the existing manual matrix twice — and §6 (plugin file systems and archives, incl. the refusal cases)

### Implementation for User Story 2

- [x] T028 [US2] Hit-testing and help context: add `mwhteLeftTabStrip`, `mwhteRightTabStrip` to `CMainWindowsHitTestEnum` in `src/mainwnd.h` (`:337-360`); test `PtInChild(LeftPanel->TabStrip ? LeftPanel->TabStrip->HWindow : NULL, p)` before the Directory Line test in `CMainWindow::HitTest` (`src/mainwnd1.cpp:2139-2168`, both sides); return early for both values in `OnWmContextMenu` (`:2173-2188` — the strip owns its menu, FR-033); map both to `IDH_TABSTRIP` in `CMainWindow::MapClientArea` (`src/mainwnd4.cpp:1515-1626`)
- [x] T029 [US2] Audit the off state end to end in `src/paneltabs.cpp`, `src/tabwnd.cpp`, `src/fileswnb.cpp` and `src/mainwnd1.cpp` and fix what is found (record in `specs/078-panel-tabs/fix-log.md`): with `Configuration.PanelTabs == FALSE` no strip window exists, `SwitchToTab`/`NewTab`/`CloseTab` are never reachable from the UI, the panel `WM_SIZE` reserves 0 pixels for the strip, `GetDirectoryLineHeight()` returns today's value, and the tab set holds exactly one record (so `CaptureActiveTab` cost is nil); confirm with a debug build that a 0.1.7 registry (no `Panel Tabs`, no `Tabs`) starts with the strip (default on) and that `Panel Tabs = 0` starts without it
- [x] T030 [US2] Verify the leave semantics (FR-019, FR-020, Clarification Q1) in code before the matrix: trace that `SwitchToTab` → `ChangeDir` → `PrepareCloseCurrentPath` runs the archive branch (`src/fileswn2.cpp:1279-1305`, update offer) and the plugin branch (`:1364-1372`, `TryCloseOrDetach`) unchanged, that `CHPPFR_CANNOTCLOSEPATH` reaches the revert path of T017, and that `CloseTab` on a background tab touches neither `DetachedFSList` nor any plugin; note any deviation in `specs/078-panel-tabs/fix-log.md`
- [ ] T031 [US2] Run `build.cmd` + `saltests.exe`, then execute quickstart.md §5 (a) with tabs off and §5 (b) with several tabs per panel (copy/move/delete/rename, Create Directory, Compare Directories, Swap, Zoom, one and two Drive Bars, hot paths, Back/Forward, Working Directories, Change Directory, command line, SFTP session on `localhost:2222`, an archive, every menu, Configuration, bug report), then §6 steps 1–5 (SFTP leave/return, the archive-update *Cancel* refusal, closing an SFTP tab with the kept connection still in Alt+F1, the deleted-directory fallback, the duplicated SFTP tab); record results in `specs/078-panel-tabs/fix-log.md`

**Checkpoint**: US1 and US2 verified — the principal goal of the request ("nothing else breaks") holds with tabs off and on

---

## Phase 5: User Story 3 - Tabs come back after a restart (Priority: P2)

**Goal**: each panel's tab list, order, active tab and per-tab view/sort/filter are stored with the configuration and restored at the next start; archive and file-system tabs open lazily; older configurations yield one tab per panel; nothing is written on tab changes

**Independent Test**: quickstart.md §7 steps 1–7

### Implementation for User Story 3

- [x] T032 [US3] Writer in `CMainWindow::SavePanelConfig` (`src/mainwnd2.cpp:1193-1218`) per contracts/persistence-and-option.md §4: `panel->CaptureActiveTab()` first; legacy values unchanged; then `CreateKey(actKey, "Tabs", tabsKey)`, `ClearKey(tabsKey)`, for each record `CreateKey(tabsKey, "<n>", k)` + `SetValue` of `Path` (REG_SZ, `-1`), `View Type`, `Sort Type`, `Reverse Sort`, `Enable Filter` (REG_DWORD), `Filter` (REG_SZ) and `CloseKey(k)`; `CloseKey(tabsKey)`; `SetValue(actKey, "Active Tab", REG_DWORD, &ActiveIndex, sizeof(DWORD))`; add the two new value-name constants (`PANEL_TABS_REG = "Tabs"`, `PANEL_ACTIVETAB_REG = "Active Tab"`) to the name block (`:185-197`)
- [x] T033 [US3] Reader in `CMainWindow::LoadPanelConfig` (`src/mainwnd2.cpp:2242-2314`), inside the existing `PANEL_PATH_REG` gate: after the legacy values, `OpenKey(actKey, "Tabs", tabsKey)` → read `0`, `1`, … until `OpenKey` fails, each into a `CSalTabRecord` (buffer sizes as the fields), drop records failing `SalTabRecordClamp(rec, stAttr)`; if none survived keep the single record 0 built from the panel; read `Active Tab` and clamp; replace the panel's tab set with the loaded records (`Visited = FALSE` for all but the active one, fresh histories); after the start-up path application (the block at `:3897-3926`) the active record is re-captured by `SetTabsEnabled` (T020) so an FS/archive location active at exit is not reconnected (FR-028) and command-line `-l/-r/-a` still win
- [ ] T034 [US3] Run `build.cmd` + `saltests.exe`, then execute quickstart.md §7 steps 1–7 (three-plus-two tabs incl. archive and SFTP, lazy opening with the login prompt, active SFTP tab → last disk path, the vanished-directory fallback, `Export Configuration` → `.reg` inspection for `Left Panel\Tabs\0\Path` and the absence of any password, a 0.1.7 registry, kill-and-restart with Process Monitor confirming no registry writes on tab changes, option off → one entry per side); record results in `specs/078-panel-tabs/fix-log.md`

**Checkpoint**: US1–US3 verified; tabs are the user's working layout

---

## Phase 6: User Story 4 - Keyboard-driven tab work (Priority: P2)

**Goal**: New / Close / Next / Previous Tab by keyboard, all seven commands in the *Left* and *Right* menus at every skill level with shortcuts shown, hidden while tabs are off, no existing shortcut changes meaning

**Independent Test**: quickstart.md §8 steps 1–5

### Implementation for User Story 4

- [x] T035 [US4] `WM_COMMAND` handlers in `CMainWindow::WindowProc` (`src/mainwnd3.cpp`, near `CM_ACTIVE_CHANGEDIR`/`CM_LEFT_CHANGEDIR`/`CM_RIGHT_CHANGEDIR`, `:3773-3789`) for all 21 ids of contracts/commands-and-shortcuts.md §1: resolve the panel (`GetActivePanel()` / `LeftPanel` / `RightPanel`), do nothing when `!Configuration.PanelTabs`, honour `panel->Tabs.ContextTabIndex` (when ≥ 0) for Close / Duplicate / Close Others / Close Right and reset it afterwards, else act on `ActiveIndex`; Next/Previous via `SalTabsCycle` + `SwitchToTab`
- [x] T036 [US4] Menus: append the *Tabs* submenu rows of contracts/commands-and-shortcuts.md §2 to the *Left* menu (`src/menu4.cpp:21-47`, after `IDS_MENU_LEFT_REFRESH`) and the *Right* menu (`:225-251`) with `MNTS_B | MNTS_I | MNTS_A`; in `WM_USER_INITMENUPOPUP` (`src/mainwnd3.cpp:4845+`) add `case CML_LEFT:`/`case CML_RIGHT:` that removes the trailing separator + submenu with `RemoveItemsRange` when `!Configuration.PanelTabs` and re-inserts them from the template rows when on (the `CML_LEFT_GO` idiom, `:4820-4844`), and `case CML_LEFT_TABS:`/`case CML_RIGHT_TABS:` that `EnableItem`s Close Tab / Close Other Tabs (count > 1) and Close Tabs to the Right (tabs exist right of the active one)
- [x] T037 [US4] Shortcuts per contracts/commands-and-shortcuts.md §4: at the top of `CFilesWindow::OnSysKeyDown` (`src/fileswn0.cpp:1104`, before the `VK_NEXT`/`VK_PRIOR` and letter branches) handle `Configuration.PanelTabs && controlPressed && shiftPressed && !altPressed` for `'T'` → `PostMessage(MainWindow->HWindow, WM_COMMAND, CM_ACTIVE_NEWTAB, 0)`, `'W'` → `CM_ACTIVE_CLOSETAB`, `VK_NEXT` → `CM_ACTIVE_NEXTTAB`, `VK_PRIOR` → `CM_ACTIVE_PREVTAB` (set `SkipCharacter = TRUE` for the letters, return TRUE); fall through otherwise; add `case CONTROL_SHIFT:` under `'T'` (`src/keyboard.cpp:601`), `'W'` (`:640`), `VK_PRIOR` (`:81`) and `VK_NEXT` (`:93`) in `IsSalHotKey`; do **not** touch `src/salamand.rc`
- [ ] T038 [US4] Run `build.cmd` + `saltests.exe`, then execute quickstart.md §8 steps 1–5 (Ctrl+Shift+T/W/PgDn/PgUp, the *Tabs* submenu at Beginner/Intermediate/Advanced and its absence with tabs off, Ctrl+T/Ctrl+W/Ctrl+Tab/Ctrl+PgUp/PgDn/Tab/Ctrl+Shift+Tab unchanged, the command line unaffected, Plugins Manager refusing Ctrl+Shift+T as a hotkey); record results in `specs/078-panel-tabs/fix-log.md`

**Checkpoint**: US1–US4 verified; keyboard users need no mouse

---

## Phase 7: User Story 5 - Chrome-style mouse conveniences (Priority: P3)

**Goal**: middle click on a folder opens it in a background tab, middle click on a tab closes it, tabs can be dragged into a new order, tooltips show the full location, and the tab context menu offers New / Duplicate / Close / Close Others / Close to the Right on the clicked tab

**Independent Test**: quickstart.md §9 steps 1–5

### Implementation for User Story 5

- [x] T039 [US5] Middle click on items: add `case WM_MBUTTONDOWN:` / `case WM_MBUTTONUP:` to `CFilesBox::WindowProc` in `src/filesbx1.cpp` routed like `WM_RBUTTONDOWN` (`:1505-1513`, with the `HasLockedUI()` check) to a new `CFilesWindow::OnMButtonUp(WPARAM, LPARAM)`; implement `CFilesWindow::OpenIndexInNewTab(int index)` in `src/paneltabs.cpp` per research R5: `GetIndex(x, y)` (skip `INT_MAX` and out-of-range), only `index < Dirs->Count` (files do nothing), build the target location with the `OpenFocusedInOtherPanel` shape (`src/fileswn8.cpp:1437-1513`: disk/archive `GetGeneralPath` + `SalPathAddBackslash` + name; UNC-root `..` → nethood; FS `GetPluginFS()->GetFullName(*file, isDir /*2 for ".."*/, …)` then `ConvertPathToExternal`) in `SAL_MAX_PATH_UTF8`-sized `CSalPathBuf` buffers, append a background record (current view/sort/filter, `Visited = FALSE`), `UpdateTabStrip()`; only when `Configuration.PanelTabs`
- [x] T040 [US5] In `src/tabwnd.cpp`: middle click on a tab → `CloseTab(index)` (never the only tab); tooltips per contracts/tab-strip-ui.md §5 — `SetCurrentToolTip(HWindow, id)` from `WM_MOUSEMOVE` (`id = 0` while any button is down), `SetCurrentToolTip(NULL, 0)` on `WM_MOUSELEAVE`/`WM_CANCELMODE`/button-down, `WM_USER_TTGETTEXT` answering `1` → `LoadStr(IDS_TABS_TT_NEW)`, `2` → `IDS_TABS_TT_LIST`, `100 + index` → the tab's `Location` through `CopyToolTipAnswer`, `default: TRACE_E`
- [x] T041 [US5] Drag-to-reorder in `src/tabwnd.cpp` per contracts/tab-strip-ui.md §4 and the `CEditListBox` gesture (`src/edtlbwnd.cpp:993-1006`, `1036-1062`, `1065-1103`, `1125-1133`): `SetCapture` + `WaitForDrag`/`DragAnchor` on left button-down over a tab, `SM_CXDRAG`/`SM_CYDRAG` threshold (clamped ≥ 1), while dragging compute the insert position with an `InsertMarkHitTest`-style rule (prefer "after the previous tab" near a left edge, `src/toolbar2.cpp:169-232`) and draw an I-beam like `CToolBar::DrawInsertMark` (`:805-846`, theme pen), `WM_SETCURSOR` returns TRUE while captured, commit with `MoveTab(from, to)` on `WM_LBUTTONUP`, cancel on `WM_RBUTTONDOWN`/`WM_CANCELMODE`/Escape (`WM_GETDLGCODE | DLGC_WANTMESSAGE` while dragging); a click without drag still switches
- [x] T042 [US5] Context menu in `src/tabwnd.cpp` per contracts/tab-strip-ui.md §6: on `WM_RBUTTONUP` build an ad-hoc `CMenuPopup` (`MENU_ITEM_INFO` shape of `src/mainwnd1.cpp:2191-2208`) with local ids 1–5 for New / Duplicate / Close / Close Others / Close Right (greyed per §6; only New on the strip background), set `FilesWindow->Tabs.ContextTabIndex` to the clicked tab (or `-1`), `BeginStopRefresh()`/`Track(MENU_TRACK_RETURNCMD | MENU_TRACK_RIGHTBUTTON, …)`/`EndStopRefresh()`, map the result to `CM_LEFT_*`/`CM_RIGHT_*` by `FilesWindow == MainWindow->LeftPanel` and `PostMessage(MainWindow->HWindow, WM_COMMAND, …)`; include the `export_mnu.py` comment block `MENU_TEMPLATE_ITEM TabStripMenu[]` listing the five `IDS_MENU_TAB_*` ids (the `src/mainwnd1.cpp:2322-2358` convention)
- [ ] T043 [US5] Run `build.cmd` + `saltests.exe`, then execute quickstart.md §9 steps 1–5 (middle click on folder / `..` / file in disk, archive and SFTP tabs; middle click on tabs; drag reorder and Escape; tooltips; context menu on a tab and on the background; the unchanged Directory/Header/Information Line and item menus); record results in `specs/078-panel-tabs/fix-log.md`

**Checkpoint**: all five stories independently verified

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: translations, manual, stress/theme/encoding checks, hygiene, release bookkeeping, closing record

- [x] T044 Translation refresh (research R20, memory: `.slt` import is positional): `src\vcxproj\build_langs.cmd --export-templates --module salamand` → `cd tools` → `python -m translate.merge --module salamand --dry-run` (record gap count and DeepL cost in fix-log) → `python -m translate.merge --module salamand` → `python -m translate.slt --verify`; open the *Left* menu in Czech and German, check the *Tabs* submenu wording; add a `_feature_078` note and per-language pins for the *Tab* term in `translations/ui-overrides.json` (`salamand` section: cs/sk "karta", de "Registerkarte", fr "onglet", es "pestaña", nl "tabblad", ro "filă") where the machine result differs, re-run `merge`; commit the 8 regenerated `.slt` files and `.origin` sidecars
- [x] T045 [P] Manual (contracts/commands-and-shortcuts.md §5, commit `66f9443` pattern): new `help/src/hh/salamand/windows_tabstrip.htm` (Tandem Commander header/footer, © 2026 Pavel Stupka; the strip, `+`, `×`, list button, context menu, middle click, drag, what leaving a tab means for archives and plugin file systems, two tabs on one connection), mention the strip in `windows_panel.htm`, add four rows to `shortcuts_keyboard.htm` after the Ctrl+Shift+Left/Right row (line ~161), document *Show tabs in panels* and the close confirmation in `configuration_appea.htm`; TOC/index blocks in `help/src/salamand.hhc` (Panel Components chapter, after Directory Line) and `help/src/salamand.hhk`; `IDH_TABSTRIP=hh\salamand\windows_tabstrip.htm` in the `[ALIAS]` section of `help/src/salamand.hhp`
- [ ] T046 [P] Stress, theme and encoding verification: quickstart.md §10 steps 1–6 (20 tabs per side with the list button, narrow panel, five-minute Process Monitor idle with SFTP and network tabs — no activity from background tabs and a thread count equal to the two-panel baseline, the 10,000-entry switch under one second, Dark theme and every colour scheme, font-size/scaling change) and §12 (non-ASCII, Chinese and unpaired-surrogate names in titles and tooltips vs the Directory Line); record results in `specs/078-panel-tabs/fix-log.md`
- [x] T047 Language check after T044 (quickstart.md §13): `build.cmd full`, switch through all 8 shipped UI languages (`translations/languages.cfg`) — *Tabs* submenu, context menu, tooltips, the option label and the close confirmation translated, accelerators unique per menu; record in `specs/078-panel-tabs/fix-log.md`
- [x] T048 Source hygiene: `python tools\check_encoding.py --strict` → `TOTAL: 0`; `python tools\check_encoding.py --draft --format list | findstr /i "tabwnd paneltabs saltabs filesbx1 fileswn0"` → no new findings; `clang-format -i` (repo `.clang-format`) over `src/common/saltabs.*`, `src/paneltabs.*`, `src/tabwnd.*` and the edited regions of the other files (`normalize.ps1` needs PowerShell 7 — not installed; note in fix-log); every new/edited file UTF-8 with BOM; new comments in English; no `src/plugins/shared/` diff (`git diff --stat -- src/plugins/shared` empty, interface stays 106)
- [x] T049 Release bookkeeping (constitution, Release Documentation): `CHANGELOG.md` entry `## [0.1.8]` with *Added* (panel tabs — on by default, how to turn them off in Configuration ▸ Appearance, the strip, the commands and the four shortcuts, restart persistence, what leaving a tab means for archives and plugin file systems) and a *Changed* note that Ctrl+Shift+PgUp/PgDn, previously undocumented duplicates of Shift+PgUp/PgDn, switch tabs while tabs are on; bump `VERSINFO_SALAMANDER_MINORB` and `VERSINFO_BUILDNUMBER` (191 → 192) in `src/plugins/shared/spl_vers.h`, `MyAppVersion` in `setup/tandemcommander.iss`, the version line and a *Recent Changes* entry for 078 in `CLAUDE.md` — all in one change
- [ ] T050 Full quickstart.md pass (§1–§14) on the final `build.cmd full release` build incl. `saltests`, with every result in `specs/078-panel-tabs/fix-log.md`; write `specs/078-panel-tabs/closing-report.md` (what shipped, deviations from the plan, the two `CPathHistory` verifications of T017, open follow-ups such as cached background listings, a *New Tab* toolbar button and drop-onto-tab)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: T001 first (the log); T002–T008 in parallel
- **Foundational (Phase 2)**: T009 → T010 → T011 (pure module then tests); T012, T013 parallel with them; T014 after T009; T015 after T014 (and T004 for the `CTabWindow` type); T016, T017, T018 after T015 (T017 after T012 and T016); T019 after T004; T020 after T015, T019 and T013 — **blocks all user stories**
- **User Stories (Phases 3–7)**: all depend on Phase 2; US2 depends on US1 only for its verification matrix (its code tasks T028–T030 can start after Phase 2); US3, US4 and US5 are independent of each other and of US2; US4's context-menu id handling (T035) is used by US5's T042
- **Polish (Phase 8)**: T044 after every task that adds a string (T007, T008 — and nothing later adds strings); T045, T046 in parallel once the stories are verified; T047 after T044; T048 after all code; T049 after T047/T048; T050 last

### User Story Dependencies

- **US1 (P1)**: after Phase 2 — the MVP
- **US2 (P1)**: code after Phase 2; verification (T031) after US1's T027 because the matrix drives the strip
- **US3 (P2)**: after Phase 2; independent of US2/US4/US5
- **US4 (P2)**: after Phase 2; independent of US2/US3/US5 (the strip is not needed for the commands to work, only to see them)
- **US5 (P3)**: after Phase 2 and US1's T022 (the strip interactions it extends); T042 uses T035's `ContextTabIndex` handling

### Within Each User Story

- Model/list operations before strip interactions before hooks before the page (US1)
- Writer before reader (US3); handlers before menus before shortcuts (US4)
- The verification task closes the phase and writes the fix-log entry

### Parallel Opportunities

- Phase 1: T002, T003, T004, T005, T006, T007, T008 (seven different files)
- Phase 2: T012 and T013 alongside T009–T011; T018 alongside T016–T017; T019 alongside T014–T018
- Phase 3: T023 and T025 alongside T022/T024 (different files); T026 alongside all of them
- Across stories after Phase 2: US3 (T032–T033), US4 (T035–T037) and US5 (T039–T041) touch different files and can proceed in parallel with US1
- Phase 8: T045 and T046 in parallel

---

## Parallel Example: Foundational phase

```text
T009 saltabs.h API  →  T010 saltabs.cpp  →  T011 TestPanelTabs078 (saltests)
T012 CPathHistory::IsLocked            (parallel)
T013 CConfiguration::PanelTabs + registry   (parallel)
T014 CPanelTab/CPanelTabs  →  T015 CFilesWindow members  →  T016 CaptureActiveTab  →  T017 SwitchToTab
                                                             T018 histories over all tabs (parallel with T016/T017)
T019 CTabWindow paint/hit test          (parallel with T014–T018)
T020 ToggleTabStrip + SetTabsEnabled + layout + start-up   (after T015, T019, T013)
```

## Parallel Example: after Phase 2

```text
Developer A: US1  T021 → T022 → (T023 ‖ T024 ‖ T025 ‖ T026) → T027
Developer B: US3  T032 → T033 → T034
Developer C: US4  T035 → T036 → T037 → T038
Developer D: US5  T039 ‖ (T040 → T041 → T042, after T022) → T043
Then US2: T028 ‖ T029 ‖ T030 → T031 (after T027)
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Phase 1 (T001–T008) and Phase 2 (T009–T020) — the model, the switch and the strip
2. Phase 3 (T021–T027) — interactions, page, verification
3. **STOP and VALIDATE** with quickstart §3, §4, §11; at this point tabs are usable, on by default, and switchable off

### Incremental Delivery

1. US2 (T028–T031) proves the principal goal — run this before anything else ships
2. US3 (T032–T034) makes tabs a working layout across restarts
3. US4 (T035–T038) keyboard and menus
4. US5 (T039–T043) mouse conveniences
5. Phase 8 (T044–T050) translations, manual, stress, hygiene, release, closing report

### Notes

- Every phase's last task writes to `fix-log.md`; a ticked box in this file means "verified against quickstart", not "code written".
- **Do not run `build.cmd full` between T007/T008 and T044** — the language build fails by design until the `.slt` refresh; use plain `build.cmd` (English DLL) until then.
- Commit after each task or logical group with a `[078]`-prefixed message (repo convention); never touch `src/plugins/shared/` (interface 106).
- Two facts the switch algorithm depends on are verified inside T017 (`CPathHistory::AddPath` de-duplication, `ChangeActualPathData` on a non-matching path) — do not skip the check, record the outcome.
- The two popup anchors (Alt+F1 drive menu, hot-paths popup) are verified inside T020 through the `GetDirectoryLineHeight()` semantics change; if either still lands on the strip, fix it there.
- Keep `HiddenNames`/`OldSelection` per visit (research R3) — do not add them to the tab record.
