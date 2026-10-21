# Contract - the path of one key identity below another (feature 294)

Header `src/common/salregkeyid.h` (header-only, needs `<windows.h>`). Internal to the Registry
Editor plug-in and `saltests`; not a plug-in interface.

| Function | Result |
|---|---|
| `SalRegKeyIdBelow(key, outer)` | pointer into `key` just after `outer` and its `\` when `key` lies strictly inside `outer` (`outer` non-empty, a case-ignored prefix of `key` followed by `\`, and something after it); NULL otherwise (equal, not inside, a partial element, empty or NULL input) |

Consistency with 292: `SalRegKeyIdBelow(k, o) != NULL` implies `SalRegKeyIdWithin(k, o)` and not
`SalRegKeyIdSame(k, o)`.

## Use in `fs5.cpp` (`CPluginFSInterface::CopyOrMoveFromFS`, the key check)

After 292's `into = SalRegKeyIdsAnyWithin(targetIds, sourceIds)` is FALSE: for every pair
(`sourceIds.Id[i]`, `targetIds.Id[j]`) with `below = SalRegKeyIdBelow(source, target)` non-NULL,
`SafeRegKeyHoldsPath(sourceRoot, sourceKey, below, ...)` opens `sourceKey\below`; when it exists,
`into = TRUE` (the existing refusal follows); an error other than "not found" goes through
`RegOperationError(IDS_OPEN)` (Retry / Skip / Skip All / Cancel); a joined path is allocated at its
full length (never cut).
