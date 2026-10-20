# Data model: 272

No stored data. The decision of one Change Attributes entry:

| Input | Meaning |
|---|---|
| `listedAttr` | the entry's attributes as listed (panel or the walk), with `FILE_ATTRIBUTE_REPARSE_POINT` / `FILE_ATTRIBUTE_DIRECTORY` |
| `linkByRule` | `DeleteAsDirLink(name)` - asked only when the reparse bit is listed (fail closed) |
| `wantedAttr` | the requested attributes |
| `changeEncryption` | the operation changes encryption |

| Output | Rule |
|---|---|
| `isLink` | reparse bit listed and `linkByRule` (folder or file) |
| open flags (times; compression uses `isDir` = TRUE) | `FILE_FLAG_BACKUP_SEMANTICS` for a folder, `FILE_FLAG_OPEN_REPARSE_POINT` for a link, both for a directory link, 0 for a plain file |
| encryption refused | `isLink` and `changeEncryption` and the encrypted bit of `listedAttr` differs from `wantedAttr` |
