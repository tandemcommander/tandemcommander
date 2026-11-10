# Feature Specification: Square panel tabs as the new default; rounded tabs kept as an Appearance option

**Feature Branch**: `423-square-panel-tabs`  
**Created**: 2026-11-10  
**Status**: Draft  
**Input**: User description: "Backlog item square-panel-tabs-as-the-new-default-rounded-tabs-kept-as-an - implement exactly what it describes; in the same run, improve the legibility of the tab strip in the Light theme (maintainer, 2026-11-10)." From backlog item square-panel-tabs-as-the-new-default-rounded-tabs-kept-as-an.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Square tabs by default (Priority: P1)

A user starts Tandem Commander with panel tabs on. The active tab of each panel is a plain
rectangle that runs straight into the directory line below it - no rounded top corners and no
rounded "feet" where it meets the directory line (the maintainer's mockup `flat_tabs.png`).
Hovering an inactive tab highlights it with a rectangle, not a rounded pill.

**Why this priority**: it is the new look the maintainer asked for and it applies to every user
who never changes the setting.

**Independent Test**: start with a configuration that has no tab-style value (fresh or upgraded
from 0.3.0); capture the tab strip; the active tab's top corners and the strip pixels next to its
bottom corners show the tab's fill or the strip background exactly as a rectangle does.

**Acceptance Scenarios**:

1. **Given** a configuration without a tab-style value, **When** the program starts, **Then** the
   active tab of both panels is drawn as a rectangle from its top to the bottom of the strip.
2. **Given** square tabs, **When** the mouse hovers an inactive tab, **Then** the hover highlight
   is a rectangle.
3. **Given** square tabs, **When** the user switches the theme (Light / Dark) or the DPI, **Then**
   the tabs stay square, with the colours of that theme.

---

### User Story 2 - Rounded tabs as a choice (Priority: P1)

A user who prefers the look of 0.3.0 opens *Options > Configuration > Appearance*, finds a *Tab
style* group directly below *Icon style*, chooses *Rounded* and presses OK. The tabs at once look
as they did before this feature; the choice survives a restart. Choosing *Square* again brings the
square look back.

**Why this priority**: the maintainer asked that the rounded look stays available.

**Independent Test**: set the value through the page, press OK, capture; restart, capture again.

**Acceptance Scenarios**:

1. **Given** square tabs, **When** the user chooses *Rounded* and presses OK, **Then** the strips
   repaint with the rounded active tab with feet and the rounded hover pill, without a restart.
2. **Given** *Rounded* chosen, **When** the program is restarted, **Then** the tabs are rounded
   and the page shows *Rounded* selected.
3. **Given** the page open, **When** the user changes the choice and presses Cancel, **Then**
   nothing changes.

---

### User Story 3 - Legible tab titles in the Light theme (Priority: P2)

In the Light (default) theme the titles of inactive tabs and the + glyph are drawn noticeably
darker than today (545454 on DEDEDE, 5.63:1), so that they read easily, while they stay a step
lighter than the title of the active or hovered tab.

**Why this priority**: the maintainer asked for it together with the new look; it affects every
Light-theme user, in both tab styles.

**Independent Test**: capture the strip in the Light theme; the most contrasting pixel of an
inactive tab's title reaches at least 7:1 against the strip background; the Dark theme's pixels
are unchanged.

**Acceptance Scenarios**:

1. **Given** the Light theme, **When** the strip is painted, **Then** an inactive title reaches at
   least 7:1 against the strip background and is lighter than the active title.
2. **Given** the Dark theme or High Contrast, **When** the strip is painted, **Then** the inactive
   title colour is exactly as before this feature.

---

### Edge Cases

- A stored tab-style value that this version does not know (written by a later version) or of a
  wrong type: the tabs are square and the stored value is kept; it is overwritten only when the
  user changes the choice on the page.
- A settings import (*Import Settings*, a `-C` configuration file) that carries a tab-style value:
  the strips show the imported style after the import, as with the icon style (416).
- Panel tabs switched off (Configuration > Tabs): the setting is still shown and stored; nothing
  is painted until tabs are on again.
- A dragged tab is drawn in the chosen style (square in Square, rounded in Rounded).
- High Contrast: the shape follows the chosen style; colours stay the High Contrast colours.
- The Appearance page in every enabled language: the new group and its labels fit without
  clipping.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: *Options > Configuration > Appearance* MUST show, directly below the *Icon style*
  group, a *Tab style* group with two radio buttons: **Square** and **Rounded**.
- **FR-002**: With **Square**, the active tab MUST be painted as a filled rectangle covering the
  tab's width from the tab's top row to the strip's bottom row (no arcs, no feet), and the hover
  highlight of an inactive tab (also the dragged tab) MUST be a filled rectangle.
- **FR-003**: With **Rounded**, the strip MUST be painted exactly as before this feature (apart
  from FR-007's Light title colour).
- **FR-004**: **Square** MUST be the default: a configuration without the value, with a value of a
  wrong type or with a value this version does not know MUST give square tabs.
- **FR-005**: The choice MUST be stored with the configuration, read at start, and applied to both
  panels' strips at once when the page is confirmed with OK, and after a settings import - without
  a restart. A value the user did not change on the page MUST NOT be rewritten (a later version's
  value survives).
- **FR-006**: The tabs' positions, sizes, icons, titles, separators, close glyph and + glyph MUST
  stay where they are in both styles (switching the style moves nothing).
- **FR-007**: In the Light theme (not Dark, not High Contrast) the inactive tab titles and the +
  glyph MUST reach at least 7:1 contrast against the strip background with the default system
  colours, and MUST remain lighter than the active / hovered title; in the Dark theme and under
  High Contrast their colour MUST be unchanged.
- **FR-008**: The new texts MUST be translated in every enabled language (formal register) and
  fit on the page.

### Key Entities

- **Tab style**: the user's choice of the panel tab look - Square (default) or Rounded; one value
  for the whole program (both panels).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With a configuration that never stored the value, 100 % of the strips captured at
  start show a rectangular active tab: the pixels at its four corners (top-left, top-right, and the
  bottom row just inside the tab) are the tab's fill, and the strip pixels just outside its
  bottom corners are the strip background (no feet).
- **SC-002**: With *Rounded* chosen, the captured strip is identical, pixel for pixel in the tab
  shapes, to the strip of the build before this feature (same corner and foot pixels).
- **SC-003**: Changing the style on the page and pressing OK changes the captured strips within
  one repaint, without a restart; the choice survives a restart (round trip of both values).
- **SC-004**: In the Light theme, an inactive tab title's most contrasting pixel reaches at least
  7:1 against the strip (today 5.63:1); the Dark theme's inactive title colour is unchanged.
- **SC-005**: The Appearance page shows the new group without clipping in all 8 enabled
  languages.

## Assumptions

- Assumption (autonomous run): the hover highlight follows the tab style (rectangle in Square) -
  the mockup shows no hover; the item's *Expected* asks for it.
- Assumption (autonomous run): the strip keeps its left inset (room the rounded tab's left foot
  needs) in both styles, so switching the style moves no tab (item *Approach*).
- Assumption (autonomous run): the setting is a new value under the existing configuration key,
  like the icon style of 416; it changes no public claim (`PRIVACY.md` describes settings in
  general).
- Assumption (autonomous run): the Light-theme legibility is improved by darkening the inactive
  titles and the + glyph only; the strip background, the active tab's fill and the Dark theme stay
  as they are (the measured weak point was the 5.63:1 inactive title).
- The Appearance page grows to make room for the new group (the *Icon style* group already ends at
  the page's bottom).
