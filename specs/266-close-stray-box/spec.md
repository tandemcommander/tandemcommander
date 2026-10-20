# Feature Specification: Plug-in closing - forced Disk Map unload in a shell command, stray comparator box

**Feature Branch**: `266-close-stray-box`  
**Created**: 2026-10-20  
**Status**: Draft  
**Input**: User description: "Backlog item plugin-close-forced-unload-and-stray-box - implement exactly what it describes." From backlog item plugin-close-forced-unload-and-stray-box.

## Clarifications

### Session 2026-10-20

- Q: Part (1) - may a forced unload of Disk Map, made while a shell command of the map is
  running, avoid terminating the map's thread? → A: No change of behaviour. A forced unload
  cannot be declined (the core unloads the plug-in's code right after a forced `Release`, the
  return value is ignored); waiting without a limit freezes the main window for as long as the
  shell command runs; making the shell command return needs the plug-in to answer or cancel the
  shell's window, which reverses the recorded decision of feature 143 (FR-004: the shell's
  windows are never touched). The termination stays the core's "force" semantics, as the item's
  *Approach* allows; the site documents it, and the alternative (cancel the shell's window on a
  forced unload) is handed to the maintainer as a decision item. (autonomous run: item)
- Q: When has the comparator's close "begun"? → A: When its main window starts being destroyed
  (its destruction handler runs, which may still wait for a running comparison and handle
  messages meanwhile). Earlier states (a close request that still closes open boxes first) keep
  their behaviour. (autonomous run: conservative)
- Q: Should the mapping's hand-over routine (it forgets the handles without closing them) also
  reset the size? → A: No - only the destroy routine the item names; the hand-over routine has no
  caller in the tree and keeps its behaviour. (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Closing the File Comparator shows no stray error box (Priority: P1)

A person compares two files that differ in binary content (the hex view) and closes the
comparator window while a comparison is still being computed. A read error of the hex view that
was reported just before (and not yet shown) must not appear as an error box (with Retry /
Cancel, and after Cancel a "close the comparison?" question) while the window is going away.

**Why this priority**: it is the only part of the item that changes behaviour; a box over a
window that is disappearing is confusing and its answer has no meaning any more.

**Independent Test**: code review of the close path plus a build; the timing (an error pending
in the milliseconds the closing window waits for its comparison) cannot be driven on the hidden
desktop - recorded as NOT DRIVEN.

**Acceptance Scenarios**:

1. **Given** a hex view with a read error reported but not yet shown, **When** the comparator's
   window is being destroyed and handles messages while it waits for its comparison, **Then**
   no error box and no "close the comparison?" question appears and the window closes.
2. **Given** a hex view with a read error reported while the window is open (not closing),
   **When** the error is handled, **Then** the error box appears as before (Retry repaints,
   Cancel offers to close the comparison).

---

### User Story 2 - A destroyed file mapping reports no size (Priority: P2)

After the hex view released a file (its data destroyed), the view's file size reads as zero, so
any later paint finds nothing to show instead of trying to read a released file and reporting
"the handle is invalid".

**Why this priority**: no visible defect today (a trap for later work), but it closes the path
by which a paint after the release would produce the stray box of story 1.

**Independent Test**: code review; the size is reset next to the handles it describes.

**Acceptance Scenarios**:

1. **Given** a hex view whose data were destroyed, **When** it paints, **Then** it reads no file
   data and reports no error.
2. **Given** a hex view given a new file, **When** it paints, **Then** it shows the new file as
   before.

---

### User Story 3 - A forced Disk Map unload keeps its documented behaviour (Priority: P3)

A person exits the program while a Disk Map shell command (e.g. the Delete confirmation) waits,
and answers the core's "force it to unload?" question Yes. The program ends without a crash;
the file is kept; the map's thread is ended by force as in every release (the force semantics).

**Why this priority**: no change; recorded so the outcome of the item is explicit.

**Independent Test**: 143's probe row E5 on the build of this feature: clean exit, file kept
(as before).

**Acceptance Scenarios**:

1. **Given** the shell's Delete confirmation of a map open, **When** the person exits and
   forces the unload, **Then** the program exits with code 0, no crash report, the file kept.

### Edge Cases

- The error pending at close time came from the other (sibling) hex view: the same rule - no
  box once the close began.
- A comparison of text files (no hex view): nothing changes.
- A recompare that replaces the hex views' data while the window stays open: the error box
  keeps its current behaviour (the close has not begun).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Once the File Comparator's window has begun to be destroyed, a hex-view read
  error that is still pending MUST NOT show any box (no error box, no "close the comparison?"
  question) and MUST NOT change the closing.
- **FR-002**: A hex-view read error handled while the window is not closing MUST behave as
  before.
- **FR-003**: Destroying a hex view's file mapping MUST reset the mapped file's size to zero
  together with the released handles (the hand-over routine that forgets the handles without
  closing them is unchanged).
- **FR-004**: The forced unload of Disk Map MUST keep its behaviour (end the map's threads by
  force after the short wait); the reason MUST be documented at the site.
- **FR-005**: No new UI text, no plug-in interface change, no registry change.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the comparator's closing path, zero code paths remain that show a box from a
  pending hex-view read error (code review, confirmed by the independent review).
- **SC-002**: After a hex view's data are destroyed its reported file size is 0 (code review).
- **SC-003**: 143's probe rows E4, E5, E6 pass on the build of this feature as they did before
  (no regression of Disk Map's close).
- **SC-004**: The build succeeds, the encoding guard reports 0 findings and saltests report 0
  failed checks.

## Assumptions

- Assumption (autonomous run): the stray-box timing cannot be reproduced on the hidden desktop
  (it needs a posted message pending during the milliseconds the closing window waits for its
  comparison); the fix is proven by code review and the independent review, and the row is
  recorded as NOT DRIVEN.
- Assumption (autonomous run): a "close the comparison?" question raised during the close
  retry that precedes destruction (the window still has an open box and closes it first) is a
  separate, earlier state and keeps its behaviour; it is recorded in the fix-log, not changed.
- Constitution II (backward compatibility): no plug-in interface, registry or text changes.
