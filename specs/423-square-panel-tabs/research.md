# Research - 423 square panel tabs

## R1 - Where the tab shape is painted

- Decision: one branch in `CTabWindow::PaintTabBack` (`src/tabwnd.cpp`). Square: the active tab is
  `TabFillSolid` of `{r.left, TextTop(), r.right + 1, Height}` in `TabPaint.CapBk`; the hover is
  the same rectangle in `TabPaint.Strip.HoverBk`. Rounded: the 404 paths unchanged.
- Rationale: `PaintTabBack` is the only place that draws a tab's background (active, hover, the
  dragged tab: `Paint` calls it for each); text, icon, close glyph and + are drawn by
  `PaintTabFront` / `PaintPlus` independently of the shape. A GDI fill is exact (no AA edge).
- The square hover covers the whole tab (top of the content band to the strip's bottom), the same
  box as the active tab: a flat strip shows the tab's own box on hover (the pill's inset only made
  sense as a rounded shape). The mockup shows no hover; the item asks for a rectangle.
- Alternatives: a square pill with the pill's insets (looks like a button, not a tab); a nanosvg
  rectangle path (AA of axis-aligned integer edges gives the same pixels, slower).

## R2 - The left inset

- Decision: `TABSTRIP_LEFT` (8 px) stays in both styles.
- Rationale: switching the style must move nothing (FR-006); the item's *Approach* says so.

## R3 - The stored value

- Decision: `Panel Tab Style`, REG_DWORD under the configuration key; 0 = Square, 1 = Rounded;
  read quietly (`GetValueAux(..., TRUE)`); missing / wrong type -> 0 kept as Square; the number read
  is kept in `Configuration.PanelTabStyle` and mapped by `SalTabStyleFromStored`; the page writes
  the value only when the user changed the choice (416's rule: a later version's value survives).
- Rationale: the same pattern as `Toolbar Icon Set` (416), measured and reviewed there.
- Read only in `LoadConfig` (not early as the icon set): nothing paints a strip before
  `LoadConfig`, and a settings import goes through `LoadConfig` + `CCfgRefreshState`.

## R4 - Applying the change

- Decision: `CCfgRefreshState` captures `PanelTabStyle`; `RefreshAfterConfiguration` repaints both
  strips (`CFilesWindow::UpdateTabStrip`) when the mapped style changed.
- Rationale: the strip reads the style at every paint; no layout change is needed.

## R5 - Room on the Appearance page

- Measured: every Configuration page is 299 x 231 du and the holder dialog is sized to the largest
  page (`CTreePropDialog`, `src/common/sheets.cpp`, `maxPageRect`): a taller Appearance page would
  make the whole dialog taller. The *Icon style* group ends at y 229.
- Decision: move the *Thumbnails* group (30 du tall, one "Size: [n] pixels" row) beside the *Panel
  Font* group (its read-only font edit narrowed from 224 to 125 du), which frees 36 du; *Content of
  Information Line* and *Icon style* move up, and the *Tab style* group (radios side by side) goes
  directly below *Icon style*, all within 231 du.
- Alternatives: a taller page (grows the whole dialog for all 31 pages); *Tab style* beside *Icon
  style* (not "below" as the maintainer asked); the *Tabs* page (the maintainer asked for
  Appearance).

## R6 - Light-theme legibility

- Measured at 75efd1ac (tabs413_probe THEME capture): strip DEDEDE, inactive title 545454
  (`SalTabMix(text, StripBk, 0.38)`) = 5.63:1; the active title 000000 on 99B4D1 = 9.80:1.
- Decision: Light (not Dark, not High Contrast) mixes the text 20 % toward the strip: 2C2C2C =
  10.38:1, still lighter than the active / hovered title (000000). The + glyph uses the same colour.
- Rationale: clearly above WCAG AAA (7:1) while keeping the active/inactive hierarchy; with custom
  system colours the mix keeps the same relation. Dark (B3B3B3 on 242424) stays as 413 measured.
- Alternatives: 0.30 (434343, 7.35:1 - barely AAA); pure text colour (no hierarchy).
