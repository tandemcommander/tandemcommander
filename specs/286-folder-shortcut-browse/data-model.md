# Data model - feature 286

No stored data. Two transient values:

## Browse result

| Outcome | `GetTargetDirectory` returns | `path` | Shown |
|---|---|---|---|
| a file-system folder whose UTF-8 path fits `MAX_PATH` bytes | TRUE | the folder (or a followed folder shortcut's target) | nothing |
| a file-system folder whose UTF-8 path does not fit | FALSE | unchanged | "The path specified is too long." |
| a folder shortcut whose target does not fit | FALSE | unchanged | "The path specified is too long." |
| an item with no file-system path | FALSE | unchanged | nothing |
| Cancel | FALSE | unchanged | nothing |

## Folder shortcut

A folder `F` with `F\desktop.ini` (at most 1,000 bytes) naming the class
`{0AFACED1-E828-11D1-9187-B532F1E9575D}` (whole id, any letter case) and a file
`F\target.lnk`. Its target = `IShellLinkW::GetPath(SLGP_UNCPRIORITY)` of `target.lnk`, no
`Resolve`. Only on a local fixed drive (checked by the caller, as before).
