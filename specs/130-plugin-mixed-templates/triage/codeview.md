# Triage: codeview (feature 130)

Read: all 63 lines with `LoadStr` (`codeview.cpp`, `config.cpp`, `viewer.cpp`, `webglue.cpp`)
and every `SalMessageBox`, `SetWindowText*`, `sprintf`-family call of the plug-in's own sources.
No build, nothing run. **Nothing changed.**

## 1. How the names are encoded

The viewed file's name is UTF-8 (`viewer.cpp:626-639`: "The name is UTF-8", converted with
`SplU8ToWAlloc`). The plug-in was written after interface 104: wherever a name is shown, the
text is composed wide with `LoadStrW`.

## 2. Compositions

| Place | Template | Pieces | Sink | Verdict |
|---|---|---|---|---|
| `viewer.cpp:624-655` `UpdateTitle` | `IDS_WINDOW_TITLE` by `LoadStrW` | name UTF-8 -> wide, language name ASCII -> wide, zoom | `SplSetWindowTitleW` | RIGHT AS IT IS (wide end to end) |
| `viewer.cpp:658-683` `UpdateStatus` | `IDS_STATUS_*` by `LoadStrW` | numbers, ASCII names | `SetWindowTextW` | RIGHT AS IT IS |
| `viewer.cpp:444`, `477-490` `ShowBlockedNotice` | `IDS_LOAD_ERROR` / `IDS_BINARY_NOTICE` + `"\n\n"` + `IDS_OPEN_BUILTIN_ASK` (all cp) | none - the name is passed on to the built-in viewer, it is **not** in the text | `SalMessageBox` | RIGHT AS IT IS (all code page) |
| `viewer.cpp:737` | `IDS_ENCODING_INVALID` (cp) | number | `SalMessageBox` | RIGHT AS IT IS |
| `codeview.cpp:115-118` About | literal with `VERSINFO_COPYRIGHT` | `IDS_PLUGINNAME`, `IDS_PLUGIN_DESCRIPTION` (cp) | `SalMessageBox` | RIGHT AS IT IS (no name; see the note in `peviewer.md` about the `©` byte) |
| `webglue.cpp:268-275`, `viewer.cpp:959` | `LoadStrW` texts | - | JSON to the page (wide) | RIGHT AS IT IS |
| `viewer.cpp:522-570`, `854-861` | menu texts (cp) | - | `AppendMenuA` | RIGHT AS IT IS |
| the other message boxes (`codeview.cpp:176`, `config.cpp:241`, `viewer.cpp:929, 965, 1061`), `SetWinLibStrings`, `SetBasicPluginData` | constant texts | - | core | RIGHT AS IT IS |

Counts: 0 fixed, 8 rows right as they are, 0 recorded.

## 3. Reaching fixed places

None.

## 4. Other defects seen

None in the texts. (`viewer.cpp:522-570`: the menus are built with `AppendMenuA` from
code-page texts - right as long as the window's menu is a code-page menu; a language whose
texts are outside the system's code page shows `?`, as in every `A` menu of the program.)
