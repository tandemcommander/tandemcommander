# Fix log - 423 square panel tabs

Backlog item `square-panel-tabs-as-the-new-default-rounded-tabs-kept-as-an`, plus the maintainer's
request given with the run (2026-11-10): improve the legibility of the tabs in the Light theme.

## Measurement before (75efd1ac)

- `.\build.cmd` (Debug x64) at 75efd1ac.
- `tools\run_on_hidden_desktop.ps1` + `specs\413-tab-drag-first-place\probe\tabs413_probe.ps1 -Only THEME`
  -> 14 PASS / 0 FAIL / 1 NOT DRIVEN (`probe/result_before_tabs413.txt`, captures in
  `probe/captures_before/`).
- Default theme: strip DEDEDE (29 px), active tab 99B4D1 (active panel) / BFCDDB (inactive panel)
  on rows 3-28, drawn as the 404 path: rounded top corners and outward feet (visible in
  `captures_before/theme_default_main.png`). No tab-style setting exists (no configuration value,
  nothing on the Appearance page).
- Inactive titles (and the +) in Light: 545454 on DEDEDE = 5.63:1 (`SalTabMix(text, StripBk, 0.38)`);
  the active title 000000 on 99B4D1 = 9.80:1. Dark: B3B3B3 inactive titles on 242424.

## Analyze (speckit-analyze, one run)

0 CRITICAL, 0 HIGH. Accepted: C1 (MEDIUM) the settings-import path has no probe row - it runs the
same `CCfgRefreshState` refresh as OK, which the PAGE rows drive; C2 (LOW) the dragged tab's shape
has no own row - `PaintTabBack` is the same branch as the hover row; F1 (LOW) wording of SC-001 vs
the contract - the contract is authoritative.

## Decisions

- Square hover = the tab's whole box (top of the content band to the strip's bottom) in HoverBk
  (research R1).
- Light DimText mix 0.38 -> 0.20 (2C2C2C, 10.38:1) (research R6).
- Page room: Thumbnails beside Panel Font, the page keeps 299 x 231 du (research R5).

## Work

- Pure rules (`src/common/saltabs.*`): `SALTAB_STYLE_SQUARE` 0 / `SALTAB_STYLE_ROUNDED` 1,
  `SalTabStyleFromStored` (only a read 1 is Rounded), `SALTAB_DIMTEXT_LIGHT` 0.20 /
  `SALTAB_DIMTEXT_DARK` 0.30 in `SalTabStripColorsGet`.
- `saltests`: `TestTabStrip423` (mapping incl. not read / 2 / 7 / 0xFFFFFFFF; Light DimText 2C2C2C >= 7:1
  and lighter than the text; a custom Light scheme keeps the relation; Dark / both High Contrast schemes
  unchanged; negative control in the test: 404's 0.38 gives < 7:1). The 404 expectation
  `DimText == RGB(84, 84, 84)` became `RGB(44, 44, 44)`. Result: `saltests: 287255 checks, 0 failed`.
- Configuration: `Configuration.PanelTabStyle` (default Square), `CONFIG_PANELTABSTYLE_REG = "Panel Tab
  Style"`, `ReadPanelTabStyle` (quiet read in `LoadConfig`, number kept), written in `SaveConfig`,
  `GetActiveTabStyle()`; `CCfgRefreshState` captures it and `RefreshAfterConfiguration` repaints both
  strips on a change (`UpdateTabStrip`) - also after a settings import (same refresh).
- Paint: `CTabWindow::PaintTabBack` Square branch - `TabFillSolid` of `{r.left, TextTop(), r.right + 1,
  Height}` in `CapBk` (active) or `HoverBk` (hover / dragged); Rounded = 404's paths unchanged.
- Page: `IDC_TABSTYLE_GROUP` / `_SQUARE` / `_ROUNDED` (6302-6304, `_APS_NEXT_CONTROL_VALUE` 6305);
  Thumbnails beside Panel Font (font edit 224 -> 106 DLU), Information Line unchanged, Icon style 36 DLU
  up, Tab style (radios side by side) at y 198..225 - the page keeps 299 x 231 DLU (the tree dialog is
  sized to its largest page). Transfer: written only on a change (416's rule).
- Process slip, recorded: a helper script that applied the core edits was run twice by mistake and doubled
  every insertion; the six files were restored from HEAD (`git checkout HEAD -- ...`, nothing else was in
  them) and the script applied once (grep counts checked).

## Findings fixed on the way

- The Thumbnails labels were 19 / 22 DLU wide (English layout, every language refitted to it): Czech
  "Velikost:" 40 px in a 29-px label, also de / nl / hu / ro / sk / es clipped (probe FIT before the
  refresh: 7 languages CLIPPED). Moving the group gave them 34 / 33 DLU: FIT after - all 9 PASS
  (Czech 40/51 px). Severity 2 (cosmetic), fixed here (stop-rules rule 11).
- French "éléments d'images (pixels)" (107 DLU of its own before the refresh) no longer fits the new
  33-DLU label: pinned to "pixels" (`#pixels`, the only such row in salamand).

## Translations (stop-rules 2.13, module salamand)

- Entries (step 0): new dialog controls 6302 " Tab st&yle ", 6303 "S&quare", 6304 "Rou&nded"; moved /
  resized (English text unchanged): 1151, 612, 1153, 1154, 1155, 620, 6291-6295. No changed English text.
- `build_langs.cmd --export-templates --module salamand`; dry run: 3 unique gaps, ~27 chars per
  language; merge `--formality prefer_more --budget 2432`: 192 DeepL characters, 0 validation failures,
  duplicate accelerators 148 -> 147 (the module's, none on this page).
- Read back in 8 languages; pins (`ui-overrides.json`, `_feature_423`): cs " St&yl karet " (the corpus's
  'karty', not 'záložek') and "&Hranaté"; sk "&Hranaté"; de "Ec&kig" (not 'Quadratisch'); fr "Ca&rrés"
  (agrees with 'onglets') and "#pixels"; hu " Lapok &formája " (the corpus's 'lap', not 'fül'; every
  letter of 'Lapstílus' is taken on the page). Kept: nl "&Tabbladstijl / &Vierkant / A&fgerond", ro
  "&Stilul filelor / P&ătrat / Rotu&njit", es "Es&tilo de las pestañas / &Cuadrado / Redonde&ado", de
  " &Registerkartenstil " / "Abgeru&ndet", fr "St&yle des onglets" / "Arro&ndis".
- Merge again (pins as human), `translate.slt --verify`: 298 files, round-trip byte-exact.
- 14 rows changed per language (11 moved + 3 new); no other layout drift.
- `build.cmd full`: BUILD SUCCEEDED (21 modules x 8 languages).

## Checks

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `build.cmd full`: BUILD SUCCEEDED (the warnings C4018 in salamdr2.cpp and C4244 in zip.cpp are
  untouched code).
- `saltests`: 287,255 checks, 0 failed.
- `tabs423_probe` (`probe/result_after.txt`): 47 PASS / 0 FAIL / 2 NOT DRIVEN. First try (`try1`, before
  the refresh): 36 / 11 - probe faults fixed: the rounded-hover sample point lay below the pill; the
  overlap check counted the page's check boxes, which touch by one pixel (DLU rounding, as before 423);
  FIT read the not yet refreshed `.slt`.
- Regression with "Panel Tab Style" = 1 added to their registry preparation:
  - `tabs404_probe` (`probe/result_tabs404.txt`): first 19 / 10 / 1 - all 10 LOOK rows failed by the E:\
    tab's drive icon only (77 px Light, 47 px Dark, x 639..652): Fluent 2 since 416 vs the mockup's shell
    icon - the probe had not run since 416, not a 423 change (Dark is untouched by 423 and failed the
    same). With "Toolbar Icon Set" = 1 too (the set the evidence was made with): 29 / 0 / 1 = its last
    recorded result. The darker Light titles stay within its edge tolerance (max 58 <= 64).
  - `tabs413_probe` (`probe/result_tabs413.txt`): 22 / 0 / 1 (as recorded by 413).
  - `tabs405_probe` (`probe/result_tabs405.txt`): 7 / 0 / 1.
- Registry: every probe restored the key identically. Between the end of the `tabs404` run (key hash
  F8CA10C2...) and the start of the `tabs413` run (1A2CB153...) the key changed outside any probe (no
  probe was running; nothing of this run writes it); the current key equals 1A2CB153.... Noted for the
  maintainer; not caused by a probe (each one deletes the key and imports its backup, verified by hash).
