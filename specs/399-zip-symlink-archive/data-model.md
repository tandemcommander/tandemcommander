# Data model - 399-zip-symlink-archive

| Name | Where | Meaning |
|---|---|---|
| `ZipName` | `CZipCommon` (UTF-8, heap) | the archive as the user named it (a link's path stays the link's path); every message uses it |
| `ReplaceTarget` | `CZipPack` (UTF-8, heap, new) | NULL: the replace target is `ZipName`. Set by `CreateTempFile` when `ZipName` is a file link and its final path could be read: the real archive's path |
| `TempName` | `CZipPack` | `Sal*.tmp` in the folder of the replace target |
| `ZipAttr` | `CZipPack` | the archive's attributes; after a resolve those of the real archive |

States of one update with the backup option:

1. `ZipFile` open through `ZipName`.
2. `CreateTempFile`: the name tested (`SalReplaceTargetOfLinkW`) -> `ReplaceTarget` set or NULL;
   the temporary file made next to the replace target.
3. Work written into the temporary file; `ZipFile` closed.
4. `ReplaceArchiveWithTemp`: `SalReplaceWithTempW(replace target, TempName)` - outcomes as in 320;
   attributes / newest time applied to the replace target.

Validation: `ReplaceTarget` only from a name-surrogate, non-folder reparse name; only a DOS drive or
UNC final path; only when it fits `U8_MAX_PATH`.
