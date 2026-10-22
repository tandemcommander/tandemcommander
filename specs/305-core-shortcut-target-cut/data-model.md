# Data model: 305

No stored data. The values of the rule (the same as feature 304's plug-in twin):

| Value | Meaning |
|---|---|
| answer | `IShellLinkW::GetPath(flags)` into 32,768 units; non-empty |
| list name | `SHGetNameFromIDList(SIGDN_FILESYSPATH)` of the link's item list; read only for answers of 259+ units without `SLGP_RAWPATH`; may be absent |
| plain form | `\\?\UNC\x` → `\\x`, `\\?\x` → `x`, anything else unchanged |

Outcomes of `SalShellLinkWholeTargetW(answer, listName)` (pure):

| Condition | Result |
|---|---|
| answer NULL or empty | NULL (refused) |
| answer shorter than 259 units | a copy of the answer (unchanged behaviour) |
| 259+ units, plain(answer) equals plain(list name) (ordinal, case ignored) | plain(list name) |
| 259+ units, plain(answer) is a prefix of the longer plain(list name) | plain(list name) |
| 259+ units, no list name, or any other difference | NULL (refused) |
| low memory | NULL (refused) |

Outcomes of `SalShellLinkGetPathU8(link, path, size, flags)`:

| Condition | Return | `path` |
|---|---|---|
| bad arguments | `E_INVALIDARG` | "" |
| low memory (the 32,768-unit buffer) | `E_OUTOFMEMORY` | "" |
| GetPath fails / S_FALSE | its code | "" |
| NOERROR with "" | `S_FALSE` | "" |
| answer under 259 units, fits | `NOERROR` | the answer (UTF-8) |
| 259+ units with `SLGP_RAWPATH` | `HRESULT_FROM_WIN32(ERROR_FILENAME_EXCED_RANGE)` | "" |
| 259+ units, the rule refuses | `HRESULT_FROM_WIN32(ERROR_FILENAME_EXCED_RANGE)` | "" |
| 259+ units, proven whole, fits | `NOERROR` | the whole item-list name, plain (UTF-8) |
| the result does not fit `size` bytes | `E_FAIL` | "" |

`SalFolderShortcutLinkTargetU8` (the loaded `target.lnk`, extracted after review 1) and so
`SalFolderShortcutTargetU8`: a reader result of `ERROR_FILENAME_EXCED_RANGE` is returned as its
own `ERROR_FILENAME_EXCED_RANGE` (refuse, `target` ""); every other path as before.
