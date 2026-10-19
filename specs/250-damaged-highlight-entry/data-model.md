# Data model - 250-damaged-highlight-entry

No change to the stored data. For reference:

`HKCU\Software\Tandem Commander\0.1\Colors\Panel Items Hilighting\<n>`, `n` = 1, 2, ... without gaps
(the list ends at the first missing number):

| Value | Type | Role |
|---|---|---|
| `Masks` | REG_SZ, < `MAX_PATH` bytes | which files the entry applies to - **required**; an entry without a readable one is skipped (feature 250) |
| `Attributes`, `Valid Attributes` | REG_DWORD | attribute filter - optional (default 0) |
| `Item Fg/Bk Normal / Selected / Focused / Focused and Selected / Highlight` | REG_DWORD (or legacy REG_SZ) | colours - optional (default colour) |

The save on exit (`CMainWindow::SaveConfig`) clears the key and writes the loaded entries as 1..N.
