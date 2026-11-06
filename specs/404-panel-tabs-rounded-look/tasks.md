# Tasks: Panel tabs - taller rounded look with icons and Chrome-like mouse handling

**Input**: `specs/404-panel-tabs-rounded-look/` (spec, plan, research, data-model, contracts/tab-strip-f.md, quickstart)
**Tests**: requested by the spec (FR-019 probe, FR-020 saltests).

Order of work inside the feature (item Notes): look first, then icons, then mouse handling and commands.

## Phase 1: Setup

- [ ] T001 Start `specs/404-panel-tabs-rounded-look/fix-log.md` (measurement at f2d2ca59, decisions of the spec's Clarifications)
- [ ] T002 Write the probe `specs/404-panel-tabs-rounded-look/probe/tabs404_probe.ps1` (style of `specs/312-tabs-browser-keys/probe/tabs312_probe.ps1`; registry backup/restore; LOOK rows: six tabs from the registry, left strip sized to 786 px, `WM_NCACTIVATE`, `PrintWindow(PW_CLIENTONLY)` of the strip, compare with `probe/evidence/*.png` by the spec's edge rule; MOUSE and MENU rows by posted messages / commands)
- [ ] T003 Run the probe on the unchanged build: record the before state (LOOK vs `current_*` = control, LOOK vs `variantF_*` FAIL, close-on-press FAIL, menu commands FAIL) in `fix-log.md`

## Phase 2: Foundational (pure rules)

- [ ] T004 Add to `src/common/saltabs.h` / `saltabs.cpp`: `SalTabMix`, `SalTabStripColors`, `SalTabStripHeight`, `SalTabStripWidths`, `SalTabLocationKind` (+ kind constants), `SalTabDragSlot`, `SalTabDragOrder`, `SalTabEaseOut`, `SalTabMenuCanMoveToOther`, `SalTabMenuCanNewAsOther`
- [ ] T005 Add `TestTabStrip404()` checks in `src/saltests/saltests.cpp` (mixes against mockup values, heights 29 / scaled, widths, slots and orders incl. cancel, ease, menu rules, kinds) and call it from main
- [ ] T006 Add `IsThemeHighContrast()` to `src/themes.h` / `src/themes.cpp`

## Phase 3: User Story 1 - variant F look (P1)

**Goal**: the strip matches `variantF_*.png`. **Independent test**: probe LOOK rows.

- [ ] T007 [US1] `src/tabwnd.h` / `src/tabwnd.cpp`: AA painter (nanosvg rasterizer + strip-sized DIB, `FillPathAA`, `StrokePathAA`), new metrics in `GetNeededHeight`, `Layout`, `GetTabRect`, `GetCloseRect`; handle `WM_PRINTCLIENT`
- [ ] T008 [US1] `src/tabwnd.cpp`: new `Paint` / `PaintTab` / `PaintPlus` per the mockup's `PaintNew` (strip bg, hover pills, active outline with feet, separators, title, X with hover circle, + with hover circle), High Contrast fallbacks
- [ ] T009 [US1] Build, run LOOK rows, iterate until all 10 images pass; record in `fix-log.md`

## Phase 4: User Story 2 - icons (P1)

**Goal**: each tab shows its location icon. **Independent test**: LOOK rows (folder and drive icons) + an archive / plug-in kind check in saltests.

- [ ] T010 [US2] `src/paneltabs.h` / `src/paneltabs.cpp`: `IconKind`, `IconDriveType`, `IconPluginIndex` session fields, set in `CaptureActiveTab` and after a successful `SwitchToTab`; `CFilesWindow::GetTabIconKind(CPanelTab*)` derives once for restored tabs
- [ ] T011 [US2] `src/tabwnd.cpp`: icon kind read from the tab (derived outside painting: at capture, or once per restored tab - the only call is `GetDriveType` of a letter root, no I/O on the location; SC-005); HICON cache (folder, archive, drive per type, plug-in FS per plug-in, generic plug-in FS), drawn at x + 10; dropped on colour / font change and destroyed with the strip

## Phase 5: User Story 3 - live drag (P2)

**Goal**: live, animated reorder. **Independent test**: MOUSE drag rows.

- [ ] T012 [US3] `src/tabwnd.h` / `src/tabwnd.cpp`: drag state, grab offset, clamped drawn x, `SalTabDragSlot`, neighbour offsets with a 16-ms timer and 150-ms ease-out, glide on release + one `MoveTab`, cancel glide on Esc (timer, `GetAsyncKeyState`) / `WM_CAPTURECHANGED` / `WM_CANCELMODE` / right button, `SPI_GETCLIENTAREAANIMATION` off -> jump; remove `PaintInsertMark`

## Phase 6: User Story 4 - close on release (P2)

- [ ] T013 [US4] `src/tabwnd.cpp`: `PressedClose` / `PressedCloseInside`; down on X captures and paints the pressed circle, no switch, no drag; up over the same X closes; capture loss forgets

## Phase 7: User Story 5 - Move to Other Panel, New Tab as Other Panel (P2)

- [ ] T014 [US5] `src/resource.rh2`: `CM_LEFT_MOVETABTOOTHER` 2885, `CM_RIGHT_MOVETABTOOTHER` 2886, `CM_LEFT_NEWTABASOTHER` 2887, `CM_RIGHT_NEWTABASOTHER` 2888
- [ ] T015 [US5] `src/texts.rh2` 14192 / 14193 and `src/lang/texts.rc2`: "&Move to Other Panel", "New Tab as Other &Panel"
- [ ] T016 [US5] `src/paneltabs.cpp` / `src/fileswnd.h`: `CFilesWindow::MoveTabToOtherPanel(int index)`, `CFilesWindow::NewTabAsOtherPanel()`; `CMainWindow::HandleTabCommand` cases; `src/mainwnd3.cpp` WM_COMMAND cases
- [ ] T017 [US5] `src/tabwnd.cpp`: the two menu items (ids 7, 8) with enabling rules; `TabStripMenu` comment updated

## Phase 8: Polish & cross-cutting

- [ ] T018 Translations: two-stage `.slt` refresh of module `salamand` (stop-rules §2.13) with pins for de / fr / nl / es; `fix-log.md` *Translations*
- [ ] T019 Encoding guard `python tools/check_encoding.py --strict` -> TOTAL: 0
- [ ] T020 `.\build.cmd full` -> BUILD SUCCEEDED; saltests 0 failed
- [ ] T021 Probe after: all rows PASS or NOT DRIVEN; `tabs312_probe` 33 PASS
- [ ] T022 Release checklist lines for the person checks (real mouse hover/drag feel, Esc during drag, Dark on screen, 125/150 % DPI, High Contrast)
- [ ] T023 Manual (`help/`): update the panel tabs page if it describes the strip's mouse handling or menu

## Dependencies

Phase 1 -> Phase 2 -> US1 -> US2 -> US3 / US4 (same file, sequential) -> US5 -> Polish. US5's
paneltabs part (T014-T016) can go in parallel with US3/US4 (different files).

## Implementation Strategy

MVP = US1 (the look) - the maintainer's main point; then icons, then the mouse and menus, as the
item orders them. Everything closes in this one feature.
