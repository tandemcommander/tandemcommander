# Data model - feature 315

No stored data. The values of `CFilesWindow::Unpack` before the dialog opens:

| Value | Size | Source | Rule |
|---|---|---|---|
| `path` | 260 bytes | other panel's path (UA on), else empty | whole or empty; with SD: + `\` + archive name whole, or the name alone (path left out) |
| `pathAlt` | 260 bytes | other panel's path (UA off), else empty | the same |
| `mask` | 260 bytes | plug-in mask, else `*.*` | whole, else `*.*` |
| `path` after OK, when empty | 260 bytes | the archive panel's path | whole, else refused (`IDS_TOOLONGPATH`) |

"Fits" = UTF-8 bytes + terminator <= 260. A path is UTF-8 (WTF-8); a whole copy never splits a
character, so no invalid UTF-8 reaches the combo box.
