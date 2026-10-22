# Feature Specification: Markdown Viewer - choose the page width in View, up to the full window

**Feature Branch**: `314-mdview-page-width`
**Created**: 2026-10-23
**Status**: Draft
**Input**: User description: "Backlog item mdview-page-width-levels - implement exactly what it describes." From backlog item mdview-page-width-levels.

## Measured at da0a455a (before any change)

- The generated page limits the text column to `max-width:46rem`; a rule for a full-width class
  exists in the stylesheet but nothing ever applies it (both the rendered and the View Source page
  emit only `markdown-body`).
- The View menu has no width command; the plug-in configuration has no width value.
- The generator harness (`tests/mdview_htmlgen_test/build_and_run.cmd`): 38 passed, 0 failed,
  among them "reading measure" (the 46rem limit).
- A color-scheme change rebuilds the page and navigates to a new document version with no
  fragment; the page runs with scripts off (feature 021 lockdown) and the shared WebView2 host
  exposes no scroll position, so the rebuilt page opens **at the top**. View Source and Load
  Remote Images behave the same way. A scheme change therefore does not keep the reading
  position today.
- The manual has no Markdown Viewer page.

## Clarifications

### Session 2026-10-23

- Q: Do the page-width levels get keyboard shortcuts? → A: No; the levels are chosen from the menu only (autonomous run: conservative - the item leaves keys to the spec, the viewer's free Ctrl keys are not obvious, and no key of today changes).
- Q: Does a choice in one viewer window rebuild the other open viewer windows? → A: No; only the window where the level was chosen is rebuilt; the stored level applies to windows opened afterwards (autonomous run: conservative - a rebuild opens a page at the top, so rebuilding other windows would move their reading position).
- Q: Must the width change keep the reading position when a scheme change does not? → A: It behaves exactly like a scheme change (FR-009); keeping the position across every rebuild needs the shared host and is a new Inbox item (autonomous run: item - its note keeps the change out of `src/common/webhost/`, and it asks to measure what a scheme change does).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Widen the text column of an open document (Priority: P1)

A user reads a Markdown document with wide tables or long code lines in a large viewer window.
They open View > Page Width and choose a wider level (Wide, Wider or Full Window). The page is
shown again at once with the wider column; tables, code blocks and images use the new width.

**Why this priority**: it is the whole value of the item - today the column cannot be widened.

**Independent Test**: open a document with a wide table in a wide window, choose each level and
compare the width of the text column; the menu shows the chosen level checked.

**Acceptance Scenarios**:

1. **Given** a document open with the default settings, **When** the user opens View > Page
   Width, **Then** four radio items are shown - Normal, Wide, Wider, Full Window - and Normal is
   checked.
2. **Given** the document open at Normal, **When** the user chooses Wide, **Then** the page is
   rebuilt with a column limited to 64rem and Wide is checked.
3. **Given** the document open, **When** the user chooses Wider, **Then** the column is limited to
   90rem; **When** Full Window, **Then** the column has no width limit and the page padding stays.
4. **Given** Full Window and a window wider than a wide table, **When** the page is shown,
   **Then** the table is not cut and needs no horizontal scroll.
5. **Given** View Source is on, **When** the user chooses a level, **Then** the source page uses
   the same width.

---

### User Story 2 - The chosen width is remembered (Priority: P2)

The level the user chose is stored in the plug-in configuration, so the next document - also
after the program is restarted - opens with it.

**Why this priority**: without it the user would have to choose the width for every document.

**Independent Test**: choose Wider, close the viewer, open another document: Wider is checked
and used; restart the program: still Wider.

**Acceptance Scenarios**:

1. **Given** the user chose Wider, **When** another document is opened, **Then** it opens with
   Wider checked and applied.
2. **Given** the configuration was saved with Wider, **When** the program starts again and a
   document is opened, **Then** Wider is checked and applied.
3. **Given** the configuration has no width value or an unknown one, **When** a document is
   opened, **Then** Normal is used and checked.

---

### User Story 3 - Nothing changes for a user who changes nothing (Priority: P1)

A user who never opens the submenu sees exactly the page of today: the 46rem column, the same
padding, the same tables, code blocks and images.

**Why this priority**: decided with the maintainer - the current width stays the default.

**Independent Test**: render a document with the default settings and compare with the page of
today: the column limit is 46rem and the article carries no width class.

**Acceptance Scenarios**:

1. **Given** default settings, **When** a document is shown, **Then** the column is limited to
   46rem as before.

---

### Edge Cases

- A stored width value that is not 0-3 (corrupt, written by a later version) reads as Normal.
- A stored value of the wrong registry type is not read; Normal stays.
- Two viewer windows open: choosing a level in one rebuilds only that window; the other keeps its
  page and its own check mark until it is rebuilt or closed; documents opened afterwards use the
  last chosen level.
- Zoom keeps working with every level (the width scales with the text as before).
- A find in progress keeps working after a width change (the find marks are rebuilt with the
  page, as for a scheme change).
- The dark menu rendering shows the radio check of the submenu.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The View menu MUST offer a submenu *Page Width* right after *Color Scheme* with four
  radio items: *Normal* (46rem, the default), *Wide* (64rem), *Wider* (90rem), *Full Window* (no
  width limit, the page padding unchanged); the level in use MUST be checked.
- **FR-002**: Choosing a level MUST rebuild the open document at once with the chosen column width,
  in the rendered view and in View Source.
- **FR-003**: Tables, code blocks and images MUST keep their rule of today - at most the width of
  the column - so they follow the chosen level.
- **FR-004**: The level MUST be stored in the plug-in's configuration as a new value next to
  `ZoomPercent`; a missing, unreadable or unknown value MUST read as *Normal*.
- **FR-005**: A document opened after a choice (in a new viewer window, also after a restart) MUST
  open with the last chosen level.
- **FR-006**: With *Normal* the generated page MUST give the article the same column limit (46rem)
  and padding as before the feature.
- **FR-007**: The new menu texts MUST be in the plug-in's language module; translation into the
  enabled languages goes through the two-stage `.slt` refresh.
- **FR-008**: `IMPLEMENTATION_NOTES.md` MUST describe the page-width levels instead of the unwired
  "full-width toggle".
- **FR-009**: After a width change the rebuilt page MUST behave exactly as after a color-scheme
  change (the same rebuild, the same position handling).
- **FR-010**: The change MUST stay inside the plug-in (its generated page, menu and
  configuration): no change to the shared WebView2 host, the plug-in interface or `PRIVACY.md`.

### Key Entities

- **Page width level**: one of Normal, Wide, Wider, Full Window; stored as a number 0-3; maps to a
  column limit (46rem, 64rem, 90rem, none).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Each of the four levels can be chosen from View > Page Width in two clicks and is
  checked afterwards (probe: menu items and check state per level).
- **SC-002**: In a window wider than 90rem the rendered column width grows from Normal to Wide to
  Wider to Full Window (probe row per level, or a person's check where the probe cannot read the
  page).
- **SC-003**: The chosen level survives closing the viewer and restarting the program (probe:
  stored value and the check after restart).
- **SC-004**: With default settings the generated page keeps the 46rem limit (generator harness),
  and the feature 081 smoke checks of `mdview_probe.ps1` still pass.

## Assumptions

- Assumption (autonomous run): the levels are exactly the item's example - Normal 46rem, Wide
  64rem, Wider 90rem, Full Window none - and they get no keyboard shortcuts (no free, obvious key;
  the item leaves keys to the spec; conservative: no new keys).
- Assumption (autonomous run, item note + measurement): the item asks to keep the reading
  position "measure what a scheme change does today". The measurement shows a scheme change
  opens the rebuilt page at the top, because the page has scripts off and the shared host offers
  no scroll position; keeping the position would need a change in `src/common/webhost/`, which
  the item's note rules out. A width change therefore behaves exactly as a scheme change (FR-009),
  and keeping the reading position across every rebuild (scheme, width, View Source, remote
  images) is recorded as a new Inbox item.
- Assumption (autonomous run): the manual has no Markdown Viewer page, so there is no page to
  extend; writing a whole manual page for the plug-in is outside this item and is recorded as a
  new Inbox item.
- Assumption (autonomous run, conservative): the width is a per-window state taken from the stored
  level when the window opens; a choice changes that window and the stored level, other open
  windows are not rebuilt (a rebuild would move their reading position).
- Assumption (autonomous run): the stored value is named `PageWidth` (REG_DWORD), in the
  plug-in's existing registry key; nothing new leaves the machine.
