# Research - 418

## R1 What makes the Dark tabs look lower

- Measured (fix-log): the tab strip (29 px), the tabs (26 rows), the title's position in the tab (11 / 9 px) and
  everything below are the same in both themes. The default theme frames the strip from above with the rebar's
  etched border (2 px) and separates the band rows; Dark has neither (the rebar 69 vs 77 px), and its strip
  (242424) hardly differs from the face (2D2D2D), so the strip's frame is missing: 11 px from the visible top edge
  to the title against 13 px.
- **Decision**: give Dark the same rebar structure (border + band borders). **Rejected**: a 2-px padding at the
  top of the Dark strip (the strip would then differ in size from the default theme's; the window rows would still
  differ by 8 px); a single line below the rebar only (the toolbar area would still be 4 px shorter, the band rows
  unframed - clarification 1).

## R2 How to draw the rebar's lines dark

- Feature 028 (commit a65ac017) removed `WS_BORDER | RBS_BANDBORDERS` in Dark because the classic rebar drew them
  in the light system colours ("light-only 3D chrome").
- **Decision**: `RB_SETCOLORSCHEME` - the rebar's `COLORSCHEME` (`clrBtnHighlight`, `clrBtnShadow`) is what it
  uses for its 3D elements. Experiment on the live build (Dark, the scheme = `COLOR_BTNHIGHLIGHT` 464646 /
  `COLOR_BTNSHADOW` 1A1A1A of the Dark palette): rows 0-1, 25-26, 51-52, 75-76 = 1A1A1A / 464646 (the default theme:
  A0A0A0 / FFFFFF at the same rows), left / right columns 1A1A1A / 464646, the strip at 77-105 in both themes; the
  only A0A0A0 / FFFFFF pixels left in the Dark rebar lie inside toolbar icons (WSL penguin, one toolbar glyph).
  **Rejected**: a subclass that paints the frame and band borders itself (it would have to re-create the rebar's
  band geometry; more code, flicker risk).
- `CLR_DEFAULT` in the default theme = the system colours, i.e. the rebar as today.

## R3 Theme switch

- `OnColorsChanged` calls `ThemeUpdateRebarStyle` on every theme / colour change. The style no longer changes on a
  switch, so the function repaints the frame and the bands itself when the scheme changes
  (`RedrawWindow(..., RDW_FRAME)`); the band layout does not change (same styles).
