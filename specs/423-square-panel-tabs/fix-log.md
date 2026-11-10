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

- Square hover = the rounded pill's box with square corners, in HoverBk (research R1; full height until
  review 2, full width until the maintainer's follow-up of 2026-11-10).
- Light DimText mix 0.38 -> 0.20 (2C2C2C, 10.38:1) (research R6).
- Page room: Icon style up, Tab style below it with Thumbnails beside, the page keeps 299 x 231 du (research R5, as changed by review 1).

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
  first Thumbnails beside Panel Font (font edit 224 -> 106 DLU; review 1 S1 rejected it, see *Review*),
  now: Panel Font and Information Line unchanged, Icon style 36 DLU up (y 153..193), bottom row y 198..225
  Tab style (1..140, radios side by side) and Thumbnails (144..296, WS_GROUP, labels 40 / 62 DLU) - the
  page keeps 299 x 231 DLU (the tree dialog is sized to its largest page); template order = tab order
  Font, Information Line, Icon style, Tab style, Thumbnails. Transfer: written only on a change (416's rule).
- Process slip, recorded: a helper script that applied the core edits was run twice by mistake and doubled
  every insertion; the six files were restored from HEAD (`git checkout HEAD -- ...`, nothing else was in
  them) and the script applied once (grep counts checked).

## Findings fixed on the way

- The Thumbnails labels were 19 / 22 DLU wide (English layout, every language refitted to it): Czech
  "Velikost:" 40 px in a 29-px label, also de / nl / hu / ro / sk / es clipped (probe FIT before the
  refresh: 7 languages CLIPPED). Moving the group gave them 40 / 62 DLU: FIT after - all 9 PASS
  (Czech 40/60 px). Severity 2 (cosmetic), fixed here (stop-rules rule 11).
- French "éléments d'images (pixels)" (107 DLU of its own before the refresh) no longer fits the new
  62-DLU label: pinned to "pixels" (`#pixels`, the only such row in salamand).

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
  The window the probes open is now 1650x1078 (was 1694x1110): the stored main-window size is part of
  the change.

## Review

### Review 1 (refute-first agent, commit 5d9027d9) - no MUST

It re-ran saltests (287,255 / 0) and the probe from a copy (45 PASS / 2 FAIL - its S2), and ran a negative
control: the "want square" check applied to the before capture fails (top corners DEDEDE, feet in the tab
colour). It confirmed default Square; missing / REG_SZ / 7 / 0xFFFFFFFF = Square; written only on a
change; Cancel changes nothing; both panels repaint; `UpdateTabStrip` is a no-op with tabs off; Dark /
High Contrast titles unchanged; no duplicate accelerator on the page in 8 languages; `PRIVACY.md` not
affected. Its note that a settings import "reads only Altap / Open Salamander keys" means the import
cannot bring this value; the refresh path is shared anyway.

- **S1 (fixed)** the Panel Font field (612), narrowed to 106 DLU, cut "%d pt. %s (default font)" in 7 of 8
  languages (hu 213 px of ~148). Fix: Panel Font keeps its 224 DLU; Icon style moved up into the old
  Thumbnails row and the bottom row holds Tab style + Thumbnails. Probe FIT gained a row per language for
  612 (both the default and a custom-font form, "10 pt. Microsoft Sans Serif (...)"): widest es 252 / 328
  px, all 9 PASS.
- **S2 (fixed)** ROUNDED SAME-AS-BEFORE used the current window's tab position in the before capture; with
  another stored window size the right panel's tab moved (1002 -> 981) and the row failed. Fix: each
  capture's tab is located by its own pixels (`FindTab`: the topmost row with a 20-px run of the fill, the
  left column 8 rows below), the boxes are compared at each capture's own position: 0 / 0 px in all four
  rows, with the window at 1650x1078 against the before capture's 1694x1110.
- N1 (fixed) tab order: the Thumbnails controls now come last in the template (after Tab style), the
  order of the layout; the Thumbnails group box has WS_GROUP so the Tab style radio group ends at it.
- N2 (fixed) the 413 comment above `TestTabStrip423` moved back to `TestTabStrip413`.
- N3 (fixed) help: "as in version 0.3.0" -> "the shape of earlier versions".
- N4 the CHANGELOG entry: no `## [Unreleased]` section (the tree is prepared for 0.3.0) - the entry goes
  into `closing-report.md` (SKILL.md step 8.5).
- N5 accepted (analyze C1): no probe row for the settings import; it shares `CCfgRefreshState`.
- N6 accepted: `tabs404_probe` now pins the Classic icon set for its LOOK rows, because its evidence
  predates 416's Fluent 2 drive icon; recorded above. Refreshing the 404 evidence images to Fluent 2 is
  probe upkeep, not this feature's.

After the fixes: `build.cmd full` BUILD SUCCEEDED; merge 0 gaps (geometry only), `slt --verify`
byte-exact, 12 rows per language differ from `main` (5 Icon style, 4 Thumbnails, 3 new); saltests
287,255 / 0; encoding guard 0; `tabs423_probe` **56 PASS / 0 FAIL / 2 NOT DRIVEN**
(`probe/result_after.txt`).

### Review 2 (refute-first agent, commit 211833b6) - no MUST

It re-ran saltests (287,255 / 0), the encoding guard (0) and the probe from a copy (56 / 0 / 2, the same as
`result_after.txt`), and confirmed the review 1 fixes: S1 (IDE_PANELFONT back to 224 DLU, FONTFIELD rows
pass), S2 (SAME-AS-BEFORE 0 / 0 px with a 1650x1078 window against the 1694x1110 capture), N1 (tab order;
the Square radio starts its own group, the Thumbnails box ends it - Rounded cannot uncheck an Icon style
radio). DIALOG 595 has the template's row order in all 8 languages, no duplicate accelerator on the page,
only the 12 layout rows differ from `main`. The settings import never writes the value. In the four High
Contrast themes the highlight and caption colours always differ.

- **S1 (fixed)** in the inactive panel a square hovered tab read as a second active tab: the full-height
  hover (into the directory line) was CECECE next to the active tab's BFCDDB (Light, distance 15) and
  383838 next to 454545 (Dark, 13; its title F0F0F0 even brighter than the active one), below 413's
  24 - in Rounded the pill's shape separates them. The probe hovered only in the active panel. Fix: the
  square hover ends 3 px above the strip's bottom (`Height - Scaled(3)`, where the pill ends), so only
  the active tab joins the directory line. New probe row HOVER-SQUARE-INACTIVE (and HOVER-SQUARE changed):
  top corners and the lowest row (YB - 3) CECECE, the 3 rows under it the strip, the active tab next to it
  square - both PASS. Its own reproduction with the review 2 build (full height) showed the hover colour
  down to the bottom row, which the new rows reject.
- N1 accepted: the Tab style group box has no WS_GROUP, like the Icon style box (a group box is never
  checked or focused); kept consistent with 416's group.
- N2 (fixed) the "Size:" label of Thumbnails 40 -> 30 DLU (the field closer to it; the widest label, es
  "Tamaño:" 42 / 45 px, still fits), "pixels" 62 -> 72 DLU.
- N3 answered: the live page (449 x 628 px) is taller than its template because the Configuration dialog
  is resizable and its stored height was larger; the minimum size comes from the 231-DLU template
  (`CTreePropHolderDlg`, `MinWindowSize`), which is the constraint of research R5.
- N4 / N5: the closing steps (closing report with the changelog entry, FEATURE-HISTORY) follow; the
  NOT DRIVEN rows are release-checklist lines.

After the fixes: `build.cmd full` BUILD SUCCEEDED; merge 0 gaps, `slt --verify` byte-exact, 12 rows per
language differ from `main`; saltests 287,255 / 0; encoding guard 0; `tabs423_probe` **57 PASS / 0 FAIL /
2 NOT DRIVEN** (`probe/result_after.txt`). The change is the hover's height in the Square branch only (the
Rounded paths, already compared pixel for pixel with the build before 423, are untouched), so no third
review was run.

## Follow-up (the maintainer, 2026-11-10, after the closing)

The square hover ran over the tab's full width (and from the content band's top), while the rounded pill
is inset 3 px left, 2 px right, 4 px top and 3 px bottom; the maintainer asked to keep those insets. Now
the square hover is exactly the pill's box `{r.left + 3, 4, r.right - 2, H - 3}` (scaled) without the
corners. Probe rows HOVER-SQUARE / HOVER-SQUARE-INACTIVE check its four corners (CECECE) and one pixel
outside each edge (strip): `tabs423_probe` 57 PASS / 0 FAIL / 2 NOT DRIVEN; saltests 287,255 / 0;
`build.cmd` BUILD SUCCEEDED. No UI text changed (no translation refresh).
