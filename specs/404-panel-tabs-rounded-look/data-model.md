# Data model - 404

## CPanelTab (session-only additions, never persisted)

| Field | Meaning |
|---|---|
| `IconKind` | `SAL_TAB_KIND_*`: unknown (-1, not derived yet), folder, drive root, UNC root, archive, plug-in FS |
| `IconDriveType` | `GetDriveType` result for a drive root (0 = not known) |
| `IconPluginIndex` | index of the plug-in owning the FS for `IconKind == plug-in FS` (-1 = unknown) |

Set by `CaptureActiveTab` from the panel's type; for a restored tab derived once at first paint.

## CTabWindow drag / press state

| Field | Meaning |
|---|---|
| `WaitForDrag`, `Dragging` | as today |
| `DragIndex` | the pressed tab (index in the strip) |
| `GrabOffset` | cursor x - the pressed tab's left at the press |
| `DragX` | drawn left of the dragged tab (clamped) |
| `DragSlot` | the slot the dragged tab would take now (`SalTabDragSlot`) |
| `Anim[i]` | per visible slot: `Cur`, `From`, `To`, `Start` (drawn offset from the tab's layout x) |
| `Gliding` | the release / cancel glide is running (input to the strip ignored for the order) |
| `PressedClose` | tab whose X was pressed (-1 none); `PressedCloseInside` - cursor still over it |

## Pure rules (`saltabs.h`)

- `SalTabMix(c1, c2, percent)` -> colour (rounded per channel as the mockup).
- `SalTabStripColors(face, shadow, highlight, text, dark, highContrast, out)` -> strip background,
  dim text, hover background, separator.
- `SalTabStripHeight(fontHeight, scalePercent)`; `SalTabStripWidths(avgChar, scalePercent, &min, &max)`.
- `SalTabDragSlot(count, tabWidth, draggedLeft, from)` -> slot index (centre crossing).
- `SalTabDragOrder(count, from, slot, order[])` -> the visible order while dragging / after release;
  cancel = identity.
- `SalTabMenuCanMoveToOther(onTab, count, otherTabsShown)`; `SalTabMenuCanNewAsOther(otherHasLocation)`.
- `SalTabLocationKind(location)` -> kind from the text alone (plug-in FS candidates are confirmed by
  the caller).
- `SalTabEaseOut(elapsedMs, durationMs)` -> 0..1000 progress.
