# Data model - 390

No stored data changes. The run-time decision:

| Input | Meaning |
|---|---|
| `machineHeld` | `HKLM\Software\Classes\<path>` opened (exists) before this level's copy |
| `userHeld` | `HKCU\Software\Classes\<path>` opened (exists) before this level's copy |

`SalRegHkcrDeleteHalf(machineHeld, userHeld)`:

| machineHeld | userHeld | delete |
|---|---|---|
| yes | no | `SAL_HKCR_DELETE_MACHINE` - `HKEY_LOCAL_MACHINE\Software\Classes\<path>` |
| no | yes | `SAL_HKCR_DELETE_USER` - `HKEY_CURRENT_USER\Software\Classes\<path>` |
| yes | yes | `SAL_HKCR_DELETE_VIEW` - through `HKEY_CLASSES_ROOT` (unchanged) |
| no | no | `SAL_HKCR_DELETE_VIEW` (unchanged; the source's own open reports the error) |

`SalRegJoinClassesPath(out, outUnits, key)`: `Software\Classes\` + `key`; FALSE (out = "") when the
result with its terminator does not fit `outUnits` or `key` is empty - never cut.
