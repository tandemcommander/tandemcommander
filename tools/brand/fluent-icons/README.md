# Fluent 2 icon set (feature 416)

The default toolbar, menu, drive and `..` icons of Tandem Commander ("Fluent 2") are generated from
**Microsoft Fluent UI System Icons** (MIT licence, Copyright (c) 2020 Microsoft Corporation). The output is
committed in `src/res/iconsets/fluent/` (light) and `src/res/iconsets/fluent/dark/` (hand-made Dark variants,
used verbatim in the Dark theme) and deployed as `iconsets\fluent\` beside `tandemcommander.exe`. The old
set ("Classic") stays in `src/res/toolbars/`. The file contract is
`specs/416-fluent-icon-set/contracts/icon-set-files.md`.

The build does not run the generator and needs no network; the source package is **not** vendored.

## Pinned source

| | |
|---|---|
| package | npm `@fluentui/svg-icons` |
| version | `1.1.344` (published 2026-10-09) |
| tarball | `https://registry.npmjs.org/@fluentui/svg-icons/-/svg-icons-1.1.344.tgz` |
| integrity | `sha512-rasjaq4hBXzRS25pSY9gaqwY7NdvZJCz7G/rtpwF6mCmg2R+9TnySLhHbR+sOpkMP/IDDG28XvxRcNEQ/lJYoQ==` |
| licence text | `LICENSE` of https://github.com/microsoft/fluentui-system-icons (MIT) - the package has none |

## Regenerating

1. Download the tarball into an empty folder outside the repository, check it, unpack it:

   ```text
   mkdir %TEMP%\fluent-1.1.344 && cd /d %TEMP%\fluent-1.1.344
   curl -L -o pkg.tgz https://registry.npmjs.org/@fluentui/svg-icons/-/svg-icons-1.1.344.tgz
   python -c "import base64,hashlib;print(base64.b64encode(hashlib.sha512(open('pkg.tgz','rb').read()).digest()).decode())"
   tar -xzf pkg.tgz            (creates package\icons\*.svg)
   ```

   The printed hash must equal the integrity above. Save the MIT licence text of the Fluent repository as
   `LICENSE.txt` beside `package\`.
2. Run `python -I tools\brand\fluent-icons\gen_fluent.py %TEMP%\fluent-1.1.344` from the repository root.
   It rewrites the 95 + 95 files and `LICENSE-fluent.txt` in `src\res\iconsets\fluent`; with the pinned package
   the output is byte-identical to the committed files.
3. Run `python tools\brand\fluent-icons\check_iconset.py` (every name the program uses exists in both folders,
   no colour the image lists treat as transparent, the paths parse with the vendored nanosvg) and `saltests`
   (`TestIconSet416` rasterizes every file at 16 / 20 / 24 / 32 px and checks coverage and contrast).

## What the generator does

- `MAP`: button name (the `SVGName` of `ToolBarButtons[]` in `src/toolbar4.cpp`, or the Fluent names of
  `src/common/saliconset.h`) -> Fluent icon (16 px regular; a few 20 px ones are scaled) and a colour role.
- Roles and palettes (`PAL`, `ROLES`): ink, blue, red, green, folder, document, archive, blue duotone, drive.
  Duotone roles draw the `_filled` glyph underneath as a tint and the `_regular` outline on top.
- Legibility on the dark blue menu highlight: outline icons get a paper underlay (their `_filled` shape in the
  paper colour) or, where a filled shape would change the meaning (`NO_PAPER`: arrows, letters, lines), a thin halo.
- Own drawings on the Fluent grid: the console `>_` (no 16 px Fluent glyph), the `..` symbol of the file list
  (today's shape: an angular up arrow whose stem turns right and two square dots) and the Network composite
  (Fluent desktop + globe badge).
- Never used as a colour: `#FF00FF`, `#F0F0F0`, `#2D2D2D` (the image lists' transparent keys).

The mapping, palettes and drawings come from the maintainer's design study of 2026-11-07 (blind recognition and
paired comparisons of 80 commands: meaning better 52 / worse 14 / equal 14, dark-bar legibility 65 / 2 / 13).
