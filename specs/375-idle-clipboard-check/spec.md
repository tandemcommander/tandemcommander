# Feature Specification: Switching back to the program never waits for a busy clipboard

**Feature Branch**: `375-idle-clipboard-check`
**Created**: 2026-11-01
**Status**: Draft
**Input**: User description: "Backlog item every-activation-of-the-program-blocks-it-150-ms-in-the-idle - implement exactly what it describes." From backlog item every-activation-of-the-program-blocks-it-150-ms-in-the-idle.

## Background

Every time the program is activated again it checks the clipboard to decide whether *Paste*,
*Paste Shortcuts* and the paste of a path are available. Feature 372 measured that every
activation blocked the program for ~140 ms, also with local folders in both panels, and placed
the block in that clipboard check.

Measured at `e1b1e2c9` (Debug x64, hidden-desktop probe that deactivates and re-activates the
program the way Windows does and pings its main window every 2 ms; 5 activations a row):

| Clipboard at the activation | Longest wait per activation |
|---|---|
| free (another program owns its content, nobody keeps it open) | 0.4-2.3 ms |
| kept open by another program (content unchanged) | 140-142 ms, starting +15 ms - every activation |

The clipboard queries themselves cost below 1.1 ms on the user's desktop and on the hidden
desktop alike. When another program keeps the clipboard open, every attempt of this program to
open it fails at once; the check of "is there text on the clipboard" then tries again ten times
with a pause of ~15 ms each (155-165 ms measured) and gives up. Programs that keep the clipboard
open for a while exist (clipboard managers, remote-desktop clipboard sharing, a hung program);
at feature 372's time one did so on the maintainer's machine for hours, so every activation paid
the 140 ms.

## Clarifications

### Session 2026-11-01

- Q: While the clipboard is kept open by another program, what do the paste commands show? → A: What they show today after the waiting check gives up (the clipboard cannot be read, so the paste of files, shortcuts and a path are not offered); the program looks again shortly afterwards, so they become available on their own once the clipboard is free (autonomous run: conservative - same result as today, without the wait).
- Q: How long does the program keep looking again while the clipboard stays busy? → A: Every 0.5 s for at most 5 s after a check that found it busy; after that the next usual trigger (the next activation, opening a menu, closing a dialog, a paste) looks again (autonomous run: conservative - bounded work, never a permanent poll).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Switching back answers at once even when another program holds the clipboard (Priority: P1)

A user switches from another program back to Tandem Commander (Alt+Tab, a click on the taskbar
or into the window) while some other program keeps the clipboard open. The window answers at
once: keys and clicks are handled immediately.

**Why this priority**: it is the reported defect; while such a program holds the clipboard it
happens on every activation.

**Independent Test**: the activation probe (row HELD): the longest time the main window does not
answer after an activation, before and after the change.

**Acceptance Scenarios**:

1. **Given** another program keeps the clipboard open, **When** the program is deactivated and
   activated again, **Then** the main window answers within 30 ms at every moment of the 1.5 s
   after the activation (it did not answer for ~140 ms before).
2. **Given** the clipboard is free, **When** the program is activated again, **Then** it answers
   within 30 ms as before (no regression, row FREE).

---

### User Story 2 - The paste commands still follow the clipboard (Priority: P2)

After the activation the paste commands (*Paste*, *Paste Shortcuts*, the paste of a path) are
offered exactly when the clipboard holds something they can paste - also when the clipboard was
busy at the moment of the activation and is released a little later.

**Why this priority**: removing the wait must not leave the paste commands showing a wrong
state.

**Independent Test**: the pure decision of when to look again is covered by unit checks; the
enabled state of the commands is shown only in menus and toolbars, which the hidden-desktop
probe cannot read (a person-step confirms it on a real desktop).

**Acceptance Scenarios**:

1. **Given** the clipboard is free and holds copied files, **When** the program is activated,
   **Then** *Paste* is offered as before.
2. **Given** another program keeps the clipboard open at the activation and releases it within
   5 s, **When** the user then opens the *Edit* menu, **Then** the paste commands reflect the
   clipboard's content (within 0.5 s of the release, or at once when the menu opens).
3. **Given** the clipboard stays busy for longer than 5 s, **Then** the paste commands stay as
   they are today when the clipboard cannot be read, and the next activation, menu or paste
   looks again.

### Edge Cases

- The clipboard is released while the check runs: the next look (within 0.5 s) sees it free.
- Another program keeps the clipboard open for hours: the program looks again at most 10 times
  after each activation (or other trigger), never permanently.
- The user's own commands that read the clipboard on purpose (*Paste*, *Restore Selection* from
  the clipboard) keep their current behaviour, including their short wait for a busy clipboard -
  they are a deliberate user action, not an activation.
- The window is closed while a later look is pending: nothing happens.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The check of the clipboard that the activation (and every other trigger of the
  same check) requests MUST NOT wait for a clipboard that another program keeps open: it tries
  once and treats a busy clipboard as "cannot be read now".
- **FR-002**: When that check found the clipboard busy, the program MUST look again after
  0.5 s, at most 10 times in a row; a look that finds the clipboard free, or a new trigger of
  the check, ends or restarts that series.
- **FR-003**: Opening a menu while a later look is pending MUST look at once, so the menu shows
  the current state.
- **FR-004**: The result of a check that could read the clipboard MUST be the same as today
  (the same paste commands offered for the same clipboard content).
- **FR-005**: The result of a check that found the clipboard busy MUST be the same as today's
  result after its waiting gave up.
- **FR-006**: The commands that read the clipboard because the user asked for it (*Paste*,
  *Paste Shortcuts*, *Restore Selection* with the clipboard) MUST keep their current behaviour.

### Key Entities

- **Re-check series**: how many times the program has looked again since the last check that
  found the clipboard busy; at most 10; reset by a free clipboard or by a new trigger.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With the clipboard kept open by another program, the longest time the main window
  does not answer after an activation drops from ~140 ms to below 30 ms (probe row HELD, every
  one of 5 activations).
- **SC-002**: With the clipboard free, the longest wait after an activation stays below 30 ms
  (probe row FREE).
- **SC-003**: The decision when to look again is covered by unit checks (busy / free, the
  limit of 10, a new trigger restarting the series), all passing.
- **SC-004**: A person confirms on a real desktop that *Paste* is offered after copying files in
  another program and switching back, and after a clipboard that was busy at the activation is
  released.

## Assumptions

- Assumption (autonomous run): the item's *Expected* is met by the "without a perceptible
  wait" route (a single, non-waiting try plus later looks), not by moving the check to another
  thread - the clipboard can be read only by a thread with a window and the check takes below
  1.1 ms when the clipboard is free.
- Assumption (autonomous run): the item's note that the hidden desktop may make the queries
  slower is answered by the measurement (both desktops below 1.1 ms); the block depends on
  another program keeping the clipboard open, which the probe reproduces with a helper.
- Assumption (autonomous run): the enabled state of the paste commands cannot be read on the
  hidden desktop (the program's own menus and toolbars); it is owed to a person (SC-004).
- Out of scope: when the clipboard is busy at the check, the "cut" marking of files cut in this
  program is cleared, as today (an existing behaviour of the same check, unchanged).
