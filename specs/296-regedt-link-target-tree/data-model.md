# Data model - feature 296

No stored data. The entities of the decision (all in `src/plugins/regedt/fs5.cpp`):

| Entity | Fields | Notes |
|---|---|---|
| Operation's source (`CRegCopyTop`) | root, heap copy of the selected key's path, identities (`CSalRegKeyIds`, read lazily), "identities read" flag | one per call of `CopyOrMoveKey`; the recursion appends to its own path buffer, so the top path is copied |
| Target key of a level | root, path (`target\P`) | decided before it is created or opened |
| Registry link | the target key opened as a link; value `SymbolicLinkValue` of type `REG_LINK` | not a link: no key at the name, or no such value / another type |
| Link's target identities | `CSalRegKeyIds` from `GetRegKeyIds(root, path)` with links followed | `ERROR_FILE_NOT_FOUND` = dangling |

Decision per level (see [contracts/target-link-check.md](contracts/target-link-check.md)):

```text
no key / not a link            -> go on as before
link, dangling                 -> open-error box (ERROR_CANT_RESOLVE_FILENAME): Retry / Skip / Skip All / Cancel
link, error                    -> open-error box with that error
link, L in or = S              -> "Can't move/copy a key to itself." (OK skip / Cancel stop)
link, S strictly in L, current
  source holds below(S, L)     -> the same box
otherwise                      -> follow the link as before
```
