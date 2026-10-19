# Feature Specification: A damaged highlighting entry no longer hangs the start-up

**Feature Branch**: `250-damaged-highlight-entry`  
**Created**: 2026-10-19  
**Status**: Draft  
**Input**: User description: "Backlog item a-damaged-highlighting-entry-hangs-the-program-at-start-up - implement exactly what it describes." From backlog item a-damaged-highlighting-entry-hangs-the-program-at-start-up.

## Clarifications

### Session 2026-10-20

- Q: Should the existing "Error Loading Configuration" message for an entry of the wrong type or a read error be silenced? → A: No - it stays, shown at most once per damaged entry; only the endless repetition goes (autonomous run: conservative)
- Q: Should a skipped damaged entry be kept in the registry when the configuration is saved on exit? → A: No - the existing save rewrites the list from the loaded entries; the save is not changed (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The program starts with a damaged highlighting entry (Priority: P1)

A user whose configuration holds a damaged entry in the panel item highlighting list (Options >
Configuration > Panels > Colors, the list of masks with their colours) - made by a hand edit of the
registry, an imported `.reg` file or a settings import - starts Tandem Commander. Today the start-up
never ends: the program spins at full processor load without ever showing its window, or shows the same
"Error Loading Configuration" box again and again. After the change the program starts, the damaged
entry is left out, and every other entry of the list keeps working.

**Why this priority**: it is the whole item; a program that does not start cannot be used or repaired
from its own configuration dialog.

**Independent Test**: write a highlighting list with one damaged entry into the configuration, start the
program on the hidden desktop, see the main window appear, close it and read back the saved list.

**Acceptance Scenarios**:

1. **Given** a highlighting list whose first entry has no masks value and two good entries follow,
   **When** the program starts, **Then** the main window appears without a message box, and the list
   saved on exit holds exactly the two good entries in their order.
2. **Given** a list whose middle entry has no masks value, **When** the program starts, **Then** it
   starts and the entries before and after the damaged one are both kept (the damaged entry is skipped,
   it does not end the list).
3. **Given** an entry that is an empty key (no values at all), **When** the program starts, **Then** it
   starts and the following entry is kept.
4. **Given** an entry whose masks value has the wrong type (a number) or is longer than the program
   reads, **When** the program starts, **Then** it shows the existing "Error Loading Configuration"
   message at most once for that entry, then starts with the following entry kept.
5. **Given** an intact list, **When** the program starts and is closed, **Then** nothing changes: no
   message, the same list saved in the same order.

### Edge Cases

- Several damaged entries in a row: each is skipped once; the list continues with the next number.
- The list key exists but holds no entries: the list is empty, as today.
- The numbering has a gap (entries 1, 2, 4): the list ends at the gap, as today - only the entries that
  exist in sequence are read.
- The item for an entry cannot be created for lack of memory: the entry is skipped like a damaged one
  (today the same endless loop).
- Configurations older than version 16 still get the added "encrypted files" entry after the list.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Reading the highlighting list at start-up MUST move to the next entry after every entry it
  opened, whether or not the entry could be read.
- **FR-002**: Every entry key opened while reading the list MUST be closed in the same round (no key
  handle left open).
- **FR-003**: An entry whose masks value cannot be read (missing, wrong type, too long) or whose item
  cannot be created MUST be left out of the list; the entries after it MUST still be read.
- **FR-004**: The existing message for an unreadable value of the wrong type or a read error MUST be
  shown at most once per damaged entry; no new message or text is added.
- **FR-005**: An intact list MUST load exactly as before: the same entries, the same order, the same
  colours and attributes.
- **FR-006**: The list saved on exit MUST hold the loaded entries only (the damaged ones are not written
  back), numbered from 1 without gaps, as the existing save does.

### Key Entities

- **Highlighting entry**: one numbered key of the list; its masks value (which files it applies to),
  attributes and colours. Only the masks value decides whether the entry can be used.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With any one of the five damaged-entry kinds of the probe (missing masks first, missing
  masks in the middle, empty key, wrong type, too long), the main window appears within 30 seconds
  (before the change: never; measured 0 of 5).
- **SC-002**: At most one message box per damaged entry (before: an endless series - 10 in 3 seconds).
- **SC-003**: The list saved on exit equals the good entries in their order in 7 of 7 probe rows (the
  control row included).
- **SC-004**: The control row with an intact list behaves exactly as before the change (start, no box,
  same list saved).

## Assumptions

- Assumption (autonomous run): the damaged entry is **skipped**, not treated as the end of the list - the
  item allows both; skipping loses fewer of the user's entries (stop-rules §1 step 4, conservative).
- Assumption (autonomous run): the masks value is still read into the existing buffer of `MAX_PATH`
  bytes; a longer value (which the configuration dialog cannot produce - its edit is limited to
  `MAX_PATH`) is reported by the existing message and skipped, and therefore not written back on exit.
  Reading longer masks would be a new behaviour outside the item (conservative).
- Assumption (autonomous run): no change to the registry layout, the save code, the configuration
  dialog or any other list loader; the other `while (OpenKey(...))` loops of the core were measured to
  advance on every round.
- The fix is in the start-up configuration loader only; it needs no new UI string and no translation.
