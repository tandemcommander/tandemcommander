# Data model - 268-damaged-list-entries

No layout change. The lists as the loaders read them (`HKCU\Software\Tandem Commander\0.1\...`):

| List key | Entry `<n>` required values (missing / wrong type = damaged) | Optional values (default when unreadable) |
|---|---|---|
| `Viewers`, `Alternative Viewers` | `Masks` REG_SZ (no `|`), `Type` REG_DWORD | `Command`, `Arguments`, `Initial Directory` (empty) |
| `Editors` | `Masks` REG_SZ | `Command`, `Arguments`, `Initial Directory` (empty) |
| `User Menu` | `Item Name`, `Command` REG_SZ; `Execute Through Shell`, `Close Shell Window` REG_DWORD | `Arguments`, `Initial Directory`, `Open Shell Window`, `Icon`, `Separator`, `Type`, `Show In Toolbar` |

Reading rule (after the fix): entries `1, 2, ...` are opened in sequence until a number does not exist;
a damaged entry is closed and skipped; a usable entry is added; an entry whose item cannot be created
or added (out of memory) is closed and ends the list.

User Menu structure (feature 268, `src/common/salumbalance.h`): a damaged entry whose `Type` reads
submenu beginning (1) is skipped with its matching end; one whose `Type` reads submenu end (2) is
loaded as a plain end. A damaged entry without a readable `Type` is skipped like an item.

Saving (unchanged): the list key is cleared and the loaded entries are written as `1..Count`.
