# Feature Specification: A tab switch that shows a dialog never leaves the tab strip in drag mode

**Feature Branch**: `405-tab-switch-dialog-drag`
**Created**: 2026-11-06
**Status**: Draft
**Input**: User description: "Backlog item problem-s-prepinanim-zalozek - implement exactly what it describes (GitHub issue #22: switching away from an FTP tab leaves the tab strip in drag mode)." From backlog item problem-s-prepinanim-zalozek.

## Clarifications

### Session 2026-11-06

- Q: When the switch showed a dialog but the left button is still held when it returns (the dialog was answered with the keyboard), should the strip still arm a drag? → A: Yes - only the button state decides; a button held from the press to the release is a real drag (Expected, second bullet; the first bullet allows "or the left button is no longer down"). (autonomous run: item)
- Q: When a new left press reaches the strip while an older gesture is still pending, is the new press handled after cancelling the old one, or swallowed? → A: The old gesture is cancelled (glide back, capture released) and the new press is then handled as usual; a press outside every tab part only cancels. (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Switching away from a tab that asks a question (Priority: P1)

A user has several tabs in a panel; one shows an FTP connection. They click another tab of the same panel. Before the panel leaves the FTP location, the FTP plug-in asks what to do with the connection; the user releases the mouse button, answers the question (for example *keep the connection*) and goes on working. The strip must behave as after any ordinary click: no insert mark following the mouse, no tab moving at the next click, and the next click anywhere goes where the user clicks.

**Why this priority**: This is the reported defect (GitHub issue #22). Today a tab can be moved to a place the user never chose, and the next click elsewhere is swallowed by the strip.

**Independent Test**: A click on a tab whose switch shows a modal box (here the error box for a tab whose folder was deleted - the same path as the FTP question), the button released while the box is open, the box answered; then a move with the button pressed elsewhere and a release. The tab order is unchanged and the strip holds no mouse capture after the box.

**Acceptance Scenarios**:

1. **Given** a panel with tabs A X1 X2 X3 B and a switch to X1 that shows a box, **When** the user presses on X1, releases the button while the box is open, answers the box, and later presses elsewhere and moves the mouse, **Then** no tab moves and the strip does not hold the mouse capture after the box.
2. **Given** the same, **When** after the box the mouse only moves (no button) and the user then clicks on tab B, **Then** no insert mark follows the mouse, the click on B only switches to B and no tab moves.

---

### User Story 2 - A real drag still works (Priority: P2)

A user presses on a tab and drags it to another place, holding the button from the press to the release - also when the switch to that tab showed a box that was answered without releasing the button (for example with the keyboard).

**Why this priority**: The fix must not take away the live drag added by feature 404.

**Independent Test**: The existing drag rows of the feature-404 probe (posted messages) and a held-button row of the new probe: the tab moves.

**Acceptance Scenarios**:

1. **Given** tabs A B C D, **When** the user drags A past C's centre with the button held, **Then** the order becomes B C A D (unchanged behaviour).
2. **Given** a switch that shows a box while the button stays held, **When** the user then moves the held mouse onto the first tab's place and releases, **Then** the tab moves there.

### Edge Cases

- The switch shows no window and the button is still held: the drag is armed as before.
- The button goes up during a switch that pumps messages without a dialog (a wait window): no drag is armed, because the button is no longer down.
- A new left press reaches the strip while an old gesture is still pending (a capture left behind): the old gesture is cancelled first.
- Mouse buttons swapped in Windows settings: the logical left button is what counts.
- Press on a tab's X (close glyph) or on the plus / list buttons: unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: After a click on a tab switches the panel, the strip MUST arm a drag and take the mouse capture only when the left button is still held; when the button was held at the press and is no longer held after the switch, no drag is armed and the capture is not taken.
- **FR-002**: A tab MUST move only through a drag whose left button is held from the press to the release (keeps the feature-404 rule that a mouse move without the button cancels a pending drag).
- **FR-003**: A new left press on the strip while an earlier gesture is still pending MUST cancel that gesture (glide back, capture released) before handling the press; a press outside every part of the strip (no tab, X, plus or list) only cancels.
- **FR-004**: Every existing behaviour of the strip that does not involve a window or a lost button-up during the switch MUST stay as it is (drag reorder, cancel by Esc / capture loss / cancel mode, close on release, middle click, context menu).
- **FR-005**: The decision "arm a drag after the switch" MUST be a pure rule with unit checks.
- **FR-006**: A probe MUST reproduce the defect before the fix and pass after it; the real FTP question with a real mouse is a person's check on the release checklist.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe, after a switch that showed a box with the button released during it, 0 tabs move on the following press-and-move, and the strip holds no capture (before the fix: 1 tab moved, capture held).
- **SC-002**: All rows of the feature-404 probe that drive the mouse keep passing (29 PASS / 0 FAIL / 1 NOT DRIVEN before and after) and the held-button row of the new probe moves the tab.
- **SC-003**: The unit checks of the rule pass, together with all existing unit checks (0 failed).

## Assumptions

- Assumption (autonomous run): "SwitchToTab showed any window" (Expected, first bullet) is detected through its effect on the left button: answering a dialog with the mouse always takes the button-up, so the button is no longer held when the switch returns. A button held continuously through a dialog answered by the keyboard keeps the drag - the button really is held from the press to the release (Expected, second bullet); the item allows either signal ("or the left button is no longer down").
- Assumption (autonomous run): the button state is the one the program's own input reading reports (synchronous with the messages it processed). Messages posted by probes do not change that state, so a press without a recorded button-down (posted) arms as before - the existing probes keep working.
- The FTP question itself is not reachable on the hidden desktop (no server, no real mouse); the deleted-folder error box takes the same path (a modal window inside the switch inside the strip's button-down handling).
- No UI string, dialog, setting, plug-in interface or stored data changes.
