# Tasks: Fluent 2 icons for the plug-ins; Appearance group renamed to Icon style

**Input**: Design documents from `specs/417-fluent-plugin-icons/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/plugin-icon-files.md, quickstart.md
**Tests**: requested by the spec (FR-013, FR-014, SC-001..SC-006): `saltests` checks, `check_iconset.py`, a hidden-desktop probe.

## Phase 1: Setup

- [ ] T001 Keep `specs/417-fluent-plugin-icons/fix-log.md` running (measurement before already recorded; decisions, commands and results from here on)
- [ ] T002 [P] Generator `tools/brand/fluent-icons/gen_fluent_plugins.py`: port of the study's `nastroje\gen_fluent_plugins.py` (package path argument like `gen_fluent.py`, `--help`, output `src/res/iconsets/fluent/plugins/<id>.svg` and `plugins/dark/<id>.svg`, English comments, the 31 ids + `_plugin` / `_pluginfs`, the transparent-key colour assertions, `newline=""`); no study-only data (Czech texts, catalogue `.js`, today's PNGs)
- [ ] T003 Generate the 33 + 33 files into `src/res/iconsets/fluent/plugins/` and `src/res/iconsets/fluent/plugins/dark/` from the pinned package (the study's `vendor\fluent-1.1.344`, sha512 checked against the README); confirm they equal the approved study files byte for byte
- [ ] T004 [P] `tools/brand/fluent-icons/README.md`: section "Plug-in icons (feature 417)" - what the files are, the regeneration command, the table id -> glyph / role / badge, the own drawings (7-Zip tile, RegEdit cube block)
- [ ] T005 [P] Deploy: `src/vcxproj/!populate_build_dir.cmd` copies `..\res\iconsets\fluent\plugins` and `..\res\iconsets\fluent\plugins\dark` (build.cmd's `robocopy /E` already takes them; check)

## Phase 2: Foundational

- [ ] T006 Pure rules in `src/common/saliconset.h`: `SAL_ICONSET_PLUGIN_ID_COUNT` and the id table, `SalIconSetPluginId(dllName)`, `SalIconSetPluginFSIconIsIdentity(id)`, `SAL_ICONSET_NAME_PLUGIN` / `SAL_ICONSET_NAME_PLUGINFS`, `SalIconSetPluginFolder(set, dark)`, `SalIconSetBuildPluginPath(...)` sharing one path builder with `SalIconSetBuildPath` (whole or refused)
- [ ] T007 `saltests` `TestPluginIcons417` in `src/saltests/saltests.cpp`: the id rule (all 31 `<id>\<id>.spl`, upper / mixed case, `<id>\other.spl`, `a\a.dll`, `a\a.spl\x`, absolute and UNC paths, `a/a.spl`, drive, empty, NULL, unknown id, non-ASCII), the FS identity rule, the folder (none in Classic), the path builder (exact fit, one byte short, UTF-8 dir); every id + both defaults present in both folders; the 66 files parsed (shapes, 16 x 16) and rasterized at 16 / 20 / 24 / 32 px with 416's coverage (>= 8 %) and legibility thresholds; no transparent-key colour; the files of the 20 ids enabled in `plugins.cfg` pairwise different (SC-003); called from `main`
- [ ] T008 `tools/brand/fluent-icons/check_iconset.py`: the plug-in folders - expected names from `saliconset.h` (the id table) + the two defaults, both variants, nothing else, colours, the nanosvg tokenizer emulation, the palette contrast of the new tokens; docstring updated
- [ ] T009 Loader in `src/svg.cpp` / `src/svg.h`: the folder kind in `LoadSetSVGImage`; `HICON CreateSetPluginSVGIcon(const char* name, int size)` for the active set (NULL in Classic / on a miss), sharing the rasterization of `CreateSetSVGIcon`
- [ ] T010 Core helpers in `src/salamdr1.cpp` (declared in `src/consts.h`): `CreatePluginSetIcon(dllName, size, gray, fsIcon)` (gray copy by `CIconList::CreateAsCopy(.., TRUE)`), `CreatePluginSetDefaultIcon(fs, size)`, `PluginHasSetIcon(dllName)`; HANDLES-tracked icons

## Phase 3: User Story 1 - plug-in icons in the Fluent 2 style (P1)

**Goal**: every plug-in identity icon site draws the set icon in Fluent 2. **Independent test**: probe rows FLUENT-*, DIRLINE, MANAGER.

- [ ] T011 [US1] `CPlugins::CreateIconsList` in `src/plugins2.cpp`: set icon first, today's icon next, default icon (Fluent default or `IDI_PLUGIN`) last
- [ ] T012 [US1] "Has an icon" checks with `PluginHasSetIcon`: the Plugins-menu submenu item and the plug-in list menus in `src/plugins2.cpp`, View With in `src/fileswn5.cpp`
- [ ] T013 [US1] Change Drive menu / drive bars: `CPlugins::AddItemsToChangeDrvMenu` in `src/plugins2.cpp` (`HIcon`, `HGrayIcon`, default FS icon)
- [ ] T014 [US1] Tab of a plug-in FS in `src/tabwnd.cpp` (set icon, Fluent default `IconPluginFS`); check the cache is cleared on a colour change
- [ ] T015 [US1] Directory line `CFilesWindow::UpdateDriveIcon` in `src/fileswn3.cpp`, drive-list row in `src/drivelst.cpp`, Disconnect dialog in `src/dialogs6.cpp` (both FS-row sites: open and detached file systems, and the `CONNECTION_ICON_PLUGIN` default) (set icon with `fsIcon = TRUE`, then `GetFSIcon`, then the default FS icon)

## Phase 4: User Story 2 - Classic unchanged, switching without a restart (P1)

**Goal**: Classic pixel-identical; set / theme switches rebuild the plug-in icons. **Independent test**: probe rows CLASSIC-EQ-*, SWITCH, SWITCHBACK.

- [ ] T016 [US2] `CMainWindow::OnColorsChanged` in `src/mainwnd1.cpp`: `PluginsBar->CreatePluginButtons()` when the bar exists
- [ ] T017 [US2] Review every site of T011-T015 for Classic: the helper returns NULL, today's code runs unchanged (same calls, same order); no set icon reaches `PluginIcons` / `SaveIconList`

## Phase 5: User Story 3 - "Icon style" (P2)

**Goal**: the group label. **Independent test**: probe row FIT, the page capture.

- [ ] T018 [US3] `src/lang/lang.rc`: `GROUPBOX " &Icon style ",IDC_ICONSET_GROUP` (check the accelerator `I` is unique on `IDD_CFGPAGE_APPEARANCE`)
- [ ] T019 [US3] Two-stage `.slt` refresh of `salamand` for the enabled languages (stop-rules §2.13): changed entry `IDC_ICONSET_GROUP` -> `english_fallback` keys, dry run, merge, read-back, pins in `translations/ui-overrides.json` where needed, `slt --verify`, `build.cmd full`

## Phase 6: User Story 4 - third-party plug-ins, damaged files (P3)

**Goal**: unknown plug-ins keep their icons; a missing / empty file gives today's icon. **Independent test**: probe row OVR, saltests id rule.

- [ ] T020 [US4] Covered by T006 / T007 (id rule) and T009 / T010 (a miss returns NULL); probe row OVR in T021 (an emptied and a removed set file in a copy of the build)

## Phase 7: Polish & evidence

- [ ] T021 Probe `specs/417-fluent-plugin-icons/probe/plugin417_probe.ps1` (helpers of 098 and 416): CLASSIC-EQ-LIGHT/DARK vs `-Before` (Plugins bar, drive bar, the RegEdit FS directory line, the Plugins-manager list: 0 px each), FLUENT-LIGHT/DARK (per Plugins-bar icon cell differs from Classic and has >= 8 colours; drive-bar plug-in buttons differ), DIRLINE (RegEdit FS set icon; Folders FS equals Classic), MANAGER (the Plugins manager list differs in Fluent, equals in Classic), SWITCH / SWITCHBACK (Plugins bar, drive bar and the RegEdit FS directory line equal a fresh start in the target set), CACHE (the plug-ins' stored icon lists after a Fluent 2 session equal those after a Classic session - FR-010), OVR, FIT; registry backed up and restored; NOT DRIVEN rows for menus / hot states / DPI
- [ ] T022 Build `.\build.cmd full`, `saltests`, `check_iconset.py`, `check_encoding.py --strict`, `clang-format --dry-run --Werror` on every changed C++ file (constitution: formatting verified); run the probe (before on the build of `main`, after on this build); record numbers in `fix-log.md`
- [ ] T023 [P] `CHANGELOG.md` entry under `## [Unreleased]` (and the 416 entry's group name), `specs/FEATURE-HISTORY.md` entry, release-checklist lines (menus, hot states, 150 %), `closing-report.md`

## Dependencies & order

- Phase 1 (T002-T005) -> Phase 2 (T006 before T007 / T008 / T009; T009 before T010) -> US1 (T011-T015, need T010)
  -> US2 (T016, T017) -> US3 (T018 -> T019) -> US4 (T020) -> Polish (T021 -> T022 -> T023).
- US3 is independent of US1 / US2 (a dialog label) and may be done any time after Phase 1.

## Parallel opportunities

- T002, T004, T005 touch different files; T007 and T008 can be written side by side once T006 exists.
- T011-T015 touch different files but share the helper of T010.

## Implementation strategy

MVP = Phase 1-3 (the plug-in icons in Fluent 2) with T016 (rebuild); then the label and its translations, then the
probe and the closing records. One feature, one branch; commit per phase.
