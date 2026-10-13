# Triage: folders (feature 130)

Read: all 10 lines with `LoadStr` (`folders.cpp`, `folders.h`) and a search of the plug-in's
sources for `MessageBox`, `GetErrorText`, `FormatMessage`, `sprintf`, `strcat`, `IDS_`.
No build, nothing run. **Nothing changed.**

## 1. How the names are encoded

No name or path meets a resource text anywhere in the plug-in: the only resource texts are the
plug-in's name, description, the About caption and the Change Drive menu item.

## 2. Compositions

| Place | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `folders.cpp:125-131` About | literal with `VERSINFO_COPYRIGHT` | `IDS_PLUGINNAME`, `IDS_PLUGIN_DESCRIPTION` (cp) | `SalMessageBox` | RIGHT AS IT IS (all code page, no name) |
| `folders.cpp:96`, `100-104`, `153` | constant texts | - | winliblt / core | RIGHT AS IT IS (no composition) |

Counts: 0 fixed, 2 rows right as they are, 0 recorded.

## 3. Reaching fixed places

None.

## 4. Other defects seen

None. (`folders.cpp:96`: the "invalid number" text of winliblt is the English literal
`"Invalid number!"`, not translated.)
