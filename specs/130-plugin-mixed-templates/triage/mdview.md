# Triage: mdview (feature 130)

Read: all 35 lines with `LoadStr` (`mdview.cpp`, `viewer.cpp`) and every `SalMessageBox`,
`SetWindowText*`, `sprintf`-family call of the plug-in's own sources. No build, nothing run.
**Nothing changed.**

## 1. How the names are encoded

The document's path is kept wide (`FilePathW`, `DocDir`; `viewer.cpp:515-532`, `754-771`) and
converted to UTF-8 only for the core (`SplWToU8Alloc`, `viewer.cpp:758`, `772`).

## 2. Compositions

| Place | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `viewer.cpp:515-532` `UpdateTitle` | none - literals (`L"Markdown Viewer"`, `L" [Source]"`, ...) | path wide, zoom | `SplSetWindowTitleW` | RIGHT AS IT IS (wide, no resource text) |
| `viewer.cpp:771-774` blocked local link | none - the resolved path + `"\n\n"`, UTF-8; `IDS_LINK_BLOCKED` only **instead of** it when the conversion fails | - | `SalMessageBox` | RIGHT AS IT IS (either one UTF-8 text or one code-page text, never both) |
| `viewer.cpp:792` | `IDS_LINK_BLOCKED` alone | - | `SalMessageBox` | RIGHT AS IT IS |
| `mdview.cpp:67-70` About | literal with `VERSINFO_COPYRIGHT` | `IDS_PLUGINNAME`, `IDS_PLUGIN_DESCRIPTION` (cp) | `SalMessageBox` | RIGHT AS IT IS (no name) |
| `viewer.cpp:462-490` | menu texts (cp) | - | `AppendMenuA` | RIGHT AS IT IS |
| the other message boxes (`mdview.cpp:128`, `viewer.cpp:697, 721`), `SetWinLibStrings`, `SetBasicPluginData` | constant texts | - | core | RIGHT AS IT IS |

Counts: 0 fixed, 6 rows right as they are, 0 recorded.

## 3. Reaching fixed places

None.

## 4. Other defects seen

- `viewer.cpp:520-526`: the window title is not translated (`Markdown Viewer`, `[Source]`,
  `[ANSI]` are literals although `IDS_WINDOW_TITLE` exists and is used as the caption of the
  message boxes) - not an encoding defect.
- `viewer.cpp:771-774`: the message for a blocked local link is the bare path followed by two
  line ends - no sentence around it.
