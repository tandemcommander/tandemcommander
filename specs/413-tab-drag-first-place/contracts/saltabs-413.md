# Contract - saltabs rules of 413 (core-internal, not a plug-in interface)

```cpp
// the slot a dragged tab would take; moving right tab j gives way once 'draggedLeft' is at or
// above j * tabWidth, moving left once it is at or below j * tabWidth - so both ends of the
// run (the caller clamps the left to 0 .. (count - 1) * tabWidth) are reachable (feature 413)
int SalTabDragSlot(int count, int tabWidth, int draggedLeft, int from);

// the minimum separation of the active tab's fill from the strip and from the face colour
#define SALTAB_ACTIVE_MIN_CONTRAST 24

// the active tab's fill: 'capBk', or - when it is within SALTAB_ACTIVE_MIN_CONTRAST (largest
// channel) of 'stripBk' or 'face' - 'capBk' mixed toward 'capFg' by the smallest k / 100
// (k <= 50) that separates it from both; never mixed under High Contrast (feature 413)
DWORD SalTabActiveFill(DWORD capBk, DWORD capFg, DWORD stripBk, DWORD face, BOOL highContrast);

// review 1: the active tab's title on 'fill' - 'capFg' unless the fill was lifted and the title
// lost the contrast it has on 'capBk' (at most 4.5:1 asked); then mixed toward white / black
double SalTabContrastRatio(DWORD a, DWORD b);
DWORD SalTabActiveText(DWORD capFg, DWORD capBk, DWORD fill);
```

Callers: `CTabWindow::UpdateDrag` (slot), `CTabWindow::Paint` (fill; the shape and the close
glyph of the active tab use it). No other caller (Grep at 75a45ea7).
