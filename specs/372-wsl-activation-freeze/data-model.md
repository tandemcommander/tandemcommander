# Data model - 372-wsl-activation-freeze

## Background path check request (per panel, `CFilesWindow`)

| Member | Meaning |
|---|---|
| `BkgndCheckRunning` (BOOL) | a worker of this panel runs (at most one) |
| `BkgndCheckWanted` (int, bits) | `SAL_BKCHK_ACTIVATE` (1): activation asked for it; `SAL_BKCHK_VERIFY` (2): the deferred verification of a refresh asked for it |
| `AutoRefreshVerifyTimerSet` (BOOL) | the 400 ms timer `IDT_AUTOREFRESHVERIFY` runs |

## Worker data (heap, owned by the worker until posted, then by the panel)

| Field | Meaning |
|---|---|
| `Path` | heap copy of the panel path the check tests (UTF-8, never cut) |
| `PanelType` | the panel type at the start |
| `Valid`, `Error` | the result of `SalTestPathAccessible` |

## State transitions

```text
request(bit): Wanted |= bit; if !Running -> start(current path) ; Running = TRUE
done(data):   Running = FALSE; action = SalBkgndCheckAction(Wanted, samePath && sameType, Valid)
              REFRESH_EX -> post WM_USER_REFRESH_DIR_EX(FALSE, t)   ; Wanted = 0
              REFRESH    -> post WM_USER_REFRESH_DIR(0, t)          ; Wanted = 0
              RESTART    -> start(current path) if the panel still qualifies, else Wanted = 0
              NONE       -> Wanted = 0
```
