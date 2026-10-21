# Data model - 280-user-menu-long-paths

## CUserMenuAdvancedData (src/execute.h, core-internal) - added fields

| Field | Meaning |
|---|---|
| `FullPathLeftTooLong` | the left panel shows a disk folder whose path + backslash does not fit 259 bytes (`FullPathLeft` is empty) |
| `FullPathRightTooLong` | the same for the right panel |
| `FullPathInactiveTooLong` | the same for the inactive panel (`FullPathInactive` points to the left or right path) |
| `CompareName1TooLong` / `CompareName2TooLong` | the item taken as the first / second name to compare has a full name over 259 bytes (the name is empty) |

Rules: a flag is TRUE only when its value is empty; the Find window sets the full-path flags FALSE
(the values are "not defined" there). `UserMenu` swaps the compare flags together with the names
and ignores them when the names are cleared.

## A prepared run (route without a shell)

| Part | Meaning |
|---|---|
| command | the expanded command, outer quotes removed |
| arguments | the expanded arguments |
| initial folder | the expanded Initial Directory (empty = none) - `SetDefaultDirectories` |
| item folder | the item's folder - `lpDirectory` when there is no Initial Directory (234) |

Lifecycle: collected during the loop; started in order after the loop when no item was refused;
freed when `UserMenu` returns.
