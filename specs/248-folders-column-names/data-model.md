# Data model - 248-folders-column-names

## CShellColumn (Folders plug-in, `src/plugins/folders/folders.h`)

| Field | Before | After |
|---|---|---|
| `Name` (`char[COLUMN_NAME_MAX]`) | UTF-8 text of the shell's column name | the same name in the Windows code page (ACP), no best-fit; shortened at a whole character when it does not fit (`SalWToCodePageWhole`) |
| `Fmt`, `Char`, `Flags` | unchanged | unchanged |

Flow: shell `GetDetailsOf` (STRRET) → `StrRetToBufW` (UTF-16, at most 29 units) → code page →
`CShellColumn::Name` → `SetupView` copies into `CColumn::Name` → the core's header line.

Cell texts (`GetRowText` → `TransferBuffer`) stay UTF-8 (plug-in interface 104).
