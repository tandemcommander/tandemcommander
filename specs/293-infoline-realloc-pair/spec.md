# Feature Specification: The information line survives running out of memory as its text grows

**Feature Branch**: `293-infoline-realloc-pair`  
**Created**: 2026-10-22  
**Status**: Draft  
**Input**: User description: "Backlog item the-information-line-keeps-using-a-freed-text-when-memory - implement exactly what it describes." From backlog item the-information-line-keeps-using-a-freed-text-when-memory.

## Clarifications

### Session 2026-10-22

- Q: After a failed enlargement, does the line show the old text, a part of the new one, or nothing? → A: the old text stays shown, unchanged (autonomous run: item)
- Q: Should a failed enlargement tell the user (a message box) beyond today's internal low-memory trace? → A: no - the failure is reported to the caller and traced exactly as today; no new UI and no new strings (autonomous run: conservative)
- Q: Is an enlargement that succeeded kept even though the other failed (memory held until the next attempt)? → A: yes - each successful result is kept at once; the next long text retries and reuses it (autonomous run: item)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A panel line that cannot grow keeps working (Priority: P1)

A user browses folders and moves the cursor over items. Each panel shows a directory line (the
current path) and an information line (the focused item). When one of these lines must show a text
longer than any it showed before, it enlarges its storage for the text and for the text's character
positions. If memory runs out part-way through that enlargement, today the line can keep referring
to storage that was already released; the next repaint, the next text change or closing the panel
then crashes the program or corrupts its memory. After this feature, a line whose enlargement fails
keeps showing its previous text and stays fully usable: later repaints, later texts and closing the
window behave normally.

**Why this priority**: it is the whole item - a crash (severity 7) in a low-memory scenario.

**Independent Test**: a low-memory test seam in the unit rules (`saltests`) makes the first or the
second of the two enlargements fail and checks that both storages stay valid, the old text is
intact and the recorded capacity never exceeds what either storage really holds; a reading proof in
the fix-log ties the seam to the line's code.

**Acceptance Scenarios**:

1. **Given** a line showing a short text, **When** it gets a longer text and the text storage grows
   (and moves) but the position storage cannot grow, **Then** the line keeps the moved text storage
   with its old text intact, the position storage unchanged, the recorded capacity unchanged, and
   reports failure.
2. **Given** the same line, **When** the text storage cannot grow but the position storage can,
   **Then** the line keeps the grown position storage, the text storage and its old text unchanged,
   the recorded capacity unchanged, and reports failure.
3. **Given** the same line, **When** both storages grow, **Then** both are kept, the capacity is the
   new size and the new text is shown - as before this feature.
4. **Given** a line whose enlargement failed earlier, **When** it later gets a long text again and
   memory is available, **Then** it grows and shows the new text.

### Edge Cases

- Both enlargements fail: nothing changes; failure reported; the old text stays shown.
- A text that fits the current capacity: no enlargement is attempted; behaviour unchanged.
- The first text of a fresh line (no storage yet): the same rules apply from an empty start; a
  failure leaves the line without text, as before.
- The text's wide-character mirror and the size field of the same window are replaced in one step
  each (released, then the new value stored at once) - no stale reference; unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the directory line or the information line enlarges its text and position
  storages, every storage that was successfully enlarged MUST be kept by the line at once, whether
  or not the other enlargement succeeds. Exception: a storage the line did not have before (a
  fresh line) gets nothing on a failed growth - a block newly obtained for it is released again,
  so the line stays exactly as it was (no text).
- **FR-002**: After a failed enlargement the line's recorded capacity MUST NOT exceed the size of
  either storage (it stays at the previous capacity until both storages hold the new size).
- **FR-003**: After a failed enlargement the line MUST keep its previous text and report failure to
  its caller, as it does today; callers' handling of the failure is unchanged.
- **FR-004**: When both enlargements succeed, or none is needed, the behaviour MUST be exactly as
  before.
- **FR-005**: The rule MUST be testable without the GUI and without real memory exhaustion: a
  low-memory seam in the unit rules makes either enlargement fail and checks FR-001..FR-003.

### Key Entities

- **Panel status line** (directory line / information line): a text, a parallel array of character
  positions of the same length, and the capacity both currently hold.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the unit rules, each of the three failure combinations (first fails, second fails,
  both fail) leaves both storages valid, the old text intact and the capacity unchanged - 0 failed
  checks.
- **SC-002**: A negative control (the old store-only-when-both-succeed rule) fails the new checks.
- **SC-003**: Build, encoding guard and all unit rules pass; no user-visible change when memory is
  available.

## Assumptions

- Assumption (autonomous run): the item's Expected allows either "store each result at once" or
  "allocate both before releasing either"; the first is chosen - it changes least and keeps the
  existing grow-in-place behaviour.
- Assumption (autonomous run): the low-memory case cannot be produced on the running program
  without fault injection; the proof is the unit-rule seam plus a reading proof in the fix-log
  (both allowed by the item's Expected). No GUI probe.
- Out of scope (recorded as backlog Inbox items): the size field of the same window writes into its
  storage before checking that it was obtained; `CStaticText::SetText` (src/gui.cpp) releases a
  successfully enlarged text storage when a later enlargement fails.
