# Closing report - 416-fluent-icon-set
Backlog item: fluent-icon-set-with-switch-in-appearance - Fluent toolbar icon set by default, switchable to Classic in Appearance
Outcome: closed

## What changed

- **Fluent 2 icon set, the default**: 95 icons + 95 hand-made Dark variants built on Microsoft Fluent UI
  System Icons 1.1.344 (MIT) in `src/res/iconsets/fluent/` (+ `dark/`, `LICENSE-fluent.txt`), deployed as
  `iconsets\fluent\` by `build.cmd` (`:populate_runtime`) and `!populate_build_dir.cmd`; the installer ships
  it through its recursive rule. Generator, pin (version + sha512) and data check in
  `tools/brand/fluent-icons/` (`gen_fluent.py` regenerates the 190 files byte-identical, `check_iconset.py`).
- **Classic** = the 0.2.0 look, pixel-identical (`src/res/toolbars/` unchanged, the same calls in the same order).
- Fluent 2 covers the 85 toolbar buttons with an image (14 Selection buttons, Shared Directories - the 0.2.0
  row mix-up fixed in Fluent's table only -, the 9 system folders, the Change Drive slots), the drive types of
  `GetDriveIcon` (drive bar, Change Drive menu, directory line, tabs, Drive Information), Documents and
  Network, the `..` symbol (UpDir, 16/32/48), the configuration-list toolbars (New_Insert included), the
  menus (same image lists) and the drop-down chevron (GRAYTEXT when disabled). A missing Fluent file falls
  back to the Classic icon of that site; cloud services, WSL, archives and plug-ins keep their icons.
- **Configuration > Appearance > Toolbar icons**: radios Fluent 2 / Classic with owner-drawn preview strips
  (10 icons each, built by the toolbars' own `CreateToolbarBitmaps` in the active theme); OK applies at once
  (`ColorsChanged(TRUE, FALSE, TRUE)`), also after a settings import and after a configuration imported at
  start-up.
- **Setting** "Toolbar Icon Set" (REG_DWORD under the configuration root), read quietly early (with Theme
  Mode) and in `LoadConfig`; missing / unknown / wrong type = Fluent 2; a later version's number is kept.
- **Dark-override fall-back made real**: an override that does not parse or has no shape uses the standard
  file (adapted); a file that cannot be used never blanks a cell (029's contract rule 3); NULL checks.
- **nanosvg arc fix** (vendored `nanosvg.h`): the sweep flag decides the direction (upstream rule) - circles
  written as two half arcs drew nothing before.
- Pure rules in `src/common/saliconset.h`; contract `specs/416-fluent-icon-set/contracts/icon-set-files.md`;
  `doc/third_party.txt` names the Fluent glyphs; `src/res/toolbars/dark/README.txt` points to the new contract.

## Measurements (before / after, commands)

- Before (e72ddd38, by reading + the build of main inside the probe): one set only; an empty dark override
  blanks cells - probe OVR-CLASSIC-BEFORE on the build of main: 2137 px differ (blank cells).
- saltests offline rasterization before the arc fix: DriveCD 0 %, Properties 1 %, HelpContents 4 % coverage;
  after: worst coverage 14 %, circle of two halves 608 px vs `<circle>` 611 px.
- Review 1 S1 reproduced first: probe IMPORT on the unfixed build - Classic in the file, the window Fluent
  (rebar 3748 px differ, `result_import_before_fix.txt`); after: 0 px.
- Legibility (strongest 5 % of a cell, worst icon per theme x background), Fluent 2 vs Classic: light toolbar
  2.42 / 1.72, light highlight 1.62 / 1.61, dark toolbar 2.85 / 1.78, dark highlight 1.76 / 1.10, dark
  disabled 1.66 / 1.21 (full table in fix-log.md).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd full`: BUILD SUCCEEDED, 189 language modules.
- `saltests`: 285482 checks, 0 failed (`TestIconSet416`).
- `python tools/brand/fluent-icons/check_iconset.py`: 95 + 95 files, 95 names used, 85 buttons, 0 problems
  (negative control: 3 of 3 damages reported).
- Probe `iconset416_probe.ps1` (hidden desktop, registry restored identical): **PASS 36, FAIL 0, NOT DRIVEN 3**
  (`probe/result_after.txt`) + SWITCHBACK PASS 3 (`probe/result_after_switchback.txt`); earlier runs and their
  probe defects in fix-log.md.
- Translations: two-stage `.slt` refresh of `salamand`, 3 gaps x 8 languages, 240 DeepL characters, pins
  (Fluent 2 name, cs/sk "Klasická", es "Flu&ent 2", nl "Kla&ssiek"), duplicate accelerators 147 (baseline),
  `slt --verify` byte-exact; labels fit in English and 8 languages (probe FIT).

## Reviews (findings and what was done)

- Review 1: MUST 0, SHOULD 2 (S1 imported configuration - fixed, probe row IMPORT; S2 Dutch Font key -
  fixed), NOTE 7 (arc comment scope - fixed; later set number kept - fixed; NULL DIB in RenderSVGImage -
  fixed; the rest accepted with reasons in fix-log.md).
- Review 2: MUST 0, SHOULD 0, NOTE 6 - the review-1 fixes hold; the reviewer's Classic -> Fluent 2 row
  (SWITCHBACK) was taken into the committed probe (PASS 3, `result_after_switchback.txt`); the other NOTEs are
  accepted with reasons in fix-log.md.

## Owed to a person (the lines added to the release checklist)

5 checks added to `manual-checks-owed-before-the-next-release` (feature 416): both sets on a real screen in
both themes at the usual scaling with the switch on Appearance; menus with icons on the highlighted row;
hot / pressed buttons with a real mouse; 125 / 150 / 200 % scaling; the Appearance page in Czech and German.

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

1. nanosvg drew circles written as two half arcs as nothing (arc sweep ignored) - fixed in the vendored
   header (upstream rule), saltests arc checks.
2. `check_iconset.py` missed leftover arguments before a new path command (own tool) - fixed, negative control.
3. `RenderSVGImage` wrote through a NULL DIB when `CreateDIBSection` failed (0.2.0) - fixed.

## New Inbox items (slug - title)

- none

## CHANGELOG entry (no `## [Unreleased]` section in CHANGELOG.md - versions are the maintainer's)

- **Toolbar, menu and drive icons in one modern style - the old look one click away** (feature 416).
  - **Before:** the toolbar mixed Visual-Studio-style icons with 16-colour bitmaps (the whole Selection
    group, Shared Directories) and Windows icons (system folders, every drive on the drive bar); in the Dark
    theme the blue arrows and accents faded into the dark bar.
  - **Now:** the toolbars, menus, drive bar, Change Drive menu, the `..` symbol of the file list and the
    toolbars of the configuration lists use one icon set, "Fluent 2" (built on Microsoft Fluent UI System
    Icons, MIT licence, shipped with the program), with its own Dark variants. **Configuration > Appearance >
    Toolbar icons** shows a preview of each set; choosing **Classic** and OK switches back at once, without a
    restart, to exactly the icons of 0.2.0. A hand-made Dark icon that cannot be read no longer leaves an empty
    button.
  - **Limitation:** plug-in icons, cloud-service and WSL icons keep their own look; the button frames, the menu
    highlight and the F-key bar are unchanged.
