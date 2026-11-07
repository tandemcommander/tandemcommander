# Research - 416 Fluent icon set

## R1. Does the vendored nanosvg parse the Fluent 2 files?

- Decision: use the study's files unchanged.
- Rationale: the vendored `nsvg__getNextPathItem` reads arc flags as ordinary numbers (no merged-flag support). An
  emulation of its tokenizer over all 190 files (`tools/brand/fluent-icons/check_iconset.py`, first as a scratch
  script) found 0 arcs with merged flags and 0 leftover arguments. The generator excludes gradients, masks, clip
  paths, filters, `<use>`, `<image>`, `<text>`; `<g fill>`, `<g transform="scale()/translate()">`, `<rect rx>`,
  `<circle>` and round stroke joins are supported by nanosvg. Offline rasterization in `saltests` confirms coverage.
- Alternatives: re-serializing paths without arcs (unneeded).

## R2. Pixel format of the rasterizer

- Decision: treat the rasterized buffer as premultiplied, DIB-ordered BGRA (as `RenderSVGImage` already does with
  `AlphaBlend(AC_SRC_ALPHA)`); un-premultiply before `CreateIconIndirect`.
- Rationale: the project's modified `nanosvgrast.h` leaves out `nsvg__unpremultiplyAlpha` ("AlphaBlend wants
  premultiplied"). The study's 0.1.10 screenshot (`assets/screens/bars-light-0.1.10.png`) shows `#00539C` and
  `#DCB47A` exactly as written in the SVGs, so the channel order is DIB-correct.

## R3. Where the set takes effect

- Decision: the theme switch's pipeline `ColorsChanged(TRUE, FALSE, TRUE)`.
- Rationale: it rebuilds the toolbar image lists (`InitializeGraphics`), the `..` icon (`!colorsOnly` block), the drive
  bars (`RebuildDrives`), the panels' drive icons (`CFilesWindow::OnColorsChanged` -> `UpdateDriveIcon`), the tab icon
  cache (`ClearIcons`, feature 404) and the configuration-list toolbars are created per dialog. The Configuration
  dialog has no Apply button (`PSH_NOAPPLYNOW`), OK runs `RefreshAfterConfiguration`, also used by the settings import.

## R4. Start-up order

- Decision: read the set in the early block that reads Theme Mode (`salamdr1.cpp`, before `InitializeGraphics`).
- Rationale: `InitializeGraphics(FALSE)` runs before `MainWindow->LoadConfig`; reading it only in `LoadConfig` would
  build the first image lists with the default set.

## R5. Folder layout

- Decision: Classic stays `src/res/toolbars/` -> `toolbars\`; Fluent 2 in `src/res/iconsets/fluent/` -> `iconsets\fluent\`.
- Rationale: the feature-029 override contract and its README keep their paths; an author's override in
  `toolbars\dark\` keeps working for Classic.

## R6. DPI evidence

- Decision: the GUI probe runs at the hidden desktop's system DPI; 125/150/200 % are covered by `saltests`
  rasterizing each file at 20/24/32 px with the program's rasterizer, and a release-checklist line for the look at the
  maintainer's scale.
- Rationale: the system DPI is fixed for the session; the hidden desktop cannot change it.

## R7. Classic pixel identity

- Decision: Classic keeps every call in the same order with the same arguments; the only change on its path is that a
  file that cannot be parsed or has no shapes no longer blanks the cell (no shipped Classic file is such a file).
- Evidence: the probe captures the toolbars in Classic before (build of `main`) and after and compares them.
