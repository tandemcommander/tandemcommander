# Data model - 413

No stored data changes. Two pure rules (`src/common/saltabs.*`):

| Rule | Inputs | Output | Invariants |
|---|---|---|---|
| `SalTabDragSlot` | count, tab width, dragged left relative to the run, from | slot 0 .. count - 1 | left 0 -> 0 (any from); left (count - 1) * width -> count - 1; moving right: floor(left / w); moving left: ceil(left / w); count <= 0 -> 0; width <= 0 -> from (clamped) |
| `SalTabActiveFill` | caption bk, caption fg, strip bk, face (COLORREF), High Contrast | fill COLORREF | High Contrast -> caption bk; both distances >= 24 -> caption bk; else the smallest k / 100 (k <= 50) mix toward fg reaching 24 from both, else the step k = 0 .. 50 with the largest smaller separation (the smallest k on a tie - review 2) |
| `SalTabActiveText` | caption fg, caption bk, fill | title COLORREF | fill == caption bk or the title keeps its contrast on the fill (at most 4.5:1 asked) -> caption fg; else the smallest k / 100 mix toward the pole away from the fill, then toward the other pole (reviews 1, 2) |

Distance = the largest of the three channel differences.
