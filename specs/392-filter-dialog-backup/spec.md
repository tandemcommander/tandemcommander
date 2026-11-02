# Feature Specification: Filter dialog keeps a long panel filter whole after a refused edit

**Feature Branch**: `392-filter-dialog-backup`
**Created**: 2026-11-02
**Status**: Draft
**Input**: User description: "Backlog item filter-dialog-cuts-a-long-panel-filter-to-259-bytes-after-a - implement exactly what it describes." From backlog item filter-dialog-cuts-a-long-panel-filter-to-259-bytes-after-a.

## Clarifications

### Session 2026-11-02

- Q: When the typed text is checked apart from the panel's filter, which filter mode (with or without the `#` digit wildcard) does the check use? → A: the panel filter's own mode, as the check used before; a refused edit changes neither the text nor the mode (autonomous run: item - "exactly as it was")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A refused filter edit leaves the panel's filter as it was (Priority: P1)

A panel tab carries a filter longer than 259 bytes (a tab's filter is kept with up to 1000 bytes).
The user opens Change Filter, types a mask with a syntax error, presses OK, reads the error
"File mask is syntactically incorrect." and then cancels the dialog. The panel's filter must be
exactly the filter it had before the dialog opened - whole, and ready to filter the listing.

**Why this priority**: today the panel silently keeps only the first 259 bytes of its filter
(measured at fc9b8691), so it shows other files than the user's filter selects. This is the whole
item.

**Independent Test**: hidden-desktop probe `flt392_probe.ps1` row `long-refused`: two left tabs
from the registry, tab 1 with a valid 300-byte filter; switch to it, Change Filter, field
`*.txt|`, OK, error box answered, Cancel, Change Filter again - the field shows the 300 bytes.

**Acceptance Scenarios**:

1. **Given** a panel whose filter is 300 bytes long, **When** the user enters a mask with a syntax
   error, confirms, dismisses the error and cancels, **Then** the next Change Filter shows the
   whole 300-byte filter and the panel filters by it.
2. **Given** a panel whose filter is short, **When** the same refused edit is done, **Then** the
   filter stays as it was (as today).
3. **Given** a panel whose filter is 300 bytes long, **When** the user enters a valid short mask
   and confirms, **Then** the new mask is stored and used (as today).

### Edge Cases

- A refused edit followed by a corrected, valid entry in the same dialog: the valid entry is
  stored (as today).
- The field left at the long filter and OK: refused as too long by the existing check (feature
  270) before any change - unchanged.
- "Don't use filter" selected: no syntax check runs, the dialog behaves as today.
- The panel's filter mode (the extended `#` digit wildcard flag) is not changed by a refused edit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A Change Filter edit refused for a syntax error MUST leave the panel's filter
  unchanged: the same text byte for byte (any length the panel can hold), the same mode, and
  still ready to filter.
- **FR-002**: The syntax check of the typed text MUST give the same verdict and the same error
  position as today for every text, checked in the panel filter's own mode.
- **FR-003**: An accepted edit MUST be stored and used as today; the dialog's other behaviour
  (history, "Don't use filter", the too-long refusal of feature 270) MUST stay as it is.

### Key Entities

- **Panel filter**: the panel's mask group (text up to 1000 bytes, the extended-mode flag, its
  prepared form used to filter the listing).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe, a 300-byte panel filter is shown whole (300 of 300 bytes) by Change
  Filter after a refused edit and Cancel (before: 259 bytes).
- **SC-002**: The two control rows (short filter refused, long filter replaced by a valid mask)
  pass before and after the change.
- **SC-003**: Build, encoding guard and saltests stay green.

## Assumptions

- Assumption (autonomous run): the fix validates the typed text in a separate mask group and
  never writes the panel's own group during the check (the item's second option); this also
  keeps the panel's extended-mode flag, which the old restoration reset.
- Assumption (autonomous run): no UI string, dialog or resource changes, so no translation
  refresh is needed.
- Assumption (autonomous run): the 1000-byte limit of a mask group (`SetMasksString`, plug-in
  contract) and the 259-byte limit of what the dialog accepts (feature 270) stay as they are.
