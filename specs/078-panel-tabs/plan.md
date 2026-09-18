# Implementation Plan: Panel Tabs

**Branch**: `078-panel-tabs` | **Date**: 2026-09-18 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/078-panel-tabs/spec.md`
(clarified 2026-09-18) and the codebase analysis in [analysis.md](analysis.md)

## Summary

Each of the two file panels gets a Chrome-style tab strip: one tab per
remembered directory view, a `+` button, close glyphs, a tab-list button when
tabs no longer fit, middle-click and drag conveniences, seven commands with
four shortcuts, restart persistence, and a single on/off option (on by
default) that restores version 0.1.7 exactly when off.

Technical approach (details in [research.md](research.md)):

- **A tab is remembered view state, not a second panel** (R1). Each side keeps
  its single `CFilesWindow`; a `CPanelTabs` member holds ordered `CPanelTab`
  records (location text, view/sort/filter, cursor, selection, scroll, own
  Back/Forward history). Switching = snapshot the current record → pre-set
  sort/filter/view → `ChangeDir(location)` → restore cursor/selection/scroll
  (R4). Every existing command, dialog, plugin service and background
  mechanism therefore sees an ordinary path change; the plugin ABI, the
  detached-FS model, the snooper, the icon threads, the layout and the ~770
  side-identity references are untouched. A refused leave (plugin, archive
  update) keeps the panel and the strip on the current tab.
- **Location text in the external form** the Change Directory dialog uses
  (`GetGeneralPath(…, TRUE)` ↔ `ChangeDir(…, convertFSPathToInternal = TRUE)`),
  so a background plugin-file-system tab is just text; returning re-attaches a
  kept connection by path exactly as typing the path does (R2, R15).
- **Strip window**: `src/tabwnd.{h,cpp}` rewritten from the dead upstream
  stub — owner-drawn on the shared `ItemBitmap`, `EnvFont`, theme colours and
  the active/inactive caption brushes, hot tracking, tooltips through
  `CopyToolTipAnswer`, `CEditListBox`-style drag-to-reorder, GDI glyphs, no
  keyboard focus, `HasLockedUI` respected; placed above the Directory Line by
  the panel's `WM_SIZE`; the two popup anchors and the Middle Toolbar offset
  that assume the Directory Line starts at the panel top are corrected (R6–R8).
- **Commands**: 21 ids in the free block 2860-2889 (active/left/right ×
  7), a *Tabs* submenu at the end of *Left* and *Right* (all skill levels),
  removed while the option is off with the existing dynamic-range idiom; a
  strip-owned context menu that posts the side-specific commands (R9, R10).
- **Shortcuts** "Chrome's tab keys with Shift added": Ctrl+Shift+T (new),
  Ctrl+Shift+W (close), Ctrl+Shift+PgDn/PgUp (next/previous), dispatched in
  `OnSysKeyDown` only while tabs are on and reserved in `IsSalHotKey`; no
  documented shortcut changes meaning (R11).
- **Option** `Configuration.PanelTabs` (default `TRUE`, registry value
  `Panel Tabs`, no config-version bump) with a checkbox on the Appearance
  page, the "N tabs will be closed" confirmation in `Validate`, and an
  immediate `SetTabsEnabled` + relayout after OK (R12, R19).
- **Persistence** under the existing `Left Panel` / `Right Panel` keys: an
  `Active Tab` value and a `Tabs\<n>` subkey list written only by
  `SaveConfig`, read inside the existing `Path` gate, legacy values untouched
  so older builds and the option-off state read the panel as before (R14).
- **Pure rules in `src/common/saltabs.{h,cpp}`** (title derivation, index
  rules, record clamping) unit-tested in `saltests`; the GUI matrix in
  [quickstart.md](quickstart.md) is the human gate (R13, R22).
- **Translations, help, changelog**: ~13 strings + 1 control × 8 languages
  through the `.slt` refresh; manual pages for the strip, the shortcuts and
  the option; changelog entry at the ship gate with the 0.1.8 / build 192
  bump (R20).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143 (VS2022), pure WinAPI  
**Primary Dependencies**: none new — house classes and helpers only
(`CWindow`, `CFilesWindow::ChangeDir`/`SelectViewTemplate`/`RefreshListBox`,
`CNames`, `CPathHistory`, `CTopIndexMem`, `CMaskGroup`, `CMenuPopup`,
`ItemBitmap`, `ThemeSysColor*`, `CopyToolTipAnswer`, registry helpers
`CreateKey/OpenKey/SetValue/GetValue/ClearKey` over the feature-004 facade)  
**Storage**: Windows registry, `HKCU\Software\Tandem Commander\0.1` — one new
value under `Configuration`, one value + one subkey tree under each of
`Left Panel` / `Right Panel` (see [data-model.md](data-model.md)); no migration  
**Testing**: `saltests` (Debug x64, exit code = failures) for the pure module;
manual GUI matrix in [quickstart.md](quickstart.md) for the strip, switching,
plugins, persistence, keyboard, mouse, themes, languages;
`tools/check_encoding.py --strict` inside every build; `python -m translate.slt --verify`  
**Target Platform**: Windows 11 and newer, x64  
**Project Type**: desktop application — core executable + language DLL
(`src/lang`), shared common library (`src/common`)  
**Performance Goals**: switching between two local tabs of ≤ 10,000 items in
under 1 s (SC-003; one directory read, as typing the path); no background
work for background tabs — thread count and directory watches equal the
two-panel baseline (SC-006, FR-026); strip repaint limited to changed items  
**Constraints**: plugin ABI untouched (interface 106; no `src/plugins/shared/`
diff); with the option off byte-for-byte today's behaviour (FR-003); no
documented shortcut changes meaning (FR-031); UTF-8/WTF-8 house rules,
encoding guard strict `TOTAL: 0`; house style for the strip (constitution VI);
no registry writes on tab changes (Q5); `.slt` refresh before any
`build.cmd full`  
**Scale/Scope**: 1 new common module (+ 2 vcxproj entries), 1 new core module
(`src/paneltabs.*`), 1 rewritten core file pair (`src/tabwnd.*`), edits in
~14 existing core files (`fileswnd.h`, `fileswn0/1/2/9/b.cpp`, `filesbx1.cpp`,
`mainwnd.h`, `mainwnd1/2/3/4.cpp`, `menu4.cpp`, `keyboard.cpp`, `cfgdlg.h`,
`dialogs4.cpp`, `dialogs5.cpp`, `salamand.h`, `resource.rh2`, `texts.rh2`,
`consts.h`), 1 dialog control + ~13 strings × 8 languages, 1 new + 3 edited
help topics, ~40 saltests checks

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Status |
|-----------|------|--------|
| I. Build Reproducibility | Everything is built by `build.cmd` from committed sources; translations regenerated by the documented commands and committed as `.slt`; no manual build steps. The help `.chm` is not built or shipped (feature 019) — pre-existing. | PASS |
| II. Backward Compatibility | With the option off the program is 0.1.7 (FR-003, SC-001). New registry values default when absent; no `THIS_CONFIG_VERSION` bump; legacy per-panel values keep their meaning so an older build reads the configuration unchanged (FR-029). No documented shortcut changes meaning (R11). **Documented exception**: the option defaults to **on**, so every user sees a one-tab strip plus `+` — a user-facing change that is not opt-in. Decided by the product owner (spec Clarification Q1) on the grounds that the single-tab strip alters appearance only, every behaviour is identical (FR-025), and the off switch is one click away. Recorded in *Complexity Tracking* and to be stated in the changelog. | PASS with documented exception |
| III. Incremental Modernization | New logic in new files (`src/common/saltabs.*`, `src/paneltabs.*`) and one rewritten dead file (`src/tabwnd.*`); edits to existing files are confined to hook points (layout, hit test, menus, key dispatch, config save/load, one page); no refactoring of adjacent code. The only touch to an existing class's interface is a one-line `CPathHistory::IsLocked()` accessor. | PASS |
| IV. Windows Platform Commitment | WinAPI only; no new dependency. | PASS |
| V. Plugin Architecture Preservation | Core feature; no `src/plugins/shared/` change; `LAST_VERSION_OF_SALAMANDER` untouched; plugins see only the active tab of each side (FR-022, FR-023). | PASS |
| VI. UI Consistency | The strip is owner-drawn in the house pattern of the Directory Line and the menu bar (theme helpers, `EnvFont`, caption brushes, shared bitmap cache), takes no focus, and adds no manifest/common-controls/process-wide change; the new checkbox is a standard control on an existing `DIALOGEX` page. | PASS |
| Release Documentation | CHANGELOG *Added* entry (tabs on by default, the option, the shortcuts) + version/build bump in `spl_vers.h`, `tandemcommander.iss`, `CLAUDE.md` in the ship-gate task, same change; interface version unchanged. | PASS (planned) |

**Post-design re-check (after Phase 1)**: unchanged — the design introduced
no new project, no new dependency, no plugin-interface change and no
configuration migration; the principle II exception is the one recorded
below.

## Project Structure

### Documentation (this feature)

```text
specs/078-panel-tabs/
├── plan.md              # This file
├── spec.md              # Feature specification (clarified 2026-09-18; FR-031 corrected in planning)
├── analysis.md          # Codebase analysis (four surveys) — input to research
├── research.md          # Phase 0: decisions R1–R22 with rationale + alternatives, corrections
├── data-model.md        # Phase 1: tab record, tab, tab set, option, registry layout, transitions
├── quickstart.md        # Phase 1: build/unit/translation steps + the 14-section GUI matrix
├── contracts/
│   ├── tab-strip-ui.md              # strip geometry, items, colours, mouse, tooltips, context menu
│   ├── commands-and-shortcuts.md    # ids, menu rows, strings, shortcut dispatch, manual pages
│   └── persistence-and-option.md    # option, Appearance page, SetTabsEnabled, registry read/write
├── checklists/requirements.md
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
src/
├── common/
│   ├── saltabs.h             # NEW: CSalTabRecord, SalTabTitleFromLocation, index rules, SalTabRecordClamp
│   └── saltabs.cpp           # NEW: pure logic (compiled into salamand + saltests)
├── paneltabs.h / .cpp        # NEW: CPanelTab, CPanelTabs, CFilesWindow tab operations (SwitchToTab, NewTab,
│                             #      CloseTab, DuplicateTab, MoveTab, CaptureActiveTab, SetTabsEnabled)
├── tabwnd.h / .cpp           # REWRITTEN: CTabWindow — the strip (paint, hit test, mouse, tooltips, menu)
├── fileswnd.h                # CFilesWindow: Tabs member, TabStrip member, ToggleTabStrip, tab methods
├── fileswn0.cpp              # OnSysKeyDown: Ctrl+Shift+T/W/PgUp/PgDn dispatch; OnColorsChanged strip hook
├── fileswn1.cpp              # ctor/dtor: tab set lifetime
├── fileswn2.cpp              # ToggleTabStrip (next to ToggleDirectoryLine)
├── fileswn9.cpp              # ClearPluginFSFromHistory over all tabs' histories
├── fileswnb.cpp              # WM_SIZE/WM_ERASEBKGND with the strip; WM_CREATE/WM_DESTROY; SetFont; LockUI
├── filesbx1.cpp              # WM_MBUTTONDOWN/UP → middle-click-to-new-tab
├── mainwnd.h                 # hit-test enum values; GetDirectoryLineHeight semantics
├── mainwnd1.cpp              # HitTest, OnWmContextMenu (strip early return), GetDirectoryLineHeight, ClearHistory
├── mainwnd2.cpp              # CONFIG_PANELTABS_REG + Save/Load; SavePanelConfig/LoadPanelConfig tab list; start-up SetTabsEnabled
├── mainwnd3.cpp              # WM_COMMAND cases (21 ids); WM_USER_INITMENUPOPUP (hide/enable); WM_SIZE offset;
│                             #   WM_NCACTIVATE repaint; WM_USER_CONFIGURATION post-OK; CM_OPENHOTPATHS anchor
├── mainwnd4.cpp              # ChangePanel/FocusPanel strip repaint; MapClientArea IDH_TABSTRIP
├── drivelst.cpp              # (no change if GetDirectoryLineHeight semantics carry the strip — verify)
├── menu4.cpp                 # Tabs submenu rows in Left/Right
├── keyboard.cpp              # IsSalHotKey reservations
├── salamand.h                # CPathHistory::IsLocked()
├── cfgdlg.h                  # CConfiguration::PanelTabs
├── dialogs4.cpp              # CConfiguration default
├── dialogs5.cpp              # CCfgPageAppearance Transfer/Validate
├── resource.rh2              # CM_*/CML_*/IDC_TABSTRIP/IDH_TABSTRIP ids
├── texts.rh2, lang/texts.rc2 # IDS_MENU_TAB_*, IDS_TABS_*
├── lang/lang.rc, lang/lang.rh    # IDC_PANELTABS on IDD_CFGPAGE_APPEARANCE
├── saltests/saltests.cpp         # TestPanelTabs078()
└── vcxproj/
    ├── salamand.vcxproj          # + common\saltabs.cpp, paneltabs.cpp (tabwnd.cpp already listed)
    └── saltests/saltests.vcxproj # + common\saltabs.cpp

tools/translate/uicontext.py      # _WORDS additions (tab, tabs, close, next, previous, …)
translations/<lang>/salamand.slt  # 8 enabled languages, regenerated by translate.merge
translations/ui-overrides.json    # _feature_078 note + per-language "Tab" pins where needed

help/src/
├── salamand.hhp                  # [ALIAS] IDH_TABSTRIP=hh\salamand\windows_tabstrip.htm
├── salamand.hhc, salamand.hhk    # TOC + index entries
└── hh/salamand/
    ├── windows_tabstrip.htm        # NEW topic (Panel Components chapter)
    ├── windows_panel.htm           # mentions the strip
    ├── shortcuts_keyboard.htm      # four new rows
    └── configuration_appea.htm     # the option + confirmation

CHANGELOG.md, src/plugins/shared/spl_vers.h, setup/tandemcommander.iss, CLAUDE.md   # ship gate
```

**Structure Decision**: single-solution desktop application. The pure rules
go to `src/common/saltabs.*` because `saltests` links `src/common/*.cpp` only
(the feature 071 precedent); the tab model and the switch algorithm live in a
new core module `src/paneltabs.*` so that the 28,000-line `fileswn*.cpp` set
gains only hook lines; the strip reuses the upstream file name `tabwnd.*`
(constitution III: upstream names kept) but replaces its non-linking stub.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Principle II "user-facing behavior changes MUST be opt-in": the tab strip is shown by default (one tab + `+` on every panel) | Product decision (spec Clarification Q1, 2026-09-18): tabs are the release's headline feature and must be discoverable; with a single tab the strip changes appearance only — every command, dialog and plugin behaves identically (FR-025) — and *Show tabs in panels* turns it off in one click, restoring 0.1.7 exactly (FR-003) | Default off (the constitution's letter) was considered and rejected by the product owner: it would hide the feature from every existing user, and the compatibility guarantee the principle protects is preserved by FR-003/FR-025 rather than by the default |

## Phase Outputs

- **Phase 0** — [research.md](research.md): 22 decisions (R1–R22), every
  open question resolved, three corrections applied to earlier documents
  (Ctrl+Shift+Tab is not free; hidden names / Restore Selection are per
  visit; two stale line references).
- **Phase 1** — [data-model.md](data-model.md), [contracts/](contracts/)
  (three contracts), [quickstart.md](quickstart.md) (14 sections).
- **Phase 2** — `/speckit-tasks` generates `tasks.md`. Implementation MUST keep
  a running log (`specs/078-panel-tabs/fix-log.md`) as work lands, per the
  project's working convention, and MUST verify at implementation time the
  two `CPathHistory` behaviours research R4 depends on (`AddPath` not
  duplicating the top path; `ChangeActualPathData` ignoring a non-matching
  path).
