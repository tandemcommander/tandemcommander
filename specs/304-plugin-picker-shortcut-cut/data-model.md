# Data model: 304

No stored data. The values of the rule:

| Value | Meaning |
|---|---|
| answer | `GetPath(SLGP_UNCPRIORITY)` of `target.lnk`, read into 32,768 units; non-empty |
| list name | `SHGetNameFromIDList(SIGDN_FILESYSPATH)` of the link's item list; read only when the answer has 259+ units; may be absent |
| plain form | `\\?\UNC\x` → `\\x`, `\\?\x` → `x`, anything else unchanged |

Outcomes of `WholeFolderShortcutTargetW(answer, listName)`:

| Condition | Result |
|---|---|
| answer shorter than 259 units | a copy of the answer (unchanged behaviour) |
| 259+ units, plain(answer) equals plain(list name) | plain(list name) |
| 259+ units, plain(answer) is a prefix of the longer plain(list name) | plain(list name) |
| 259+ units, no list name, or any other difference | refused (NULL) |
| low memory | refused (NULL) |
