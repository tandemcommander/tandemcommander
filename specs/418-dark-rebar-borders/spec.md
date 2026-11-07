# Feature Specification: Dark theme: panel tabs look lower than in the default theme

**Feature Branch**: `418-dark-rebar-borders`
**Created**: 2026-11-07
**Status**: Draft
**Input**: User description: "Backlog item dark-theme-panel-tabs-look-lower-than-in-the-default-theme (backlog/items/dark-theme-panel-tabs-look-lower-than-in-the-default-theme/desc.md) - implement exactly what it describes." From backlog item dark-theme-panel-tabs-look-lower-than-in-the-default-theme.

## Clarifications

### Session 2026-11-07

- Q: Does Dark get only the line that frames the tab strip, or the whole structure of the toolbar area (its frame and the lines between band rows)? → A: the whole structure, so that every row of the Dark window is where the default theme has it; a frame line only below the toolbar area would still leave the Dark toolbar area 4 px shorter and the window different (autonomous run: item - "the same in both themes", Approach)
- Q: Which colours draw the Dark lines? → A: the Dark palette's counterparts of the light etched pair - COLOR_BTNSHADOW (1A1A1A) where the light theme has A0A0A0 and COLOR_BTNHIGHLIGHT (464646) where it has FFFFFF (autonomous run: rule - the Dark palette, `themes_palette.h`)
- Q: Do the band grips appear in Dark too? → A: no - grips stay light-only as feature 028 decided; only the borders return (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The tabs look the same in both themes (Priority: P1)

A user switches between the default (light) theme and the Dark theme. The panel tabs - their strip, the space
above and below a tab's title, the line that frames the strip from above - look the same in both; nothing in the
Dark window sits higher or lower than in the light one, only the colours differ.

**Why this priority**: the maintainer's request; the Dark tabs look lower although their own size is equal,
because the frame above them is missing.

**Independent Test**: start the program in each theme on the same window size and capture the rows from the top
of the toolbar area to the directory line; the rows of the Dark window are at the same positions as the light
ones, and the Dark theme has a dark frame line where the light theme has its etched line.

**Acceptance Scenarios**:

1. **Given** the Dark theme, **When** the window is drawn, **Then** the tab strip starts at the same row as in the
   default theme, and the space from the frame line above the strip to a tab's title is the same (13 px at 96 DPI).
2. **Given** the Dark theme, **When** the toolbar area (menu, toolbars, drive bar) is drawn, **Then** it is
   divided and framed by lines at the same rows as in the default theme, drawn in the Dark palette's colours (no
   light line on the dark background).
3. **Given** the default theme, **When** the window is drawn, **Then** it is pixel-identical to the build of `main`.
4. **Given** a switch of the theme while the program runs (in either direction), **When** the window is redrawn,
   **Then** it equals a fresh start in the target theme.

---

### User Story 2 - Toolbar area layout stays correct (Priority: P2)

A user who shows, hides, moves or resizes the toolbars (top toolbar, plugins bar, user menu bar, drive bars, hot
path bar, the second drive bar) in the Dark theme sees them laid out the same as in the default theme, with the
frame lines between them, and no light pixels.

**Why this priority**: the lines belong to the whole toolbar area; a gap or a stray light line would be a new
visual defect.

**Independent Test**: in the Dark theme with additional toolbars shown, capture the toolbar area; every line
between the bands is the Dark palette's, at the rows the default theme uses.

**Acceptance Scenarios**:

1. **Given** the Dark theme with the Plugins bar and the second drive bar shown, **When** the window is drawn,
   **Then** the band rows and the lines between them are at the same rows as in the default theme with the same
   bars, and no line of the toolbar area has the light etched colours.

### Edge Cases

- High contrast mode: the program uses the system theme then (`IsDarkThemeActive` is false) - unchanged.
- Bands on one row side by side (e.g. top toolbar and plugins bar): the vertical band borders are drawn in the
  Dark colours too.
- The window resized narrower: the bands of one row shrink (a rebar moves a band to a new row only by its break
  flag or a drag, measured), and the lines follow the resized bands.
- A theme switch at run time: the rebar's style and its painting change without a restart.
- Grips (Configuration "Show grips") stay light-only, as feature 028 decided.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: In the Dark theme the toolbar area MUST have the same layout as in the default theme: the same frame
  around it and the same separation between band rows (and between bands of one row), so that the tab strip and
  everything below start at the same rows.
- **FR-002**: In the Dark theme those frame and separator lines MUST be drawn in the Dark palette's colours (the
  Dark counterparts of the light theme's etched shadow and highlight); no light line may appear.
- **FR-003**: The panel tab strip, its tabs, their titles, the directory line and the file list MUST keep their
  sizes in both themes (they are equal already).
- **FR-004**: The default theme MUST stay pixel-identical to the build of `main`.
- **FR-005**: A theme switch at run time MUST give the same result as a fresh start in the target theme.
- **FR-006**: The Dark lines MUST be repainted correctly when the toolbar area changes (bars shown / hidden /
  moved, the window resized).

### Key Entities

- **Toolbar area (rebar)**: the menu, top toolbar, plugins bar, user menu bar, drive bars and hot path bar in bands
  and rows; framed by an etched border and separated by etched band borders in the default theme.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: At 96 DPI the Dark window's rows from the toolbar area's top to the directory line are at the same
  positions as the default theme's (today: Dark rebar 69 px vs 77 px, the strip 8 px higher) - 0 px difference.
- **SC-002**: The space from the line framing the tab strip to a tab's title is the same in both themes (13 px to
  the title text at 96 DPI; Dark today: 11, no line); the probe compares the absolute row of a tab's first content.
- **SC-003**: No frame or separator line of the Dark toolbar area has the light etched colours (A0A0A0, FFFFFF);
  only the content of toolbar icons may contain such pixels.
- **SC-004**: The default theme's window is 0 px different from the build of `main`.
- **SC-005**: A run-time theme switch equals a fresh start in the target theme (0 px in the toolbar area and the
  tab strip).

## Assumptions

- Assumption (autonomous run): "the same in both themes" is achieved by giving the Dark toolbar area the default
  theme's structure (frame and band borders) in Dark colours - the measurement shows the tab strip itself is
  already equal and the difference is the missing frame above it; the maintainer's request (2026-11-07) overrides
  feature 413's recorded limit "the dark rebar (69 vs 77 px, bands without borders) is unchanged".
- Feature 028 removed the rebar's border and band borders in Dark only because the control drew them in light
  colours ("light-only 3D chrome", commit a65ac017); drawing them in Dark colours keeps its intent (no light lines).
- Other display scales than the hidden desktop's (96 DPI) are covered by the same layout rule (the rebar's border
  sizes are the system's in both themes); a check at 125-200 % is a release-checklist line.
