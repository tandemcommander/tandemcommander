# Contract - the target-link check of the Registry Editor's copy (feature 296)

Internal to the Registry Editor plug-in (`src/plugins/regedt/fs5.cpp`); not a plug-in interface.
`CopyOrMoveKey` (declared in `regedt.h`, called by `CopyOrMoveFromFS` and `QuickRename`) keeps its
signature and results.

## `SafeCheckTargetLink(targetRoot, target, sourceRoot, source, top, refuse, errorTitle, skip, skipAll)`

Called in the recursion before `SafeCreateKey(targetRoot, target, ...)` of every level.

| Situation | Result |
|---|---|
| no key at `target` | TRUE, `refuse` FALSE |
| a key that is no link | TRUE, `refuse` FALSE |
| a link whose target identities `L` lie in / equal the source identities `S` | TRUE, `refuse` TRUE |
| a link with `S` strictly in `L` and `source\below(S, L)` existing | TRUE, `refuse` TRUE |
| a link to anything else | TRUE, `refuse` FALSE (followed as before) |
| a dangling link | `RegOperationError(ERROR_CANT_RESOLVE_FILENAME, IDS_OPEN, ..., target)`: Retry checks again; otherwise FALSE (`skip` TRUE for Skip / Skip All, FALSE for Cancel) |
| any other error (open as link, value query, identities of `S` or `L`, low memory) | the existing open-error box / `IDS_LOWMEM`; FALSE unless Retry |

`refuse` TRUE: the caller shows `IDS_CANTMOVETOITSELF2` / `IDS_CANTCOPYTOITSELF2` with the full name
`<root name>\<source>` (UTF-8, heap, whole); OK = `skip` TRUE, Cancel or low memory = `skip` FALSE;
returns FALSE without writing anything of that key.

## `SafeRegKeyIdsReachSource(sourceRoot, sourceKey, sourceIds, targetIds, into, errorTitle, skip, skipAll)`

294's pair loop, shared: for every pair with `below = SalRegKeyIdBelow(sourceIds[i], targetIds[j])`
non-NULL, `SafeRegKeyHoldsPath(sourceRoot, sourceKey, below, into, ...)`; stops at the first `into`.
FALSE = Cancel / Skip / low memory of the open-error box (as in 294). `CopyOrMoveFromFS` calls it
with the selected key and the top target; the link check with the key of the current level and the
link's identities.
