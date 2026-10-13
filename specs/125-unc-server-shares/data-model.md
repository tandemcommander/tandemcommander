# Data model: feature 125

Nothing is stored. In-memory only:

## Server-only path

`\\server` or `\\server\` after the normalisation `ChangeDir` already does (slashes to
backslashes, duplicates removed). Not: `\\`, `\\.`, `\\?`, anything with a share part.
Rule: `SalUncServerOfPath(path, server, serverSize)` - TRUE and the server name (UTF-8, without
backslashes) or FALSE; a name that does not fit the buffer is refused.

## Share entry (`CUncShare`)

| Field | Meaning |
|---|---|
| `Name` | UTF-8, exactly as the server reports it (heap, any length) |
| `Hidden` | `STYPE_SPECIAL` set or the name ends with `$` |

Only folder shares become entries (`(type & STYPE_MASK) == STYPE_DISKTREE`).
Order: visible before hidden; inside a group `SalNameCompareOrdinalCI`.

## Job (`CUncSharesJob`)

| Field | Owner |
|---|---|
| `ServerW` (`\\server`, wide) | written before the thread starts, then read-only |
| `Shares`, `Count`, `Error` | written by the worker before it sets `Done`; read by the main thread after `Done` |
| `Done` (event) | set once by the worker |
| `Refs` | 2 at start (main thread + worker), `InterlockedDecrement`; whoever reaches 0 frees |

States: started -> done (list or error) -> read by the main thread; or started -> abandoned
(Esc) -> freed by the worker when its call returns.

## Outcome of the choice (`PickServerShare`)

`picked` (a path `\\server\share` in the caller's buffer) / `cancelled` (menu closed or Esc in
the wait) / `error shown` (the box was displayed) / `nothing to offer` (the caller shows the
existing "share name is missing").
