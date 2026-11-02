# Data model - 388 renamer-subdir-links

## Listed directory entry (input of the rule)

| Field | Source | Meaning |
|---|---|---|
| `listedAttr` | `WIN32_FIND_DATAW.dwFileAttributes` | the entry's attributes as listed |
| `tagRead` | TRUE for an entry from a listing; FALSE when the look-up of a selected item failed | whether `tag` is known |
| `tag` | `WIN32_FIND_DATAW.dwReserved0` (valid when the reparse bit is set) | the reparse tag |

## Rule `SalListedDirIsLink(listedAttr, tagRead, tag)` → BOOL

| listedAttr has REPARSE_POINT | tagRead | tag | result |
|---|---|---|---|
| no | any | any | FALSE (a plain directory) |
| yes | FALSE | any | TRUE (fail closed) |
| yes | TRUE | 0 | TRUE (the bit without a tag: unknown, fail closed) |
| yes | TRUE | name surrogate (bit 0x20000000) | TRUE (junction, mount point, symbolic link, WSL link, …) |
| yes | TRUE | other tag | FALSE (cloud placeholder, OneDrive, dedup, WOF) |

## Renamer source item (`CSourceFile`)

A link becomes an item with `IsDir = 1`, `Ext` at the end of the name (folders have no extension),
`Attr` = the listed attributes, size from the listing (0). Nothing else changes.
