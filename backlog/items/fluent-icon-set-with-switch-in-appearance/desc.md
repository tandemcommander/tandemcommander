---
title: Fluent toolbar icon set by default, switchable to Classic in Appearance
type: feature
status: in-progress
severity: 5
area: panels-ui
source: manual
who: both
created: 2026-11-07
updated: 2026-11-07
verified: 2026-11-07 e72ddd38
effort: L
feature: 416
related: []
depends-on: []
reason: -
---

# Fluent toolbar icon set by default, switchable to Classic in Appearance

## Problem

The toolbar, menu and drive-bar icons mix four styles and do not hold up in the Dark theme:
- 59 buttons draw Visual-Studio-style SVGs (`src/res/toolbars/*.svg`);
- 15 buttons draw 16-colour raster glyphs from `src/res/toolbar2.png`: the whole Selection group, plus Shared Directories, whose SVG name sits on the wrong table row;
- 9 system-folder buttons and every drive on the drive bar show Windows shell/imageres icons;
- plug-ins use their own bitmaps.

The Dark theme has no hand-made variants (`toolbars/dark/` is empty). The automatic recolouring leaves the main blue accent `#00539C` at 1.8:1 contrast on the dark bar.

The maintainer chose a new set ("Fluent 2", built on Microsoft Fluent UI System Icons) as the **default**. Users must be able to switch back to the **original set** ("Classic", exactly today's look) in **Configuration → Appearance**. Each set in that list shows a **preview**, so the user sees at once what the set looks like.

## Evidence

At 5fb1b7fc, by reading:
- **Button table:** `ToolBarButtons[]` in `src/toolbar4.cpp:149-252`, columns `Shell32ResID` and `SVGName`.
- **Image lists:** built by `CreateToolbarBitmaps` in `src/toolbar4.cpp:730-946`, which overlays SVGs on `toolbar2.png` and appends shell icons, then `CreateGrayscaleAndMaskBitmaps_tmp`. Called from `src/salamdr1.cpp:2490-2526`.
- **SVG loader:** `RenderSVGImage` in `src/svg.cpp:103-196` reads `<exe dir>/toolbars/dark/<Name>.svg` first in the Dark theme, then `toolbars/<Name>.svg`. Files are read at start-up and on every theme switch (`SetThemeMode`, `src/themes.cpp:1445` → `ColorsChanged` → `ReleaseGraphics` / `InitializeGraphics`).
- **Deployment:** `src/vcxproj/!populate_build_dir.cmd:115-118` copies `toolbars/` and `toolbars/dark/`. The installer takes `Release_x64/*` recursively (`setup/tandemcommander.iss:110`, `recursesubdirs`).
- **Mix-up on two rows:** `toolbar4.cpp:225-226`. `TBBE_ZOOM_PANEL` (no image) carries the SVG name `SharedDirectories`, and `TBBE_SHARES` has none.
- **Missing files:** 14 `SVGName`s of the Selection group have no file today (`toolbar4.cpp:189-239`).
- **Other icon sites the set covers:**
  - drive bar and Change Drive: `GetDriveIcon` in `src/salamdr1.cpp:1042` (imageres 28-36), `FillDriveBar` in `src/drivelst.cpp:3633`, `CFilesWindow::UpdateDriveIcon` in `src/fileswn3.cpp:2892`;
  - the file-list `..` symbol: `IDI_UPPERDIR` (`src/res/updir.ico`), loaded at `src/salamdr1.cpp:2587`;
  - the configuration-list header toolbar: `src/gui.cpp:2741-2758`, which uses `Modify`, `MoveItemUp`, `MoveItemDown` and `New_Insert`, the last of which has no file;
  - the drop-down arrow: `IDV_ARROW_DOWN` (`src/res/down.svg`, RCDATA), coloured in `CSVGSprite::ColorizeSVG` (`src/svg.cpp:371-398`).
- **Configuration page:** `CCfgPageAppearance` in `src/dialogs5.cpp:2875` (`Transfer`, `LoadControls`). The dialog is `IDD_CFGPAGE_APPEARANCE` in `src/lang/lang.rc:1264-1291`, 299×231 DLU. Its controls end at y≈184 (the Thumbnails group), so a group with previews may need more room or a new layout.
- **Model for the new setting:** `Configuration.ThemeMode` (`src/cfgdlg.h:331`, default `src/dialogs4.cpp:280`), saved as `CONFIG_THEMEMODE_REG` "Theme Mode" (`src/mainwnd2.cpp:328, 2071, 3711`).
- **Robustness defect the new set depends on:** `src/res/toolbars/dark/README.txt` and `specs/029-dark-toolbar-icons/contracts/dark-icon-override.md` promise a silent fall-back when an override cannot be used. `RenderSVGImage` uses any file it can open, and never checks `nsvgParse` for NULL (`svg.cpp:117-124, 156, 171`). An override with no shapes gives an empty button.

**Design study** (outside the repository, made 2026-11-07, by simulation; not yet on a real build). Folder: `C:\Users\pavel\AppData\Local\TandemIconStudy\`:
- `index.html`: analysis of today's icons and the 13 findings.
- `fluent.html`: the Fluent 2 catalogue, today vs new for every icon, in light, dark, disabled and 150 %.
- `novy-design-aplikace.html`: a mock-up of the whole window, old and new side by side, with the Files menu and button states. View parameters work in the address, e.g. `#dpi=150&theme=dark&menu=1`.
- `novy-design-fluent\toolbars\*.svg` and `toolbars\dark\*.svg`: the 95 + 95 proposed files, with `LICENSE-fluent.txt`.
- `nastroje\gen_fluent.py`: the generator. It holds the mapping button → Fluent icon → colour role, the palettes, the paper underlay, the halo and the three own glyphs (console `>_`, `..`, Network composite).
- Source of the glyphs: npm `@fluentui/svg-icons` 1.1.344 (published 2026-10-09), integrity `sha512-rasjaq4hBXzRS25pSY9gaqwY7NdvZJCz7G/rtpwF6mCmg2R+9TnySLhHbR+sOpkMP/IDDG28XvxRcNEQ/lJYoQ==`, MIT licence (Copyright (c) 2020 Microsoft Corporation), compatible with GPLv2.

The study also tried and rejected an own drawing ("Jasná linka", `novy-design.html`). Blind recognition tests are archived in `testy\`. In a paired comparison of 80 commands, the new design was judged better for meaning 52 / 14 / 14 (better / worse / equal) and for dark-bar legibility 65 / 2 / 13.

## Expected

- **Two icon sets, one setting:**
  - **Fluent 2** is the default for every configuration that has not chosen a set, also after an upgrade.
  - **Classic** is today's look, pixel for pixel: SVG overlays, `toolbar2.png`, shell and imageres icons, `updir.ico`, today's drop-down arrow.
- **The setting is stored** under the configuration root (`SALAMANDER_ROOT_REG`, never a literal key; rule of feature 343), e.g. "Toolbar Icon Set". An unknown or missing value means Fluent 2.
- **Configuration → Appearance** has a group (e.g. *Toolbar icons*) with one choice per set.
  - Each choice shows a **preview**: a strip of about 10 representative icons from the default top toolbar, in the active theme (light or dark), drawn by the same rendering code the toolbar uses, so the preview equals the result.
  - The choice applies at once on OK / Apply, without a restart, the way a theme switch rebuilds the image lists.
- **Fluent 2 covers every icon the study covers:**
  - all 85 toolbar buttons that have an image, including the 14 Selection buttons, Shared Directories (the row mix-up fixed) and the 9 system-folder buttons;
  - the drive-bar and Change Drive drive types: fixed, system, removable, CD, network, unavailable network, RAM. Cloud services and WSL keep their brand icons;
  - the `..` symbol in the file list, which keeps today's shape: an angular up arrow whose stem turns right, plus two square dots, in the navigation blue;
  - the configuration-list toolbar, `New_Insert` included;
  - the menus, which use the same image lists.
- **Hand-made Dark variants** of Fluent 2 are used verbatim. A Dark override that cannot be parsed or has no shapes falls back to the standard SVG, as the dark-override contract says; the NULL check is added.
- **Legibility:** no Fluent 2 icon disappears on the toolbar (light / dark, normal / hot / pressed / checked / disabled) or on the dark blue menu highlight (`COLOR_HIGHLIGHT`). The paper underlay and halo of the study do this. The same holds at 100 / 125 / 150 / 200 % DPI.
- **Licence:** the Fluent licence text (MIT) ships with the program, next to the other licences in `doc/` and in the installer. `PRIVACY.md` is not affected (no network, no data); confirm this in the record.
- **Strings:** new UI strings are translated by the two-stage `.slt` refresh in the run itself (CLAUDE.md, feature 084). The Appearance labels are checked for clipping in the 8 shipped languages.
- **Evidence:** a hidden-desktop probe captures the toolbar, drive bar, file list, a menu and the Appearance page in both sets × both themes, at 100 % and 150 %. Pure rules (the set id from the registry value, the file path of a set's icon) get `saltests` checks.

## Approach

1. **Bring the study into the repository** (it now lives only in `%LOCALAPPDATA%`):
   - the generated SVGs and their dark variants as a new set folder, e.g. `src/res/iconsets/fluent/` and `src/res/iconsets/fluent/dark/`;
   - the generator and its mapping under `tools/` (e.g. `tools/brand/fluent-icons/`), with a README that says how to fetch the pinned npm package (version + sha512) and regenerate.
   - Do not vendor the whole 12 MB npm package. Keep today's `src/res/toolbars/` as the Classic set unchanged (or move it to `iconsets/classic/` with `toolbars` kept as its deployed name; decide by the least risk to the existing override contract).
2. **Set selection in the loader:**
   - `RenderSVGImage` and `CreateToolbarBitmaps` take the active set's folder.
   - For Fluent 2, the 9 shell-icon buttons get an SVG name and skip the shell icon; Classic keeps the shell icons.
   - `GetDriveIcon` and `UpdateDriveIcon` rasterize the set's drive SVGs at the icon size for Fluent 2.
   - `IDI_UPPERDIR` is replaced by the set's `UpDir.svg`, rasterized at 16 / 32 / 48.
   - The drop-down arrow `down.svg` gets a Fluent chevron, and its disabled colour moves from BTNSHADOW to GRAYTEXT; the study found BTNSHADOW invisible in Dark.
3. **Appearance page:** add the group with radio buttons and owner-drawn preview strips. Re-check the 299×231 DLU page; if the room is not enough, enlarge the page or move the Thumbnails / Information Line groups, and measure clipping in all languages.
4. **Measure first, on a real build:**
   - The study rendered with the browser, not nanosvg. Check that nanosvg draws the Fluent paths: arcs, fill rules, the `translate`/`scale` transform of the Network badge, the halo strokes.
   - Compare against the study mock-up at 100 % and 150 %.
   - Back up and restore the registry key around the probe (CLAUDE.md working method).

## Notes

- **Out of scope** (separate items if the maintainer wants them, all shown in the study mock-up):
  - flat rounded button states instead of the 3D bevels;
  - the Windows-11-style menu highlight (`menu3.cpp`);
  - F-key "chips" instead of `bottomtb.bmp`;
  - the grey (instead of embossed) disabled menu icons.
- **Plug-in icons** stay as they are (plug-in API, `SetIconListForGUI`).
- **Person's part (`who: both`):** a visual check of both sets on the maintainer's screen in both themes and at the maintainer's DPI. Add it to the release checklist item if the run cannot finish it.
- **Constitution, UI consistency:** the Classic set must stay byte-identical in look, so a user who switches back sees no change against 0.2.0.

## Log

- 2026-11-07 — created (source manual)
- 2026-11-07 — moved to Next position 1
- 2026-11-07 — verified at e72ddd38: still present at e72ddd38: one icon set only, no set setting in Appearance; RenderSVGImage has no NULL check after nsvgParse and an empty override blanks the button
- 2026-11-07 — run started, feature 416
