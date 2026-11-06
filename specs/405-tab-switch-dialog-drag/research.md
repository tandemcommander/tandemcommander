# Research - feature 405

## R1 How to know the button is no longer held after the switch

- **Decision**: `GetKeyState(VK_LBUTTON) & 0x8000` read when `OnLButtonDown` starts and again after
  `SwitchToTab` returns; refuse the drag when it went from down to up.
- **Rationale**: `GetKeyState` is the thread's synchronous input state: it changes as the thread removes
  input messages from its queue. A modal window inside the switch runs a message loop on the same thread,
  so the button-up it receives (or that the system turns into a beep over the disabled main window) moves
  the state to "up". It reports the logical button (swapped buttons handled). Messages posted by probes do
  not change it, so a posted press reads "up" both times and arms as before (feature 404's probes stay
  valid - the reason 404 review 2 rejected a plain `GetKeyState` check).
- **Alternatives considered**:
  - `GetAsyncKeyState`: physical button, ignores button swap and does not match the message stream.
  - A plain "button down after the switch" check: breaks all posted-message probes (404 review 2 note).
  - Detecting "a window was shown" (a CBT hook around the switch, a counter of activations): heavier,
    and plug-ins may create hidden helper windows; a dialog answered by mouse always takes the button-up,
    so the button signal covers the reported case. Recorded as an assumption in the spec.
  - Only the existing 404 guard (cancel at the first move without the button): leaves the capture, so a
    press-and-move elsewhere still drags the tab (measured, probe row RELEASED).

## R2 A gesture left pending when a new press arrives

- **Decision**: `OnLButtonDown` calls `CancelGesture()` first when `WaitForDrag`, `Dragging` or
  `PressedClose >= 0`.
- **Rationale**: with a real mouse a new button-down cannot come while the old gesture's button is held;
  so a pending gesture at a new press is always stale. Cancelling releases the capture and glides a drag
  back. No posted-message probe sends two downs without an up between them (checked in `tabs404_probe`).

## R3 How to drive it on the hidden desktop

- **Decision**: probe `tabs405_probe.ps1` attaches its thread's input to the program's GUI thread
  (`AttachThreadInput`) and sets `VK_LBUTTON` with `SetKeyboardState` (shared key state of attached
  threads). The modal window is the "Error Changing Directory" box of a tab whose folder was deleted -
  shown inside `SwitchToTab` -> `ChangeDir`, the same place as the FTP leave question.
- **Rationale**: no input desktop (no `SendInput`); the seam works - before the fix the probe read the
  states back ("down" / "up") and reproduced the defect.
