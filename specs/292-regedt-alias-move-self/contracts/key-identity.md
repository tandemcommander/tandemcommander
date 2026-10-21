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

- `GetRegKeyIds(root, key, set, mayNotExist)` fills a set: a root by the rule of research R2 (the
  HKCR root: both halves), an HKCR path by each half that holds it (R3), every other key by the
  opened key's reported name. Returns a Win32 error code; `ERROR_FILE_NOT_FOUND` with
  `mayNotExist` = success with an empty set.
- Folder check: `sameFolder = text check || (SalRegKeyIdsAnySame(panelFolder, targetFolder) &&
  both sets have one identity)`; same by identity with a two-identity folder = values are refused,
  keys go to the key check.
- Key check: `into = text check || SalRegKeyIdsAnyWithin(targetKey, sourceKey)`; `targetKey` =
  the opened target key, or (not existing) the target folder's identities joined with the name.
