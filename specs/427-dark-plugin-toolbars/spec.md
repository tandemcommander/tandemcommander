# Feature Specification: Plug-in toolbars and chrome in the Dark theme

**Feature Branch**: `427-dark-plugin-toolbars`
**Created**: 2026-11-12
**Status**: Draft
**Input**: From backlog item tmavy-motiv. GitHub issue #25 ("Tmavý motiv"): in the Dark theme, plug-in windows are only partly dark - black checkbox labels (PictView settings, Batch Rename), old toolbar icons not made for a dark background (PictView, File Comparator), parts of some windows stay light grey.

## Clarifications

### Session 2026-11-12

- Q: Does FR-003 cover File Comparator's combo box ("Difference" list) and the scrollbars of its two views, or only the rebar strip? → A: all of its chrome that stays light grey in the measurement - the rebar strip, the band text area, the splitter, the combo box and the view scrollbars; the two text views keep their own configurable colours (autonomous run: item - "no light-grey area remains in those windows").

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Readable toolbar icons in PictView and File Comparator (Priority: P1)

A user of the Dark theme opens an image in PictView or compares two files in File Comparator.
The toolbar icons are readable on the dark toolbar: outlines and dark shading are drawn light, as
the core does for its own legacy (Classic) glyphs in Dark.

**Why this priority**: the icons are the part of the report that reproduces on every Windows
build; the dark outlines and the blue arrows are nearly invisible today.

**Independent Test**: a hidden-desktop probe opens the PictView viewer and File Comparator in Dark
and counts, in each toolbar's capture, the glyph pixels darker than the toolbar background; it
drops to (nearly) zero. In the Default theme the toolbars are pixel-identical to before.

**Acceptance Scenarios**:

1. **Given** the Dark theme, **When** a PictView viewer window opens, **Then** its toolbar glyphs
   (normal and hot) use the Dark palette (no glyph pixel darker than the toolbar background except
   at most a few anti-aliasing pixels).
2. **Given** the Dark theme, **When** File Comparator opens, **Then** its toolbar glyphs use the
   Dark palette likewise.
3. **Given** the Default theme, **When** either window opens, **Then** the toolbars look exactly as
   before.

---

### User Story 2 - No light-grey areas in File Comparator (Priority: P1)

A user of the Dark theme compares two files. The toolbar strip (rebar band, its "Difference" label
area, the splitter) is dark, not the classic light grey.

**Why this priority**: the reporter names light-grey parts; File Comparator shows 70,781 px of
`#F0F0F0` in Dark today.

**Independent Test**: the probe counts light-grey (`#F0F0F0`-like) pixels in the File Comparator
window outside the two text views; the count drops to (nearly) zero in Dark and is unchanged in
the Default theme.

**Acceptance Scenarios**:

1. **Given** the Dark theme, **When** File Comparator shows two files, **Then** no large area of the
   classic light grey remains in its window chrome.
2. **Given** the Default theme, **Then** File Comparator looks as before.

---

### User Story 3 - Readable checkbox labels in plug-in windows (Priority: P2)

The checkbox labels in PictView's settings and in Batch Rename draw light on the dark background,
as in the core's Configuration.

**Why this priority**: not reproduced on the measuring machine (all labels light there); it
depends on the reporter's Windows build, which is not known. The probe keeps it measured so that a
regression is seen.

**Independent Test**: the probe measures every checkbox label of PictView's five settings pages and
Batch Rename against its background (contrast at least 4.5:1).

**Acceptance Scenarios**:

1. **Given** the Dark theme on the measuring machine, **When** PictView's settings (all pages) and
   Batch Rename are shown, **Then** every checkbox label has a contrast of at least 4.5:1 to its
   background.

### Edge Cases

- A user switches between Default and Dark while a viewer is open: the open window keeps the
  glyphs it was built with until it is opened again (as before 427; the Default theme never gets
  Dark glyphs).
- The magenta (or mapped background) key colour of a toolbar bitmap must stay untouched so the mask
  stays right.
- The 16-colour and the 256-colour PictView bitmaps (the core decides which).
- PictView's histogram window shares the viewer's image lists.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: In the Dark theme, PictView's viewer toolbar (normal and hot image lists, also used
  by its histogram window) MUST show its glyphs in the Dark palette - the same colour adaptation the
  core applies to its legacy glyphs (feature 028/029).
- **FR-002**: In the Dark theme, File Comparator's toolbar glyphs MUST use the same Dark palette.
- **FR-003**: In the Dark theme, File Comparator's window chrome (rebar band background, the band
  text area, the splitter fill, the static text background, the "Difference" combo box and the
  scrollbars of the two views) MUST use the theme's colours instead of the classic light-grey
  system colours; the text views keep their own configurable colours.
- **FR-004**: In the Default theme all of the above MUST stay pixel-identical to before; the Classic
  icon set is never restyled beyond what the core already does in Dark.
- **FR-005**: The change MUST NOT change the plug-in interface (no new interface function, no
  version change); shared code used by plug-ins is header-only.
- **FR-006**: A hidden-desktop probe MUST measure: toolbar glyph pixels darker than the background
  (PictView, File Comparator), light-grey pixels in File Comparator, and the checkbox label contrast
  (PictView all pages, Batch Rename), in Dark and in Default; the registry is restored identical.
- **FR-007**: The checkbox-label part that does not reproduce MUST be recorded with what is needed
  to reproduce it (the reporter's Windows build) and the draft reply MUST ask for it.

### Key Entities

- **Toolbar bitmap**: a plug-in's legacy toolbar strip (16 × 16 cells, a key colour for the mask).
- **Dark palette adaptation**: the pure per-pixel rule of `ThemeDarkAdaptColor` (neutral dark →
  light, dark saturated → brighter hue, light colours unchanged).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In Dark, the neutral glyph pixels (outlines, shading) darker than the toolbar
  background drop by at least 90 % in PictView's and in File Comparator's toolbar; saturated colours
  the Dark palette keeps (as for the core's own Classic glyphs) are counted apart.
- **SC-002**: In Dark, File Comparator's light-grey pixels outside the text views drop from 70,781 to
  under 1 % of that.
- **SC-003**: In Default, the toolbars and File Comparator's chrome are pixel-identical before and
  after.
- **SC-004**: Every measured checkbox label keeps a contrast of at least 4.5:1 in Dark.

## Assumptions

- Assumption (autonomous run): the item's Expected allows "Fluent 2 with Dark variants, or at least
  the Dark palette applied"; the run applies the Dark palette (the conservative way: no new icon
  artwork, no icon-set change; the Classic set behaves as the core's legacy glyphs already do).
- Assumption (autonomous run): the black checkbox labels depend on the reporter's Windows build (on
  10.0.26300 a `DarkMode_Explorer` checkbox draws a light label in every case measured, and the
  reporter's screenshots show differently drawn checkbox glyphs also in the core); without that
  build the run changes no checkbox drawing (no fix without a reproduction) and records the part.
- Assumption (autonomous run): the reporter's unnamed light-grey areas are the ones measured in
  File Comparator; other windows showed none in the probe.
- A live switch of the theme while a plug-in window is open keeps the open window's glyphs (an
  existing limit of these windows, not widened).
