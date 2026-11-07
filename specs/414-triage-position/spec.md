# Feature Specification: Backlog app triage - choose the position when moving an item out of the Inbox

**Feature Branch**: `414-triage-position`
**Created**: 2026-11-07
**Status**: Draft
**Input**: Backlog item `backlog-app-triage-position-on-move-from-inbox` (Backlog app triage: choose the position when moving an item out of the Inbox) - implement exactly what it describes. From backlog item backlog-app-triage-position-on-move-from-inbox.

## Measured at db8da649 (before the change)

Read `tools/backlog-app/packages/web/src/features/triage/triage-page.tsx` (the triage page of the
backlog app, feature 344):

- **Accept** / key `n` places the item at the *suggested* place: the section that admits it by
  type and who (a decision -> *Decisions for the maintainer*, a person step or `who: person` ->
  *Person steps*, otherwise *Next*) at the position directly below the last item of at least the
  item's severity (`suggestPlacement`, `packages/shared/src/query/triage.ts`).
- **Decisions** / key `d` and **Person** / key `p` place the item at the **end** of that section -
  the page sends the move without a position.
- The AI proposal's button places the item where Claude proposed.
- There is **no control to choose a position**: an item cannot go into *Next* at any other place
  than the suggested one, nor into *Next* at all when the suggestion is another section, nor into
  *Decisions* / *Person steps* anywhere but at the end. The maintainer has to move it again on the
  item page or in the table afterwards.
- The server already takes a position in one move (`POST /api/items/:slug/move` with `position`
  runs one `backlog.sh move <slug> --section <s> --position <p>`; a position past the end appends
  the row). The limit is only in the triage interface.

## Clarifications

### Session 2026-11-07

- Q: Which sections can the triage place an item into at a chosen position? → A: the three ordered sections *Next*, *Decisions for the maintainer* and *Person steps* (autonomous run: item *Expected*)
- Q: What is the default position offered for a section? → A: the place `auto-triage` picks (`.claude/skills/tandem-backlog/reference.md` §4 *Position*): before the first row of the section whose severity is lower than the item's, the end when there is none, and after any row of the section the item depends on. The app's suggestion used another rule ("below the last item of at least its severity") that differs on a section not sorted by severity - the real *Next* is such a section (review of 414: a severity-5 item got 6 instead of 1); the suggestion now uses the same rule, so Accept and the chooser agree (autonomous run: item *Expected*; a finding fixed on the way, severity 2)
- Q: Do the existing one-key actions change (`n`, `d`, `p`)? → A: no; `n` still places at the suggested place, `d` and `p` still place at the end; the new chooser is added beside them (autonomous run: conservative - keeps the existing behaviour for every case the item does not name)
- Q: (found while implementing) May the chooser send an item to a section its type and who do not admit? → A: no; the backlog tool refuses such a move ("belongs in 'Next', not 'Person steps'; change type / who with 'set' first", measured), so the chooser shows the other sections disabled with that reason, and `d` / `p` are disabled for such an item instead of being refused after the click (a finding fixed on the way, severity 2); changing type / who stays on the item page (autonomous run: rule - the tool's admission rule; conservative - refuse in the page rather than send a move that is refused)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Place an Inbox item at a chosen position in one step (Priority: P1)

The maintainer triages the Inbox in the backlog app. For the item shown, they pick the target
section (*Next*, *Decisions for the maintainer* or *Person steps*), see a position already filled
in with the default for that section, change it if they want, and confirm. The item leaves the
Inbox and lands in that section at exactly that position, as one change of the backlog; the next
Inbox item is shown.

**Why this priority**: it is the whole item - today the same result needs a second move.

**Independent Test**: on a fixture backlog with items in *Next* and one Inbox item, open the
triage, choose *Next* and position 1, confirm; the tool lists the item first in *Next*, the Inbox
is empty, and the change tray holds one change.

**Acceptance Scenarios**:

1. **Given** an Inbox item and three items in *Next*, **When** the maintainer chooses *Next*,
   types position 2 and confirms, **Then** the item is the second item of *Next* and no longer in
   the Inbox, by one move of the backlog tool.
2. **Given** an Inbox person step and one item in *Person steps*, **When** the maintainer types
   position 1 and confirms, **Then** the person step is the first item of *Person steps*.
3. **Given** an Inbox item whose type and who belong in *Next*, **Then** the chooser shows
   *Decisions for the maintainer* and *Person steps* disabled with the reason, and the *Person* /
   *Decisions* buttons are disabled.

---

### User Story 2 - A sensible default position (Priority: P2)

The position offered for the chosen section is the place `auto-triage` would pick: before the
first item less severe than this one (after the items of equal severity), and after an item of the
section it depends on.

**Why this priority**: the default makes the common case one confirmation.

**Independent Test**: unit checks of the default for a section with rows of mixed severity, an
empty section and a section where every row is less severe.

**Acceptance Scenarios**:

1. **Given** *Next* holds rows of severity 7, 5, 3 and the item has severity 5, **Then** the
   default position in *Next* is 3; **given** rows of severity 4, 4, 5 and an item of severity 5,
   **then** it is 1.
2. **Given** an empty section, **Then** the default position is 1.

---

### Edge Cases

- A typed position that is not a whole number, or is 0 or negative: the move is refused in the
  page with a hint, nothing is sent.
- A position larger than the section's length: the item goes to the end (the tool's rule), the
  hint says so before confirming.
- The page is read-only (the write gate is closed): the chooser is disabled with the gate's reason,
  like the other triage buttons.
- The board changed underneath (another tab or the loop moved an item) while the page is open: the
  page follows the live board, so the default is recomputed and the move carries the revision of
  the board shown at the click; the server refuses a move computed on an older board (as for every
  move of the app since 371, the position is applied to the board the page showed last).
- The item changes while the chooser is open (another Inbox item becomes current after a skip or a
  placement): the chooser resets to the new item's suggested section and its default position.
- Typing into the position field must not trigger the triage's single-key shortcuts (digits set the
  severity, letters place, park, reject).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The triage page MUST show, for the current Inbox item, the target sections *Next*,
  *Decisions for the maintainer* and *Person steps*, preselected with the section the item's type
  and who admit (the suggestion's section); the sections the backlog tool would refuse for the
  item MUST be shown disabled with the reason.
- **FR-002**: The triage page MUST offer a position field for the chosen section, filled with the
  default position of FR-004 and editable.
- **FR-003**: Confirming the chooser (a button or Enter in the position field) MUST move the item
  from the Inbox to the chosen section at the chosen position in **one** change of the backlog (one
  move of the backlog tool with the position), and then show the next Inbox item as the other
  placements do.
- **FR-004**: The default position for a section MUST be the place `auto-triage` picks: the place of
  the first row of the section whose severity is lower than the item's (the end when there is
  none), moved to directly after any row of the section at or below that place that the item
  depends on. The suggestion (Accept / `n`) MUST use the same rule.
- **FR-005**: The position field MUST follow the default of the chosen section (as the board
  changes) until the maintainer types into it.
- **FR-006**: A position that is not a whole number of at least 1 MUST be refused in the page with a
  hint, and nothing is sent; a position past the end MUST be accepted, the field's hint saying so,
  and sent as the last place itself (so the item's log names the place it got).
- **FR-007**: The existing actions MUST keep their behaviour: Accept / `n` (the suggested place),
  Decisions / `d` and Person / `p` (the end of that section - disabled for an item that section
  does not admit, which the tool refused before), park, reject, skip, the severity keys and the AI
  proposal.
- **FR-008**: Keys typed into the position field or the section choice MUST NOT run the triage's
  single-key shortcuts; a key MUST bring the focus to the position field (so the chooser is usable
  from the keyboard alone), and Escape in the field MUST leave it without placing.
- **FR-009**: The chooser MUST be disabled with the write gate's reason when the backlog is
  read-only, as the other triage actions are.

### Key Entities

- **Placement**: a section and a 1-based position; the suggestion is one, the chooser's value
  another.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An Inbox item reaches any position of the ordered section its type and who admit
  (*Next*, *Decisions for the maintainer* or *Person steps*) from the triage page with one
  confirmation and one backlog change (before: two changes - a move and a reorder; *Decisions* and
  *Person steps* only at the end).
- **SC-002**: The default position equals the auto-triage rule for 100 % of the unit cases (sorted
  and unsorted sections, empty section, every row less severe, every row more severe, equal
  severity, dependencies above, at and below the place).
- **SC-003**: The existing triage test (key `n` places at the suggested position) still passes, and
  new end-to-end tests place an item at a typed position other than the suggested one, in *Next*
  and in *Person steps*.

## Assumptions

- Assumption (autonomous run): the chooser lives in the triage page's side column beside the
  existing buttons; the item page's own Move dialog stays as it is.
- Assumption (autonomous run): the key that focuses the position field is `m` ("move to a chosen
  place"), which is free on the triage page; Enter confirms, Escape leaves the field.
- Assumption (autonomous run): no server, schema or backlog-tool change is needed - the move
  request already carries an optional position.
- Scope: the backlog app (`tools/backlog-app/`) only; no product (Tandem Commander) code, no UI
  strings of the product, no translations.
