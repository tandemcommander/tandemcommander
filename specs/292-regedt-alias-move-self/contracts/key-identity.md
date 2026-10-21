# Contract - registry key identity (feature 292)

Header `src/common/salregkeyid.h` (header-only, needs `<windows.h>`). Internal to the Registry
Editor plug-in and `saltests`; not a plug-in interface.

| Function | Result |
|---|---|
| `SalRegKeyIdSame(a, b)` | TRUE when both are non-empty and equal, case ignored (`CompareStringOrdinal(..., TRUE)`) |
| `SalRegKeyIdWithin(key, outer)` | TRUE when `key` is `outer` or lies inside it: `outer` (non-empty) is a case-ignored prefix of `key` followed by the end or `\` |
| `SalRegKeyIdsAdd(set, parent, name)` | appends `parent` (`name` NULL / empty) or `parent\name`; FALSE (set unchanged) when `parent` is empty, the set is full or the text does not fit `SAL_REGKEYID_MAX` - never a cut identity |
| `SalRegKeyIdsAnySame(a, b)` | some identity of `a` is the same as some identity of `b` |
| `SalRegKeyIdsAnyWithin(inner, outer)` | some identity of `inner` lies within some identity of `outer` |

An empty set is never the same as or within anything (the caller fails closed before it would
compare an empty set).

## Use in `fs5.cpp` (`CPluginFSInterface::CopyOrMoveFromFS`)

- `GetRegKeyIds(root, key, set, mayNotExist)` fills a set: a root by the rule of research R2, HKCR
  by R3, other keys by the opened key's reported name. Returns a Win32 error code;
  `ERROR_FILE_NOT_FOUND` with `mayNotExist` = success with nothing added for the opened key.
- Folder check: `sameFolder = text check || SalRegKeyIdsAnySame(panelFolder, targetFolder)`.
- Key check: `into = text check || SalRegKeyIdsAnyWithin(targetKey, sourceKey)`.
