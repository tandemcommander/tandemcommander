# Data model: 253

No stored data. The decision works on three values per Change Attributes entry:

| Value | Source | Meaning |
|---|---|---|
| listed attributes | `op->Attr` (the panel / walk listing) | `FILE_ATTRIBUTE_DIRECTORY`, `FILE_ATTRIBUTE_REPARSE_POINT`, `FILE_ATTRIBUTE_ENCRYPTED` of the entry itself |
| link rule | `DeleteAsDirLink(name)` at processing time | TRUE = a directory link (fail closed) |
| wanted attributes | `(listed & AttrAnd) \| AttrOr` (`op->TargetName`) | the requested state, `FILE_ATTRIBUTE_ENCRYPTED` meaningful when ChangeEncryption |

Derived: `isDirLink`; open flags (`BACKUP_SEMANTICS` for a folder, `+ OPEN_REPARSE_POINT` for a
link); `refuseCrypt` = link and ChangeEncryption and the encrypted bit differs.
