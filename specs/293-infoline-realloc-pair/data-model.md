# Data model - 293-infoline-realloc-pair

## Buffer pair of a panel status line (`CStatusWindow`)

| Field | Meaning | Invariant after any `SetText` (success or failure) |
|---|---|---|
| `Text` | UTF-8 text, NUL-terminated | NULL, or a live block of at least `Allocated` bytes (or a live block holding the previous text) |
| `AlpDX` | one `int` per text unit (character positions) | NULL, or a live block of at least `Allocated` ints |
| `Allocated` | capacity both buffers hold | never greater than the real size of either block |

Transitions of a growth to `needed` elements (`Allocated < needed`):

| first realloc | second realloc | `Text` | `AlpDX` | `Allocated` | result |
|---|---|---|---|---|---|
| ok | ok | new | new | `needed` | TRUE, new text stored |
| ok | fails | new (old text copied in) | old | old | FALSE, old text shown |
| fails | ok | old | new (old positions copied in) | old | FALSE, old text shown |
| fails | fails | old | old | old | FALSE, old text shown |

A buffer whose pointer was NULL before a failed growth stays NULL (its fresh block is released).
