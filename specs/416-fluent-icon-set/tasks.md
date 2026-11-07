# Tasks: Fluent toolbar icon set by default, switchable to Classic in Appearance

**Input**: Design documents from `specs/416-fluent-icon-set/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/icon-set-files.md, quickstart.md
**Tests**: requested by the spec (FR-015, SC-001..SC-006): `saltests` checks and a hidden-desktop probe.

## Phase 1: Setup

- [X] T001 Start `specs/416-fluent-icon-set/fix-log.md` with the step-3 measurement (commands and results)
- [X] T002 Capture the *before* evidence: the probe `specs/416-fluent-icon-set/probe/iconset416_probe.ps1` with `-Label before` on the build of `main` (Classic toolbar / drive bar / Appearance captures, empty-override row), results in `specs/416-fluent-icon-set/probe/result_before.txt`
- [X] T003 [P] Bring the study into the repository: `src/res/iconsets/fluent/*.svg` (95), `src/res/iconsets/fluent/dark/*.svg` (95), `src/res/iconsets/fluent/LICENSE-fluent.txt`; generator `tools/brand/fluent-icons/gen_fluent.py` (output path adapted to the repository) with `tools/brand/fluent-icons/README.md` (npm `@fluentui/svg-icons` 1.1.344, sha512, how to fetch and regenerate, the mapping, the palettes)
- [X] T004 [P] Data check `tools/brand/fluent-icons/check_iconset.py`: every name of `src/common/saliconset.h` and of the `SVGName` column of `src/toolbar4.cpp` (Fluent table) exists in both folders, no mask-key colour (`#FF00FF`, `#F0F0F0`, `#2D2D2D`), nanosvg tokenizer emulation finds 0 problems; answers `--help`
- [X] T005 Deploy the set: `src/vcxproj/!populate_build_dir.cmd` copies `..\res\iconsets\fluent` (with the licence) and `..\res\iconsets\fluent\dark`

## Phase 2: Foundational

- [X] T006 Pure rules header `src/common/saliconset.h`: set ids, `SalIconSetFromStored`, `SalIconSetFolder`, `SalIconSetBuildPath` (refuses a path that does not fit or a bad name), `SalIconSetFluentButtonName`, `SalIconSetFluentDriveName`, `SalIconSetChooseSource`, the preview TBBE list
- [X] T007 `saltests` checks `TestIconSet416` in `src/saltests/saltests.cpp`: the rules of T006, plus offline rasterization of every file of both Fluent folders at 16/20/24/32 px with the vendored nanosvg (shapes > 0, coverage, dominant colour contrast >= 3:1 against the light / dark toolbar background, the hot / pressed backgrounds and `COLOR_HIGHLIGHT`; outline icons keep their halo / paper visible on the highlight)
- [X] T008 Setting: `Configuration.ToolbarIconSet` in `src/cfgdlg.h`, default in `src/dialogs4.cpp`, `CONFIG_TOOLBARICONSET_REG` "Toolbar Icon Set" in `src/mainwnd2.cpp` (load + save) and `src/consts.h`, early read with Theme Mode in `src/salamdr1.cpp`
- [X] T009 Set-aware loader in `src/svg.cpp` / `src/svg.h`: `LoadSetSVGImage` (parse first, dark only when usable, NULL check), `RenderSVGImage` returns BOOL and fills the cell only for a usable image, `CreateSetSVGIcon(name, set, size)` (32-bpp icon, un-premultiplied)

## Phase 3: User Story 1 - Fluent 2 out of the box (P1)

**Goal**: every icon site shows Fluent 2 with no stored value. **Independent test**: probe rows DEFAULT-* (no value -> 85 cells non-empty, the 9 system-folder cells not the shell icons, drive bar and `..` Fluent).

- [X] T010 [US1] `src/toolbar4.cpp`: `GetSVGIconsMainToolbar(set)` with the Fluent overrides; `CreateToolbarBitmaps(..., iconSet)` skips the shell icon of a button whose Fluent SVG rendered (fallback: the shell icon); callers in `src/salamdr1.cpp`, `src/consts.h`
- [X] T011 [US1] Drive icons for Fluent: `GetDriveIcon` (`src/salamdr1.cpp`), removable tab icon (`src/tabwnd.cpp`), Documents and Network entries (`src/drivelst.cpp`), all with the Classic icon as fallback
- [X] T012 [US1] `..` symbol from `UpDir` at the three icon sizes and the Fluent chevron `IDV_ARROW_DOWN_FLUENT` (`src/res/down_fluent.svg`, `src/resource.rh2`, `src/salamand.rc2`, GRAYTEXT disabled in `CSVGSprite`) in `src/salamdr1.cpp` / `src/svg.cpp` / `src/svg.h`
- [X] T013 [US1] Configuration-list toolbar names per set in `src/gui.cpp` (`CToolbarHeader`)
- [X] T014 [US1] `doc/third_party.txt`: Microsoft Fluent UI System Icons notice (MIT, `doc/license/license_mit.txt`, deployed copy in `iconsets\fluent\LICENSE-fluent.txt`)

## Phase 4: User Story 2 - Classic in Configuration > Appearance (P1)

**Goal**: choose the set with previews, applied on OK, persisted. **Independent test**: probe rows SWITCH-*, CLASSIC-EQ (Classic captures equal the before captures), PAGE-*, FIT-*.

- [X] T015 [US2] Dialog `IDD_CFGPAGE_APPEARANCE` in `src/lang/lang.rc` (+ ids in `src/lang/lang.rh`): group "Toolbar icons", radios "&Fluent 2" / "C&lassic", two owner-drawn preview statics
- [X] T016 [US2] `CCfgPageAppearance` in `src/dialogs5.cpp` / `src/cfgdlg.h`: build both sets' preview bitmaps with `CreateToolbarBitmaps` (active theme), `WM_DRAWITEM`, `Transfer` of the radios, release on destroy
- [X] T017 [US2] Apply on OK and after a settings import: `CCfgRefreshState` + `RefreshAfterConfiguration` in `src/mainwnd3.cpp` / `src/mainwnd.h` call `ColorsChanged(TRUE, FALSE, TRUE)` when the set changed
- [X] T018 [US2] Translations: the two-stage `.slt` refresh of module `salamand` for every enabled language (stop-rules §2.13), pins as needed in `translations/ui-overrides.json`, `slt --verify`, record in `fix-log.md`

## Phase 5: User Story 3 - a broken dark icon never blanks a button (P2)

**Goal**: real fallback of the override contract. **Independent test**: probe row OVERRIDE-EMPTY (an empty and an unparseable dark override of one Fluent icon -> the standard icon, adapted) and the T007 checks of `SalIconSetChooseSource`.

- [X] T019 [US3] Probe rows with a temporary override in the deployed `iconsets\fluent\dark\` of a copy of the build tree (the repository's files are never touched), before (main, Classic `toolbars\dark\`) / after
- [X] T020 [US3] Update `src/res/toolbars/dark/README.txt` and the 029 contract reference to name the new contract `specs/416-fluent-icon-set/contracts/icon-set-files.md`

## Phase 6: Polish & cross-cutting

- [X] T021 Write the probe `specs/416-fluent-icon-set/probe/iconset416_probe.ps1` (all rows above; registry backup / restore / verify; captures of toolbar, drive bar, file list, a menu and the Appearance page in both sets x both themes)
- [X] T022 Encoding guard `python tools/check_encoding.py --strict`, `.\build.cmd full`, `saltests`, `python tools/test_bin_help.py` if a `bin/` script changed, probe `-Label after`
- [X] T023 Confirm `PRIVACY.md` is not affected and record why in `fix-log.md`
- [X] T024 Release-checklist lines (visual check of both sets on a real screen, both themes, 125/150/200 %, the menu highlight with a real mouse)
- [X] T025 CHANGELOG entry, FEATURE-HISTORY entry, closing report

## Dependencies

- T003 -> T004, T005, T007; T006 -> T007..T013; T009 -> T010..T013; T008 -> T010, T016, T017; T015 -> T016 -> T018; T021 needs T010..T017.
- US1 and US2 share T006/T008/T009; US3 is in T009 and only adds probe rows.

## Parallel opportunities

- T003 / T004 / T006 (different files); T011 / T012 / T013 / T014 after T009; T015 with T011..T013.

## Implementation strategy

MVP = Phases 1-3 (Fluent 2 by default); then US2 (switch + previews), US3 rows, polish. All in one feature.
