# Closing report - 423-square-panel-tabs
Backlog item: square-panel-tabs-as-the-new-default-rounded-tabs-kept-as-an - Square panel tabs as the new default; rounded tabs kept as an Appearance option
Outcome: closed

## What changed

- **Square panel tabs by default.** The active tab is a plain box from the top of the strip's content
  band down into the directory line (no rounded corners, no feet - the maintainer's mockup
  `evidence/flat_tabs.png`); the hover is the rounded style's pill box with square corners (the same insets
  as Rounded), so only the active tab joins the directory line. Tab positions, icons, titles, separators, the close glyph and the + are unchanged.
- **Configuration > Appearance > Tab style** (directly below *Icon style*): *Square* (default) /
  *Rounded* (the look of feature 404, pixel-identical). Applied to both panels on OK without a restart.
  Stored as "Panel Tab Style" (REG_DWORD 0 / 1; missing, REG_SZ or an unknown number = Square, the number
  kept and written back unchanged; written only when the user changes it).
- **Light theme legibility (the maintainer's request with the run):** inactive tab titles and the + are
  2C2C2C instead of 545454 on the DEDEDE strip - 10.38:1 instead of 5.63:1, still a step lighter than the
  black active / hovered title. Dark and High Contrast unchanged.
- The Appearance page keeps its size: *Icon style* moved up into the former *Thumbnails* row, the bottom
  row holds *Tab style* and *Thumbnails*; *Panel Font* and *Content of Information Line* unchanged. Tab
  order follows the layout.
- Manual: `help/src/hh/salamand/configuration_appea.htm` (*Tab style*).

Code: `src/common/saltabs.*` (`SALTAB_STYLE_*`, `SalTabStyleFromStored`, `SALTAB_DIMTEXT_*`),
`src/tabwnd.cpp` (`PaintTabBack`), `src/cfgdlg.h`, `src/dialogs4.cpp`, `src/dialogs5.cpp`,
`src/mainwnd.h`, `src/mainwnd2.cpp`, `src/mainwnd3.cpp`, `src/consts.h`, `src/lang/lang.rc` / `.rh`,
`src/saltests/saltests.cpp`; translations of `salamand` in 8 languages and `translations/ui-overrides.json`.

## Measurements (before / after, commands)

- Before (75efd1ac): `tabs413_probe -Only THEME` on the hidden desktop - the rounded active tab with feet
  (`probe/captures_before/`), no tab-style setting; Light inactive title 545454 on DEDEDE = 5.63:1
  (`probe/result_before_tabs413.txt`).
- After: `tabs423_probe` (`probe/result_after.txt`) - default (no value) square in Light and Dark, both
  panels (corners = fill, no feet); value 7 and REG_SZ square, 7 kept after OK + Save Configuration;
  value 1 rounded, corner boxes identical to the before capture (0 / 0 px, each capture's tab located by
  its own pixels); square hover CECECE with the strip under it in the active and the inactive panel;
  the page: Square checked by default, Rounded + OK -> rounded without a restart and stored 1, Square +
  OK -> 0, Cancel changes nothing; Light inactive title 2C2C2C = 10.38:1, Dark B3B3B3 unchanged; layout
  inside the page, no overlaps, Tab style below Icon style; FIT of the page's moved and new texts and of
  the Panel Font field in 9 languages.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `build.cmd full`: BUILD SUCCEEDED (21 modules x 8 languages).
- `saltests`: 287,255 checks, 0 failed (`TestTabStrip423`; 404's DimText expectation updated).
- `tabs423_probe`: 57 PASS / 0 FAIL / 2 NOT DRIVEN (real mouse, other DPI).
- Regression (with "Panel Tab Style" = 1 in their preparation): `tabs404_probe` 29 / 0 / 1 (also
  "Toolbar Icon Set" = 1: its evidence predates 416's Fluent drive icon, which had made its LOOK rows
  fail since 416), `tabs413_probe` 22 / 0 / 1, `tabs405_probe` 7 / 0 / 1.
- Translations: 3 new texts, 192 DeepL characters, 7 pins, `slt --verify` byte-exact, 12 rows per
  language differ from `main`.

## Reviews (findings and what was done)

- Review 1: no MUST. S1 the narrowed Panel Font field cut its text in 7 languages - layout reworked, FIT
  covers the field; S2 a probe row depended on the stored window size - each capture's tab is now
  located by its pixels; N1 tab order, N2 a misplaced test comment, N3 help wording - fixed.
- Review 2: no MUST. S1 a full-height square hover in the inactive panel read as a second active tab -
  the hover ends 3 px above the directory line, new probe row; N2 Thumbnails label spacing - fixed; N1
  (group box WS_GROUP) kept as 416's group; N3 answered (the page's minimum size is the template's).
- Details: `fix-log.md`, *Review*.

## Owed to a person (the lines added to the release checklist)

Three lines added to `manual-checks-owed-before-the-next-release` (feature 423): the square look and
the hover with a real mouse in both themes (and the 404 line about the rounded tab now checked with
Tab style = Rounded); the page with a real mouse and keyboard (OK both ways, tab order, arrows, Czech
and German); 125 / 150 / 200 % in both styles.

**CHANGELOG entry** - `CHANGELOG.md` has no `## [Unreleased]` section (the tree is prepared for 0.3.0,
tag `v0.3.0`), so the run does not create one; the maintainer adds this entry where the next release
wants it:

```markdown
- **Panel tabs are square by default; the rounded look is one click away** (feature 423).
  - **Before:** the active tab had rounded top corners and rounded feet where it joined the Directory line, and in the default (light) theme the titles of the other tabs were a pale grey.
  - **Now:** the active tab is a plain rectangle that runs straight into the Directory line, and the highlight under the mouse is a rectangle too. *Configuration → Appearance → Tab style* switches between **Square** and **Rounded** (the previous look); the choice applies at once. In the light theme the titles of the inactive tabs are darker and easier to read.
```

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- The *Thumbnails* labels (19 / 22 DLU) were clipped in 7 of 8 languages (e.g. Czech "Velikost:" 40 px in
  29 px); they now have room (FIT: all 9 PASS). French "éléments d'images (pixels)" pinned to "pixels".
- `tabs404_probe` LOOK rows failed since 416 (the E:\ tab's Fluent drive icon against the mockup); the
  probe now uses the Classic set its evidence was made with (recorded; refreshing the 404 evidence to
  Fluent 2 is probe upkeep).

## New Inbox items (slug - title)

None.

## Notes for the maintainer

- The product's registry key changed between two probe runs of this feature, outside any probe (hash
  F8CA10C2... -> 1A2CB153...; the stored main-window size and "Toolbar Icon Set" = 1 are in the current
  key); every probe restored its key identically. If that was not you, it is worth a look.
- `main` carried the prepared 0.3.0 release commit when this feature started; whether 423 goes into
  0.3.0 or the next release is the maintainer's decision (`/tandem-release`).
