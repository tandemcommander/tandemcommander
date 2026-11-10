# Tasks: Square panel tabs as the new default; rounded tabs kept as an Appearance option

**Input**: `specs/423-square-panel-tabs/` (spec.md, plan.md, research.md, data-model.md, contracts/tab-style.md, quickstart.md)
**Tests**: required by the project rules (pure rules in `saltests`, GUI pixels by a hidden-desktop probe).

## Phase 1: Setup

- [X] T001 Start `specs/423-square-panel-tabs/fix-log.md` with the measurement at 75efd1ac (tabs413_probe THEME, `probe/result_before_tabs413.txt`, `probe/captures_before/`)

## Phase 2: Foundational (pure rules)

- [X] T002 Add `SALTAB_STYLE_SQUARE` / `SALTAB_STYLE_ROUNDED` and `SalTabStyleFromStored(BOOL read, unsigned long value)` to `src/common/saltabs.h` / `src/common/saltabs.cpp` (contract *Stored value*)
- [X] T003 Change the Light `DimText` mix from 0.38 to 0.20 in `SalTabStripColorsGet` (`src/common/saltabs.cpp`), comment the 423 reason in `src/common/saltabs.h`
- [X] T004 `TestTabStrip423` in `src/saltests/saltests.cpp`: the style mapping (missing, 0, 1, 7, wrong type), the Light DimText 2C2C2C >= 7:1 on DEDEDE and lighter than the text, Dark / High Contrast unchanged; update the 404 expectation `DimText == RGB(84, 84, 84)` to the new value with a note; negative control: old 0.38 fails the 7:1 check

## Phase 3: User Story 1 - Square tabs by default (P1)

**Independent test**: no stored value -> the probe's DEFAULT rows show rectangular active tabs.

- [X] T005 [US1] `Configuration.PanelTabStyle` in `src/cfgdlg.h`, default `SALTAB_STYLE_SQUARE` in the `CConfiguration` constructor (`src/dialogs4.cpp`)
- [X] T006 [US1] `CONFIG_PANELTABSTYLE_REG = "Panel Tab Style"`, `ReadPanelTabStyle(HKEY)` (quiet read, missing / wrong type = Square, number kept) and `GetActiveTabStyle()` in `src/mainwnd2.cpp`, declarations in `src/consts.h`; read in `LoadConfig`, write in `SaveConfig`
- [X] T007 [US1] Square branch in `CTabWindow::PaintTabBack` (`src/tabwnd.cpp`): active tab and hover as the rectangle `{r.left, TextTop(), r.right + 1, Height}`; Rounded keeps the 404 paths; comment of `TABSTRIP_LEFT` / `TABSTRIP_RADIUS` updated

## Phase 4: User Story 2 - Rounded as a choice (P1)

**Independent test**: the probe's PAGE rows (Rounded + OK repaints, stored 1; Square + OK back to 0) and ROUNDED rows.

- [X] T008 [US2] `src/lang/lang.rh`: `IDC_TABSTYLE_GROUP`, `IDC_TABSTYLE_SQUARE`, `IDC_TABSTYLE_ROUNDED` (free ids)
- [X] T009 [US2] `src/lang/lang.rc` `IDD_CFGPAGE_APPEARANCE`: Thumbnails beside Panel Font (font edit narrowed), Information Line and Icon style moved up, the *Tab style* group (two radios side by side) directly below Icon style, all inside 299 x 231 du; unique accelerators
- [X] T010 [US2] `CCfgPageAppearance::Transfer` (`src/dialogs5.cpp`): the two radio buttons; written only on a change (416's rule)
- [X] T011 [US2] `CCfgRefreshState` (`src/mainwnd.h`, `src/mainwnd3.cpp`): capture `PanelTabStyle`; on a change of the mapped style repaint both panels' strips (`UpdateTabStrip`)

## Phase 5: User Story 3 - Light legibility (P2)

- [X] T012 [US3] Probe row TITLE: Light inactive title >= 7:1 and lighter than the active title; Dark inactive title colour equals the before capture (`probe/tabs423_probe.ps1`)

## Phase 6: Probes, translations, polish

- [X] T013 Write `specs/423-square-panel-tabs/probe/tabs423_probe.ps1` (style 241/413: registry backup / restore, hidden desktop): rows DEFAULT (Light + Dark, both panels), UNKNOWN (7 kept after Save Configuration), ROUNDED (corner pixels as before), HOVER (square hover rectangle), PAGE (default radio, OK applies both ways, value stored), TITLE (T012), LAYOUT (page controls inside the page, no overlaps, all on screen); run it -> `probe/result_after.txt`
- [X] T014 Regression: `Panel Tab Style` = 1 in the `Prep-Registry` of `specs/404-panel-tabs-rounded-look/probe/tabs404_probe.ps1` and `specs/413-tab-drag-first-place/probe/tabs413_probe.ps1` (they test the rounded look); run both, compare with their last results
- [X] T015 Translations (stop-rules 2.13, module `salamand`): export, dry run, merge with `--formality prefer_more`, read back the three new texts in 8 languages, pin where needed, `slt --verify`, `build.cmd full`; record in fix-log *Translations*
- [X] T016 LAYOUT in every enabled language: the probe's PAGE / LAYOUT rows with each language (or a check of the imported dialogs) - no clipped radio labels
- [X] T017 Encoding guard `python tools/check_encoding.py --strict`, `build.cmd full`, `saltests`
- [X] T018 Manual (help/) only if a page describes the Appearance page; CHANGELOG entry under `## [Unreleased]`

## Dependencies

T001 -> T002..T004 -> US1 (T005..T007) -> US2 (T008..T011) -> US3 (T012 within T013) -> T013..T018.
US2 needs US1's value and paint branch; US3 needs only T003.

## Parallel opportunities

T002/T003 (same file, sequential); T008 and T005 [different files] can go together; the probe (T013) can be written while the build runs.

## Implementation strategy

MVP = Phases 2-3 (square default). Then the page (US2), then translations and the probes.
