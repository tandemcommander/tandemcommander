# Data model - 400-uniso-walk-after-unreadable

## SalIsoWalk (src/common/salisowalk.h)

One per walk of one file system (reset by the reader's `ListDirectory`; ISO 9660 also before its fit
walk; `CountUnder` saves and restores it around a count walk).

| Field | Meaning | Set by |
|---|---|---|
| `Stopped` | out of memory met: no later folder of the walk is descended | out-of-memory sites of the walk and of `AddFileDir` |
| `BoxShown` | the walk's one error box was shown | `SalIsoWalkBoxQuiet` |

## Walk result of a directory

`OK` -> `CONTINUE` when a nested folder's walk returned anything but OK (never back to OK);
`TERMINATE` when the directory itself cannot go on (its read failed, a bad record, out of memory).
A parent turns a child's `TERMINATE` into its own `CONTINUE`.

## Visited directories (UDF, Xbox - new; ISO 9660 - 328)

Set per listing walk. UDF key: `(partition << 32) | block` of the folder's ICB; Xbox key: start
sector. Met again: the folder is listed, not descended, not marked.
