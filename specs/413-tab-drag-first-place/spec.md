# Feature Specification: Panel tabs - a drag reaches the first place; the dark strip looks as high as the default one

**Feature Branch**: `413-tab-drag-first-place`
**Created**: 2026-11-07
**Status**: Draft
**Input**: Backlog item `panel-tabs-drag-to-first-place-and-dark-strip-height` (Panel tabs: a drag cannot put a tab in the first place; dark strip looks lower) - implement exactly what it describes. From backlog item panel-tabs-drag-to-first-place-and-dark-strip-height.

## Measured at 75a45ea7 (before the change)

Probe `tabsfirst_probe` (hidden desktop, Debug x64 build of HEAD, registry backed up and restored
identical):

- **Drag**: left tabs A B C D, D dragged far past the left end of the strip -> A D B C (second
  place, expected D A B C); right tabs P Q R S, S dragged past the left end -> P S Q R; a scrolled
  strip of 30 tabs (8 visible, the first visible is index 22), T29 dragged to the left end of the
  run -> index 23 (expected 22).
- **Theme**: the session DPI is 96 (the maintainer's 2560 x 1440 monitor at 100 %). The tab strip is
  29 px and the directory line 23 px in both themes, and the active tab covers rows 3-28 of the strip
  in both themes, in the active and in the inactive panel - nothing is lower in pixels. The colours
  differ:

  | Theme / panel | active tab | strip | directory line band under the tab | tab vs strip | tab vs band |
  |---|---|---|---|---|---|
  | default / active | 99B4D1 | DEDEDE | F0F0F0 | 69 | 87 |
  | default / inactive | BFCDDB | DEDEDE | F0F0F0 | 31 | 49 |
  | dark / active | 264F78 | 242424 | 2D2D2D | 84 | 75 |
  | dark / inactive | 2D2D2D | 242424 | 2D2D2D | **9** | **0** |

  (largest channel difference). In the dark theme the inactive panel's active tab has the colour of
  the toolbar area above the strip and of the directory line's band below it: it has no visible
  shape and reads as a gap in the strip, so the strip looks lower. The dark rebar is 8 px lower than
  the default one (69 vs 77 px) because its bands draw no borders; it is not part of the tab strip.

## Clarifications

### Session 2026-11-07

- Q: In a strip that shows only a run of its tabs, is the "first place" index 0 or the run's first visible place? → A: the run's first visible place; the strip does not scroll during a drag (autonomous run: item - its *Evidence* names "the first visible tab of a scrolled strip")
- Q: What makes the dark strip "look lower", and what is changed? → A: not a size (measured equal); the inactive panel's active tab has no contrast to the strip and the directory line band - only that fill is lifted, by a colour rule, nothing else of the look changes (autonomous run: item *Approach* "if it is the dark active tab's contrast ... make the dark look match the default one"; conservative - changes least)
- Q: Should the dark rebar's 8 px (no band borders) be changed too? → A: no; it is outside the tab strip, recorded in the fix-log (autonomous run: conservative)
- Q: What does the 404 probe compare its dark inactive capture with after the change? → A: a 413 baseline image whose difference from the mockup is shown to lie only inside the active tab (autonomous run: conservative - the mockup stays as the maintainer made it)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drag a tab to the first place (Priority: P1)

A user with several tabs in a panel drags a tab that is not the first one to the left end of the
strip and releases it: the tab becomes the first tab. This works in the left and in the right
panel, and in a strip that shows only a run of its tabs (more tabs than fit), where the dragged tab
takes the first visible place.

**Why this priority**: reordering is the drag's purpose and the first place is the most common
target; today it cannot be reached at all except by dragging the first tab away.

**Independent Test**: four tabs, the last one dragged past the left end and released -> it is
first; the configuration saved by the program lists it first.

**Acceptance Scenarios**:

1. **Given** left tabs A B C D, **When** D is dragged to (or past) the left end of the strip and
   released, **Then** the order is D A B C.
2. **Given** right tabs P Q R S, **When** S is dragged to the left end and released, **Then** the
   order is S P Q R.
3. **Given** a strip showing a run of tabs starting at index k > 0, **When** the last visible tab is
   dragged to the left end of the run, **Then** it lands at index k and the other tabs keep their
   order.
4. **Given** a tab dragged left by a little more than one tab width in the middle of the strip,
   **Then** it moves exactly one place (the centre-over-centre rule is unchanged).
5. **Given** a tab dragged past the right end, **Then** it becomes the last (unchanged).

---

### User Story 2 - The dark tab strip looks like the default one (Priority: P2)

A user who switches between the default and the dark theme sees a tab strip of the same height
with the same shapes: in both panels, the active tab is a visible rounded tab standing out from the
strip and from the directory line under it.

**Why this priority**: a visible defect of the look, no function lost.

**Independent Test**: start in each theme, capture the main window, compare the strip height, the
rows the active tab covers and its contrast against the strip and the directory line band, in the
active and the inactive panel.

**Acceptance Scenarios**:

1. **Given** the default theme, **Then** nothing changes (pixel-identical to 404's look).
2. **Given** the dark theme and the active panel, **Then** nothing changes.
3. **Given** the dark theme and the inactive panel, **Then** its active tab differs from the strip
   and from the directory line band by at least 24 (largest channel), like the default theme's
   weakest pair (31).
4. **Given** either theme, **Then** the strip height and the active tab's rows are the same.

### Edge Cases

- Only one tab: no drag reorders anything (unchanged).
- The first tab dragged away and back to the left end: still lands first (unchanged).
- A drag whose cursor leaves the strip: the dragged tab is still clamped to the run; at the left end
  it takes the first place.
- High Contrast: colours are never mixed (unchanged); the tab keeps the caption colour.
- A user colour scheme whose caption colour is close to the strip or the face colour: the same
  lift applies (it is a rule on colours, not on the theme name).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A dragged tab whose left edge reaches the left end of the strip's run MUST take the
  run's first place; generally, moving left, tab j gives way once the dragged tab's left is at or
  below j tab widths from the run's left (symmetric to moving right, where tab j gives way once the
  left is at or above j widths).
- **FR-002**: Every other slot decision MUST stay as it is (the only changed inputs are lefts equal
  to a whole multiple of the tab width while moving left).
- **FR-003**: The slot rule's unit checks MUST drive the values the caller passes (a left clamped to
  0, a left equal to a multiple of the width, the run of a scrolled strip).
- **FR-004**: The strip MUST keep its height and the active tab its rows in both themes (already
  true, kept by a probe row).
- **FR-005**: The active tab's fill MUST be the caption background colour unless that colour is
  within 24 (largest channel) of the strip background or of the face colour (the directory line's
  band under the tab); then it MUST be the caption colour mixed toward the caption text colour by
  the smallest step (hundredths, at most halfway) that gives at least 24 from both - when no step
  does, the step that separates it best (the caption colour itself on a tie, review 2); under High
  Contrast it MUST stay the caption colour. The close glyph of the active tab MUST be computed on
  that fill.
- **FR-006**: The default theme and the dark theme's active panel MUST stay pixel-identical to the
  look of feature 404.
- **FR-007** (review 1): When the fill was lifted, the active tab's title MUST keep the contrast it
  has on the caption colour (at most 4.5:1 asked): the caption text colour, else mixed toward white
  (or black) by the smallest hundredth that gives it - toward the other pole when the first cannot
  (review 2).

### Key Entities

- **Slot rule**: count, tab width, dragged left relative to the run, the dragged tab's index -> the
  index it would take.
- **Active tab fill rule**: caption background, caption text, strip background, face, High Contrast
  -> the fill colour of the active tab.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe, a tab dragged to the left end lands first in 4 of 4 cases (left panel,
  right panel, a second drag in the left panel, scrolled strip), against 0 of 4 before; the
  controls (middle, right end) unchanged.
- **SC-002**: The probe's look rows pass for both themes and both panels (4 of 4, against 3 of 4
  before); the height rows pass (unchanged).
- **SC-003**: `tabs404_probe` and `tabs405_probe` keep passing, except the dark inactive capture of
  404, whose difference from the mockup lies only inside the active tab.

## Assumptions

- Assumption (autonomous run): in a scrolled strip the "first place" is the first place of the
  visible run (the strip does not scroll during a drag - feature 404's "no tear-off, within the
  visible run").
- Assumption (autonomous run): "looks lower" was measured as a look, not a size, at the maintainer's
  DPI (96, the only monitor of the session); the fix makes the dark inactive-panel tab visible, the
  measured cause. Other DPIs are a release-checklist line.
- Assumption (autonomous run): the dark rebar's 8 px (no band borders) is outside the tab strip and
  stays; it is recorded in the fix-log.
- Assumption (autonomous run): the minimum separation 24 is below the default theme's weakest pair
  (31), so the default theme is untouched with margin; the lifted dark colour (about 454545) is
  lighter than the dark hover pill (383838), keeping active > hover.
- The 404 evidence image `variantF_dark_inactive.png` (the maintainer's mockup) shows the old dark
  inactive tab; the 404 probe's row for it compares against a 413 baseline whose difference from
  the mockup is confined to the active tab.
