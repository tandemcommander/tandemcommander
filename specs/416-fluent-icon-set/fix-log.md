# Fix log - 416-fluent-icon-set

Backlog item `fluent-icon-set-with-switch-in-appearance` - Fluent toolbar icon set by default, switchable
to Classic in Appearance. Branch `416-fluent-icon-set`, from `main` at e72ddd38.

## Measured first (at e72ddd38, before any change)

- Reading: one icon set only. `RenderSVGImage` (src/svg.cpp) reads `toolbars\dark\<Name>.svg` (Dark theme)
  then `toolbars\<Name>.svg`; no setting chooses a set (`grep "Icon Set" src` - nothing). It fills the cell
  with the background **before** parsing and uses `nsvgParse`'s result without a NULL check, so a dark
  override with no shapes blanks the button (the 029 contract's rule 3 promised a fall-back).
- Reachability: `InitializeGraphics` (start-up and every `ColorsChanged`) -> `CreateToolbarBitmaps` ->
  `RenderSVGImages` -> `RenderSVGImage`; the theme switch `SetThemeMode` -> `ColorsChanged(TRUE, FALSE, TRUE)`
  rebuilds image lists, `..` icon, drive bars (`RebuildDrives`), panel drive icons (`UpdateDriveIcon`), tab
  icons (`ClearIcons`, 404). The Configuration dialog has no Apply (`PSH_NOAPPLYNOW`); OK runs
  `RefreshAfterConfiguration` (also the settings import of 245). `InitializeGraphics(FALSE)` runs before
  `LoadConfig`, so the set must be read early (as Theme Mode is).
- Study files (`%LOCALAPPDATA%\TandemIconStudy`): 95 + 95 SVGs, `LICENSE-fluent.txt`, the generator. The npm
  tarball's sha512 equals the item's pin (`openssl dgst -sha512 -binary pkg.tgz | base64`).
- Before tree for the Classic comparison: `.\build.cmd` at the branch start (no source change yet, 9 s, up to
  date) copied to `%TEMP%\tc416\before_build`.

## Decisions (autonomous run, recorded in spec.md)

- Classic stays `src/res/toolbars/` -> `toolbars\` (029's contract and README keep their paths); Fluent 2 in
  `src/res/iconsets/fluent/` -> `iconsets\fluent\` (+ `dark\`, `LICENSE-fluent.txt`).
- Classic keeps the 0.2.0 Zoom Panel / Shared Directories row mix-up (pixel-identical); Fluent's name table
  fixes it (`SalIconSetFluentButtonName`).
- Documents / Network of the drive bar get Fluent's `OpenDocuments` / `OpenNetwork` (the study's mock-up).
- The drop-down chevron's GRAYTEXT disabled colour only in Fluent 2.
- Licence: deployed inside the set folder (the installer takes the build tree recursively - no `.iss` change),
  named in `doc/third_party.txt`.
- The Configuration-list toolbar (`CToolbarHeader`, gui.cpp) needs no code: it passes the default set (-1 =
  configured) and the Fluent folder has `Modify`, `New_Insert`, `Delete`, `SortByName`, `MoveItemUp/Down`.

## Implementation notes

- `src/common/saliconset.h`: set ids, `SalIconSetFromStored`, folders, `SalIconSetBuildPath` (refuses a bad
  name or a path that does not fit, never cuts), Fluent button / drive names, `SalIconSetChooseSource`, the
  preview list.
- `src/svg.cpp`: `LoadSetSVGImage` parses first, keeps an image only with shapes, dark variant only when
  usable; `RenderSVGImage` returns BOOL and touches the cell only for a usable image; `CreateSetSVGIcon`
  (32-bpp straight-alpha icon + 1-bit mask, HANDLES-tracked); `CSVGSprite::Load` takes the disabled colour;
  `ColorizeSVG` also recolours a colour stroke (the Classic sprites have none).
- `src/toolbar4.cpp`: `GetSVGIconsMainToolbar(set)`, `CreateToolbarBitmaps(..., iconSet)` - in Fluent a
  shell-icon button gets its SVG, the shell icon stays the fallback; `CreateIconSetImageList`,
  `GetToolBarButtonImageIndex` for the preview.
- `GetDriveIcon`, `LoadSetIconOr` (Documents / Network, removable tab), `..` icon, chevron
  (`IDV_ARROW_DOWN_FLUENT` = 1026; 1022-1025 are dialog ids of lang.rh) in salamdr1.cpp / drivelst.cpp / tabwnd.cpp.
- Setting: `Configuration.ToolbarIconSet`, "Toolbar Icon Set" REG_DWORD, read quietly (`GetValueAux(..., TRUE)`:
  a wrong type gives no error box) by `ReadToolbarIconSet` early (salamdr1.cpp, with Theme Mode) and in
  `LoadConfig`; saved in `SaveConfig`.
- Appearance page: group " Toolbar &icons " (1,189,295,40 DLU - the free room below Thumbnails), radios
  "Fl&uent 2" / "C&lassic", two `SS_OWNERDRAW` previews built by `CreateIconSetImageList` (the toolbars' own
  code) in `WM_INITDIALOG`, drawn in `WM_DRAWITEM` on BTNFACE. `RefreshAfterConfiguration` calls
  `ColorsChanged(TRUE, FALSE, TRUE)` when the set changed.
- Deploy: `build.cmd` `:populate_runtime` (the real deployer of a full build) and `!populate_build_dir.cmd`.

## Findings fixed on the way (severity <= 5, stop-rules rule 11)

1. **nanosvg drew circles written as two half arcs as nothing** (severity 5; met while measuring T007).
   Measured: `saltests` offline rasterization - `DriveCD.svg` 0 % coverage at every size, `Properties.svg` 1 %,
   `HelpContents.svg` 4 %. Cause: the vendored `nsvg__pathArcTo` (old canvg port) flips the angle by the
   large-arc flag only and ignores the sweep flag; for an exact semicircle (da = +/-PI, sign carries no
   direction) the half lands on the wrong side, and Fluent's `a7 7 0 1 1 0 14A7 7 0 0 1 8 1` cancels out.
   Fix: upstream nanosvg's sweep rule (`fs == 0 && da > 0 -> da -= 2 PI`, `fs == 1 && da < 0 -> da += 2 PI`).
   For every arc that is not an exact semicircle da's sign already matches the sweep for the centre the
   code chose, so the output is unchanged; no Classic toolbar / resource SVG has a path arc (circles and
   rounded rects go through nanosvg's own cubic code); the tab strip's quarter arcs (tabwnd.cpp, fa = 0) are
   unchanged. Tests: circle of two halves 608 px vs `<circle>` 611 px (before: 0); counter-clockwise halves
   608; rounded rect of quarter arcs 542 = `<rect rx>` 542; the tab shape with feet 575 (> 0).
   After: worst coverage of the set 14 %.
2. **check_iconset.py missed leftover arguments before a new command** (own tool, during its negative control):
   a merged-flag arc `a1 1 0 011 1z` passed; fixed, the negative control (missing dark file, mask colour,
   merged flags) now reports 3 of 3.

## Checks so far

- `saltests`: 285482 checks, 0 failed (`TestIconSet416`: rules, the arc fix, every Fluent file at
  16/20/24/32 px light + dark).
  Silhouette = contrast reached by the strongest 5 % of the cell, worst per theme x background:

  | theme / background | Fluent 2 | Classic (today) |
  |---|---|---|
  | light toolbar F0F0F0 | 2.42 (Forward @16) | 1.72 (RootDirectory @32) |
  | light checked FFFFFF | 2.72 | 1.96 |
  | light highlight 0078D7 | 1.62 (OpenActiveFolder @16) | 1.61 (Delete @32) |
  | light panel FFFFFF | 2.72 | 1.96 |
  | light disabled | 1.53 (Back @16) | 1.30 |
  | dark toolbar 2D2D2D | 2.85 | 1.78 (Back @16) |
  | dark checked 464646 | 1.95 | 1.22 |
  | dark highlight 264F78 | 1.76 | 1.10 (Back @16) |
  | dark panel 383838 | 2.43 | 1.52 |
  | dark disabled | 1.66 | 1.21 |

  Floors checked per Fluent icon: toolbar >= 2.0, checked / panel >= 1.8, highlight >= 1.5, disabled >= 1.4;
  per set: Fluent's worst >= Classic's worst - 0.05. The Classic column is the negative control: Classic's
  dark Back (1.10 on the highlight, 1.78 on the bar - the item's "1.8:1") would fail the floors.
  A first metric (pixels at 3:1 / covered pixels) failed 173 rows: at 16 px a 1-px anti-aliased stroke never
  has a full-strength pixel, and an underlay is meant to blend in; replaced by the silhouette metric
  (recorded, not tuned per icon).
- `python tools/brand/fluent-icons/check_iconset.py`: 95 + 95 files, 95 names used, 85 buttons with an image,
  palette rule (outline >= 3:1 on the face; outline or underlay / halo >= 3:1 on the highlight), 0 problems.
- `python -I tools/brand/fluent-icons/gen_fluent.py <pinned package>` regenerates the 190 files byte-identical.
- `.\build.cmd`: BUILD SUCCEEDED.
