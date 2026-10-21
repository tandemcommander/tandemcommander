# Data model - 295-statictext-grow-buffers

## CStaticText (src/gui.cpp) - buffers and capacity

| Buffer | Element | Holds (elements) | Grown when |
|---|---|---|---|
| `Text` | `char` | `Allocated` | always |
| `TextW` | `WCHAR` | `Allocated` | always |
| `AlpDX` | `int` | `Allocated` | `STF_PATH_ELLIPSIS` or `STF_END_ELLIPSIS` |
| `Text2` | `char` | `Allocated + 3` | the same |
| `Text2W` | `WCHAR` | `Allocated + 3` | the same |

Invariants after every `SetText` (success or failure):

- every non-NULL buffer is a live block holding at least the count above;
- `Allocated == 0` ⇔ all buffers NULL (a fresh control);
- on failure: the text and its forms are the previous ones (blocks may have moved, contents kept).

## CStatusWindow (src/stswnd.cpp) - size field

- `Size`: NULL or a live 30-byte block holding a terminated text; `SizeW`: its UTF-16 mirror or NULL.
