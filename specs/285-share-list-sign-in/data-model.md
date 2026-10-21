# Data model - 285

No stored data. Two pure decisions (`src/common/saluncserver.h`):

## SalUncShareListStep(count, error, logonFailure, signInTried) -> step

| Input | Step |
|---|---|
| `count > 0` | `SALUNC_LIST_SHOW` - offer the list (125) |
| `count == 0`, `error == ERROR_SUCCESS` | `SALUNC_LIST_NOTHING` - "a share name is missing" (125) |
| `count == 0`, error, `logonFailure`, not `signInTried` | `SALUNC_LIST_SIGNIN` - offer Windows' sign-in |
| `count == 0`, error, otherwise | `SALUNC_LIST_ERROR` - show the list's error (125) |

## SalUncSignInTarget(server, buf, size) -> BOOL

`\\server\IPC$` from a server name (UTF-8, no separators); FALSE and an empty buffer when the name
is empty, holds a separator, or the result does not fit - refused, never cut.

## Sign-in result (SignInToUncServerW)

`SIGNIN_CONNECTED` (also `ERROR_ALREADY_ASSIGNED`, `ERROR_DEVICE_ALREADY_REMEMBERED`) ·
`SIGNIN_CANCELLED` (`ERROR_CANCELLED`, nothing shown) · `SIGNIN_ERRORSHOWN` (the message was shown).

## Route states (PickServerShare)

`round 1: list` -> SHOW / NOTHING / ERROR as 125, or SIGNIN -> `sign-in` -> CONNECTED ->
`round 2: list` (signInTried) -> SHOW / NOTHING / ERROR; CANCELLED -> `PSS_CANCELLED`;
ERRORSHOWN -> `PSS_ERRORSHOWN`; the target cannot be built -> the list's error (`PSS_ERRORSHOWN`).
