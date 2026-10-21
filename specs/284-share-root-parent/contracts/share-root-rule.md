# Contract: SalUncShareRootServerPath (src/common/saluncserver.h, feature 284)

```cpp
inline BOOL SalUncShareRootServerPath(const char* path, char* serverPath, int serverPathSize);
```

| `path` | result | `serverPath` |
|---|---|---|
| `\\server\share` | TRUE | `\\server\` |
| `\\server\share\` | TRUE | `\\server\` |
| `\\192.168.1.10\C$` | TRUE | `\\192.168.1.10\` |
| UTF-8 names (`\\škola\Sdílené`) | TRUE | `\\škola\` (bytes copied as they are) |
| `\\server`, `\\server\` (no share) | FALSE | empty |
| `\\server\share\dir`, `\\server\share\\` | FALSE | empty |
| `\\server\\share` (empty share part) | FALSE | empty |
| `\\`, `\\\share`, `\\.\C:\`, `\\.\x`, `\\?\C:\`, `\\?\UNC\s\x` | FALSE | empty |
| `C:\`, `\server\share`, `server`, `""`, NULL | FALSE | empty |
| a result of `size` bytes or more (with its NUL) | FALSE | empty - never cut |
| `serverPath == NULL` or `serverPathSize <= 0` | FALSE | - |

Names only starting with `.` or `?` (`\\.x\s`, `\\?x\s`) are servers - as `SalUncServerOfPath`.
Slashes are not separators here (panel paths hold backslashes only): `//server/share` is FALSE.

Callers (all only where the Network plug-in test was FALSE): `ReadDirectory` (lists `..`),
`Execute` of `..`, `GotoRoot`, `OpenFocusedInOtherPanel`; each hands `serverPath` to `ChangeDir`.
