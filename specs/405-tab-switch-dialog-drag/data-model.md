# Data model - feature 405

No stored data. The state involved is the tab strip's gesture state (`CTabWindow`, feature 404):

| Field | Meaning |
|---|---|
| `WaitForDrag` | a press on a tab, the drag not yet started (inside `SM_CXDRAG`) |
| `Dragging` | a live drag running |
| `PressedClose` | a press on a tab's X, waiting for the release |
| capture | held by the strip while any of the above is set |

Transitions changed by this feature:

- press on a tab -> `SwitchToTab` -> **armed only if `SalTabArmDragAfterSwitch(downAtPress, downAfter)`**
  (else: idle, no capture);
- any pending gesture + a new left press -> `CancelGesture` -> the new press handled from idle.

Rule `SalTabArmDragAfterSwitch(BOOL downAtPress, BOOL downAfterSwitch)`:

| at press | after switch | result |
|---|---|---|
| down | down | TRUE (a held press) |
| down | up | FALSE (the button went up during the switch) |
| up | up | TRUE (a posted / synthetic press - unchanged behaviour) |
| up | down | TRUE |
