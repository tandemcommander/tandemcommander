# Contract - keyboard and menu (feature 346)

User-visible interface; no plug-in API change.

| Input (panel has focus) | Result |
|---|---|
| Shift+F6, no plug-in command bound to it | `CM_QUICKRENAMEINPLACE` |
| Shift+F6, a plug-in command bound to it before 346 | the plug-in command (as before) |
| F6 / Ctrl+F6 / Alt+F6 / Ctrl+Shift+F6 / Alt+Shift+F6 | unchanged (Move / sort by size / Unpack / Restore Selection / nothing) |
| F2 | Rename dialog (unchanged) |
| Shift+F6 with focus in the command line | nothing (unchanged) |

`CM_QUICKRENAMEINPLACE` (also Files > *Rename in Place\tShift+F6*, enabled by `EnablerQuickRename`):

| Active panel / focused item | Result |
|---|---|
| disk, file or folder other than `..` | in-place editor over the name; selection as the click-started editor |
| plug-in FS with `FS_SERVICE_QUICKRENAME` | `QuickRename` mode 1 first (the FS may show its own dialog), else the editor; mode 2 on Enter |
| `..`, empty panel, archive, FS without the service | nothing |
| editor already open | nothing |

Editor keys (unchanged): Enter renames (focus follows the renamed item), Esc cancels, a too-long
name is refused and the editor stays.

Plug-in hot keys: `IsSalHotKey(Shift+F6)` = TRUE (Plugins Manager and settings import refuse a new
binding); `IsSalHotKeyKeptAtLoad(Shift+F6)` = TRUE (a stored binding is kept).
