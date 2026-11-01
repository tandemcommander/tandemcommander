# Data model - 386-mydocs-path-whole

No stored data changes. The values the rule works on:

| Value | Meaning | Limits |
|---|---|---|
| Documents path (wide) | the folder the shell reports for Documents, or none | 0-259 UTF-16 units |
| Desktop path (wide) | read only when Documents has no file-system path | 0-259 units |
| caller buffer | bytes the asking part holds, terminator included | `MAX_PATH` (rescue path) or `SAL_MAX_PATH_UTF8` |
| result | whole UTF-8 (WTF-8) path, or refused with an empty buffer | - |

Decision table (`SalDocumentsOrDesktopToU8`):

| Documents | Desktop | fits caller buffer | result |
|---|---|---|---|
| a path | - | yes | Documents, whole |
| a path | - | no | refused (`SAL_DOCS_TOO_LONG`), Desktop not used |
| none | a path | yes | Desktop, whole |
| none | a path | no | refused (`SAL_DOCS_TOO_LONG`) |
| none | none | - | refused (`SAL_DOCS_NONE`) |
