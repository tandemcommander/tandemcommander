# Feature Specification: A dialog's status text and the panel's size field survive running out of memory

**Feature Branch**: `295-statictext-grow-buffers`  
**Created**: 2026-10-22  
**Status**: Draft  
**Input**: User description: "Backlog item a-dialog-status-text-and-the-panel-size-field-crash-when - implement exactly what it describes." From backlog item a-dialog-status-text-and-the-panel-size-field-crash-when.

## Clarifications

### Session 2026-10-22

- Q: After a failed enlargement, does the dialog text show the old text, a part of the new one, or nothing? → A: the old text stays shown, unchanged (autonomous run: item)
- Q: Should a failed enlargement tell the user (a message box) beyond today's internal low-memory trace? → A: no - failure is reported to the caller and traced exactly as today; no new UI and no new strings (autonomous run: conservative)
- Q: When one enlargement fails, are the remaining ones still attempted or does the growth stop there? → A: all are attempted in a fixed order and each success is kept, as in feature 293's two-storage rule; the next long text retries and reuses what grew (autonomous run: rule)
- Q: When the size field's storage cannot be obtained, is it tried again at the next size update? → A: yes - the field stays without storage and the next update tries again, as today's code already does once the write is guarded (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A dialog text that cannot grow keeps working (Priority: P1)

A user copies, moves, deletes or packs files; the progress dialog shows the current file name and
status in static texts (and many other dialogs show texts the same way). When such a text must show
a text longer than any before, it enlarges its storages: the text, its wide-character form and -
for texts shortened with an ellipsis - the character positions, the shortened text and its
wide-character form. If memory runs out part-way through, today the text releases a storage it
still refers to (or keeps referring to one already released); the next repaint, the next text or
closing the dialog then crashes the program or corrupts its memory. After this feature a text
whose enlargement fails keeps showing its previous text and stays fully usable.

**Why this priority**: the larger half of the item - a crash (severity 7) in a low-memory scenario,
in the dialogs of every long file operation.

**Independent Test**: a low-memory seam in the unit rules (`saltests`) grows the same set of
storages (two, or five with different sizes) with each chosen enlargement failing and checks that
every storage stays valid, the old text and measurements are intact and the recorded capacity never
exceeds what any storage holds; a reading proof in the fix-log ties the seam to the control's code.

**Acceptance Scenarios**:

1. **Given** a text showing a short text, **When** it gets a longer text and some storages grow
   (and move) but a later one cannot grow, **Then** every storage that grew is kept with its old
   contents, the others are unchanged, the recorded capacity is unchanged, the old text stays
   shown, and failure is reported to the caller as today.
2. **Given** the same text, **When** the first storage cannot grow but later ones can, **Then** the
   same holds.
3. **Given** the same text, **When** every storage grows, **Then** the new text is shown - as before
   this feature.
4. **Given** a text whose enlargement failed earlier, **When** it later gets a long text and memory
   is available, **Then** it grows and shows the new text.

### User Story 2 - The panel's size field without memory (Priority: P2)

The directory line of a panel shows the free space (size field). It obtains the storage for that
text on first use and today writes into it before checking that it was obtained - a crash when the
allocation fails. After this feature the field writes only into storage it really has; without
storage it shows no size, as every reader of the field already handles.

**Why this priority**: the smaller half of the item; a one-line defect of the same kind.

**Independent Test**: a reading proof in the fix-log (the write follows the check; every reader of
the field checks for missing storage).

**Acceptance Scenarios**:

1. **Given** a panel whose size field has no storage yet, **When** the storage cannot be obtained,
   **Then** nothing is written, no size is shown, and the panel keeps working.
2. **Given** storage was obtained, **Then** the behaviour is exactly as before.

### Edge Cases

- Every enlargement fails: nothing changes; failure reported; the old text stays shown.
- A text that fits the current capacity: no enlargement is attempted; behaviour unchanged.
- The first text of a fresh control (no storage yet): a failure leaves the control with no storage
  at all (a fresh storage would hold no text and no terminator - it is released again), as before.
- A text without an ellipsis style grows only the text and its wide form; one with an ellipsis style
  grows all five; the set never changes for one control.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When a dialog static text enlarges its storages, every storage that was successfully
  enlarged MUST be kept by the control at once, whether or not the other enlargements succeed;
  every enlargement is attempted, in a fixed order.
  Exception: a storage the control did not have before gets nothing on a failed growth - a block
  newly obtained for it is released again.
- **FR-002**: After a failed enlargement the control's recorded capacity MUST NOT exceed the size of
  any of its storages (it stays at the previous capacity until all storages hold the new size).
- **FR-003**: After a failed enlargement the control MUST keep its previous text and report failure
  to its caller as today; no storage the control refers to is released.
- **FR-004**: When every enlargement succeeds, or none is needed, the behaviour MUST be exactly as
  before (the same sizes, including the room for "..." in the shortened text).
- **FR-005**: The panel's size field MUST check that its storage was obtained before writing into it;
  without storage it shows no size and the next size update tries to obtain it again.
- **FR-006**: The rule of FR-001..FR-003 MUST be testable without the GUI and without real memory
  exhaustion: a low-memory seam in the unit rules makes chosen enlargements fail and checks it.
- **FR-007**: The panel status line's existing growth of two storages (feature 293) MUST keep its
  tested behaviour.

### Key Entities

- **Dialog static text**: a text, its wide-character form, and with an ellipsis style a
  character-position array, a shortened text and its wide form; one shared capacity (the two
  shortened forms hold three more elements for "...").
- **Panel size field**: a short text of the free space, obtained on first use.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the unit rules, every single failure and every tested combination among two and
  five storages leaves every storage valid, the old contents intact and the capacity unchanged -
  0 failed checks.
- **SC-002**: A negative control (the old rule: release earlier results on a later failure, or store
  them only when all succeed) fails the new checks.
- **SC-003**: Build, encoding guard and all unit rules pass (including feature 293's); no
  user-visible change when memory is available.

## Assumptions

- Assumption (autonomous run): the item's Notes offer "a variant of the 293 rule for more buffers"
  or "storing each result at once by hand"; the variant is chosen so the rule is tested once in
  `saltests` and shared, and the 293 pair keeps its behaviour.
- Assumption (autonomous run): the low-memory case cannot be produced on the running program without
  fault injection; the proof is the unit-rule seam plus a reading proof in the fix-log (both allowed
  by the item's Expected). No GUI probe.
- Assumption (autonomous run): a failed growth is reported and traced exactly as today; no new UI
  and no new strings.
