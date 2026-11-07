# Data model - 413

No stored data changes. Two pure rules (`src/common/saltabs.*`):

| Rule | Inputs | Output | Invariants |
|---|---|---|---|
| `SalTabDragSlot` | count, tab width, dragged left relative to the run, from | slot 0 .. count - 1 | left 0 -> 0 (any from); left (count - 1) * width -> count - 1; moving right: floor(left / w); moving left: ceil(left / w); count <= 0 -> 0; width <= 0 -> from (clamped) |
| `SalTabActiveFill` | caption bk, caption fg, strip bk, face (COLORREF), High Contrast | fill COLORREF | High Contrast -> caption bk; both distances >= 24 -> caption bk; else the smallest k / 100 (k <= 50) mix toward fg reaching 24 from both, else k = 50 |

Distance = the largest of the three channel differences.
