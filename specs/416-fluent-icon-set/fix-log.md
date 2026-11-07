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

## Translations (stop-rules 2.13, module salamand)

- Entries (step 0): dialog IDD_CFGPAGE_APPEARANCE (DIALOG 595) new controls 6291 group " Toolbar &icons ",
  6292 "Fl&uent 2", 6293 "C&lassic", 6294 / 6295 owner-drawn statics (""); no changed English text, no
  string-table change (step 2 not needed).
- `.\build.cmd` -> BUILD SUCCEEDED; `build_langs.cmd --export-templates --module salamand` -> 1/1.
- Dry run: 3 unique gaps, ~33 chars per language (8 languages) = the 3 new texts.
- Pins before the merge (`translations/ui-overrides.json`, salamand, `_feature_416`): IDC_ICONSET_FLUENT
  "Fl&uent 2" in all 8 languages (a name).
- Merge `--budget 2528`: 240 DeepL characters, validation failures 0, duplicate accelerators 147 -> 148.
- Read-back: cs / sk kept the English "&Classic" -> pinned "&Klasická" (accelerator k; c is taken on the
  page); es "Fl&uent 2" clashed with "&Un solo click" -> pinned "Flu&ent 2". Others: de " S&ymbolleisten-Symbole "
  / "C&lassic", fr " &Icônes de la barre d'outils " / "Cla&ssique", nl " &Pictogrammen op de werkbalk " /
  "K&lassiek", hu " Eszköztár &ikonok " / "Kl&asszikus", ro " P&ictograme din bara de instrumente " /
  "C&lassic", es " Iconos &de la barra de herramientas " / "C&lásico"; no informal register (no pronouns).
- Second merge: duplicate accelerators back to 147 (baseline), validation failures 0; `translate.slt --verify`:
  298 files, round-trip byte-exact. Layout drift: none (the diff holds only the 5 new rows per language and
  their `.origin` keys). `.\build.cmd full` -> exit 0, 189 language modules.

## Probe (iconset416_probe.ps1, hidden desktop)

Command: `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\416-fluent-icon-set\probe\result_after.txt
-CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\416-fluent-icon-set\probe\iconset416_probe.ps1
-Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Before %TEMP%\tc416\before_build\tandemcommander.exe -Label after"`.
The "before" side is the build of `main` inside the same run (rows CLASSIC-EQ, OVR-CLASSIC-BEFORE).

- Capture method measured first (`try416_capture.ps1`, `result_try.txt`): PrintWindow client-only shows the
  rebar, toolbars and panels on the hidden desktop.
- Run 1 (`result_after_run1.txt`): PASS 31, FAIL 4 - all probe defects: the directory line's free-space
  text changes between runs (now only its drive icon is compared); the computed dialog base unit 6.44 vs
  the live 6.00 (now taken from the live English page); the English template path (one Split-Path too
  many). Earlier dev run: the tree dialog's OK is id 5 (`_TPD_IDC_OK`) - posting IDOK ended the dialog
  without the pages' Transfer; the focused `..` row is drawn with the icon tincture (the probe now moves the
  caret down).
- Run 2 (`result_after.txt`): **PASS 35, FAIL 0, NOT DRIVEN 3**; registry restored, SHA-256 identical.
  - CLASSIC-EQ light / dark: build of main vs Classic: rebar, files, dirline 0 px differ.
  - DEFAULT light / dark: no value = value 0 = value 2 = REG_SZ (no error box): 0 px; Fluent vs Classic
    rebar ~4900 / ~5000 px differ; `..` navigation blue #0F6CBD / #62ABF5: Fluent 45 px, Classic 0.
  - SWITCH: 29 tree items walked to the page; Fluent checked; previews 312 / 173 colours, 1688 px differ;
    Classic clicked + OK -> rebar = Classic capture (0 px) without restart; stored 0x1; restart = Classic.
  - PAGE light / dark: previews drawn and different.
  - FIT: live base unit 6.00 / 6.01; all 3 labels fit in English and the 8 languages (widest "Pictograme din
    bara de instrumente" 170 / 427 px, radios <= 47 / 88 px).
  - OVR-FLUENT: 95 empty dark overrides (Copy.svg not an SVG) = no dark folder (0 px); hand-made dark files
    differ from the adapted standard files (verbatim use measured).
  - OVR-CLASSIC-AFTER: 63 empty overrides in toolbars\dark = no overrides (0 px).
  - OVR-CLASSIC-BEFORE (negative control on the build of main): 5143 px differ - the defect (blank cells).
  - NOT DRIVEN: a menu opened by a real keyboard / mouse; hot / pressed states; 125-200 % DPI -> release
    checklist lines (manual-checks-owed-before-the-next-release, 5 lines, feature 416).

## Deviations (stop-rules rule 14)

- The item asked the probe to capture at 100 % and 150 %; the hidden desktop's system DPI is fixed for the
  session. 125 / 150 / 200 % are covered by saltests (every file rasterized at 20 / 24 / 32 px with the
  program's rasterizer) and a release-checklist line for a real scaled screen - a person check (rule 9),
  so no Inbox item.
- A menu capture is not driven (no real keyboard / mouse on the hidden desktop); the menus draw from the
  same image lists the probe captured on the toolbar; release-checklist line.

## PRIVACY.md

Not affected (confirmed): no network communication; the new value "Toolbar Icon Set" is one of "the
settings" stored in `HKEY_CURRENT_USER\Software\Tandem Commander` that the statement already describes; the
installer copies more program files (`iconsets\fluent\`), which "It copies the program files" covers, and
uninstalling removes them as program files; nothing about credentials or crash reports changes.
