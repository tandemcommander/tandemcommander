# Research - 413

## R1 The slot rule at the left end

- **Decision**: moving left (`draggedLeft < from * width`), slot = ceil(draggedLeft / width)
  (tab j gives way once the left is at or below j widths); moving right unchanged
  (slot = floor(left / width), tab j gives way at or above j widths). Clamped to 0 .. count - 1.
- **Rationale**: the caller clamps the left to 0 .. (count - 1) * width; with "at or below" the left
  end 0 gives slot 0 and the right end gives count - 1 - both ends reachable, the rule symmetric.
  Only lefts equal to a multiple of the width (while moving left) get a different slot; every
  existing saltests value keeps its result (99 -> 1, 101 / 199 -> 2, -1 -> 0 for from 2).
- **Alternatives**: (a) treat a clamped left (0) as slot 0 in the caller - fixes the end only and
  leaves the asymmetry; (b) change the clamp to allow a left below the run - the dragged tab would
  be drawn outside the strip (404 "no tear-off"); (c) half-tab thresholds - changes the feel of
  every drag. Rejected.

## R2 What is "lower" in the dark theme

- **Decision**: it is the dark inactive panel's active tab: fill 2D2D2D on the strip 242424 (9) over
  the directory line band 2D2D2D (0); every height is equal (probe THEME rows). Fix by a colour
  rule, not a size.
- **Rationale**: measured at the maintainer's DPI (96: AppliedDPI 96, one 2560 x 1440 monitor at
  100 %). The default theme's weakest separation is the inactive panel's tab on the strip (31).
- **Alternatives**: (a) a darker dark strip (`Mix(face, shadow, 1.0)` = 1A1A1A) - changes both
  panels and every hover / dim colour and still leaves the inactive tab at 19 / 0; (b) an outline
  around the active tab - the default theme has none, so the looks would differ; (c) changing the
  dark inactive caption colour - it is a user colour of the scheme and also paints the directory
  line; (d) the dark rebar's 8 px (bands without borders) - outside the tab strip. Rejected.

## R3 The lift

- **Decision**: `SalTabActiveFill(capBk, capFg, stripBk, face, highContrast)`: capBk if both
  distances (largest channel) are at least 24 or under High Contrast; else the first
  `SalTabMix(capBk, capFg, k / 100)` for k = 1 .. 50 with both distances at least 24; none -> k = 50.
- **Rationale**: toward the caption text colour keeps the tab in the panel's caption colours (the
  text stays readable: it moves away from the fill only by the lift); hundredths give the smallest
  visible change; 24 < 31 leaves the default theme untouched. Dark inactive: 2D2D2D toward AAAAAA,
  k = 19 -> 454545 (24 from the face, 33 from the strip), lighter than the dark hover pill
  (383838): active stays more prominent than hover.
- **Alternatives**: a fixed dark colour (ignores user schemes); toward white (loses the scheme's
  tint). Rejected.

## R4 The 404 probe

- **Decision**: `tabs404_probe` LOOK-DARK INACTIVE compares with
  `evidence/variantF_dark_inactive_413.png` - the 413 capture, accepted only after checking that its
  difference from the mockup `variantF_dark_inactive.png` lies inside the active tab's rectangle.
  Every other 404 row keeps its mockup.
