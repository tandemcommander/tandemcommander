# Data model: feature 143

## CSalLoopCloseState (src/common/salloopclose.h, one per map window)

| Field | Meaning |
|---|---|
| `Menus` | open popup menus of the window's thread (0 or 1 in practice) |
| `OwnBoxes` | open boxes of the plug-in itself (About, close confirmation) |
| `ShellCommands` | shell commands running (`InvokeCommand`) |
| `ClosePending` | a close request arrived inside a loop and was not carried out yet |

Transitions:

- `Enter(kind)`: the kind's counter + 1; reports "first loop" when all counters were 0.
- `Leave(kind)`: the kind's counter - 1 (never below 0); when all are 0 reports "last loop", and
  "close now" if `ClosePending` (which is then cleared - the posted `WM_CLOSE` carries it) or
  "declare again" otherwise.
- `CloseRequest()`: no loop -> "destroy now"; else `ClosePending` = TRUE and "end the menu"
  (`Menus` > 0), "cancel own boxes" (`OwnBoxes` > 0 and `ShellCommands` == 0).

## DiskMapLoopsOpen (DiskMapPlugin.cpp)

Process-wide `LONG`: number of map windows with at least one loop open (interlocked).
