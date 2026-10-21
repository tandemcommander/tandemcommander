# Contract - the target of a folder shortcut (feature 286, `src/common/salshelllink.h`)

Core-internal (not part of the plug-in interface).

## `BOOL SalIsFolderShortcutIni(const char* buf, int len)`

TRUE when the first `len` bytes of a `desktop.ini` contain `{0AFACED1-E828-11D1-9187-B532F1E9575D}`
- the whole id between braces, ASCII letter case ignored. NULL / empty -> FALSE. `{}` or a
prefix of the id -> FALSE.

## `HRESULT SalFolderShortcutTargetU8(const char* folderU8, char* target, int targetSize)`

`folderU8`: a path of the core (UTF-8 / WTF-8), any length Windows knows. COM initialised.

| Result | Meaning | `target` |
|---|---|---|
| `NOERROR` | a folder shortcut; its target fits `targetSize` bytes | the target, whole |
| `S_FALSE` | not a folder shortcut (no or another `desktop.ini`), or `target.lnk` missing / unreadable / without a file-system target | `""` |
| `HRESULT_FROM_WIN32(ERROR_FILENAME_EXCED_RANGE)` | a folder shortcut whose target needs `targetSize` bytes or more | `""` - refuse, never cut |
| `E_INVALIDARG` / `E_OUTOFMEMORY` | bad arguments / low memory | `""` when `target` is usable |

The names `folderU8\desktop.ini` and `folderU8\target.lnk` are built on the heap and opened
through wide (`\\?\` from `MAX_PATH` characters) - no `MAX_PATH` limit of the folder's own path.

## `GetTargetDirectory` (core, `shellib.h`) - unchanged signature

Returns TRUE and the folder in `path` (`MAX_PATH` bytes) - or FALSE with `path` unchanged; a
refusal ("too long") shows `IDS_TOOLONGPATH` itself. `ResolveNetHoodPath(char* path)` now
returns BOOL: FALSE = `path` is a folder shortcut whose target does not fit `MAX_PATH`
(`path` unchanged).
