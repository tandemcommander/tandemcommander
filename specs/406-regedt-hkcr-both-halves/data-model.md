# Data model - 406

## CSalHkcrDeleteHalf (src/common/salregkeyid.h)

| Value | Halves held before the copy | Delete at the end of a Move |
|---|---|---|
| `SAL_HKCR_DELETE_VIEW` | none (only reachable through links) | through HKCR (as before) |
| `SAL_HKCR_DELETE_MACHINE` | machine only (390) | `HKLM\Software\Classes\<key>` |
| `SAL_HKCR_DELETE_USER` | user only (390) | `HKCU\Software\Classes\<key>` |
| `SAL_HKCR_DELETE_BOTH` (new, appended) | both | machine (after the "copied" check), then user |

Before 406 "both" returned `VIEW`.

## SalRegValueSame(type1, data1, size1, type2, data2, size2)

TRUE exactly when the types are equal, the sizes are equal and the bytes are equal (a NULL pointer
only with size 0). Letter case, a trailing NUL, REG_SZ vs REG_EXPAND_SZ all count as different.

## The "machine half copied" check (fs5.cpp, impure)

copied = (the machine's class name is empty OR exactly equal to the user's - review of 406) AND for every value V of the machine's half: the user's
half has no value named V, or `SalRegValueSame(machine V, user V)`.
Result: `ERROR_SUCCESS` + copied flag, or a Win32 error (shown in the box).
