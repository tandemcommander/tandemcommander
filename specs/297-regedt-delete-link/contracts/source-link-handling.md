# Contract - source link handling (feature 297)

Internal to the `regedt` plug-in; no plug-in interface change.

## What a registry link is (after the review of 297)

A key created with `REG_OPTION_CREATE_LINK`. It is told by **what the key is, not by its values**: a
plain key may hold a value `SymbolicLinkValue` of type `REG_LINK` (settable without elevation), and
reading values needs `KEY_QUERY_VALUE`, which a delete does not need.

## `static int OpenedRegKeyIsLink(HKEY hLink, int root, LPCWSTR key, BOOL& isLink)` (fs5.cpp)

`hLink` = `root\key` opened with `REG_OPTION_OPEN_LINK`. Opens `root\key` by name (links followed)
with `KEY_ENUMERATE_SUB_KEYS`:
- `ERROR_FILE_NOT_FOUND` -> `isLink` TRUE (a dangling link, a link without its value);
- other error -> that error;
- else `isLink` = the two keys' internal names (292's `AddOpenedRegKeyId`, `NtQueryKey`
  KeyNameInformation) are not the same (`SalRegKeyIdsAnySame`); a name that cannot be read whole ->
  that error (never a cut name).

## `static int RegKeyIsLink(int root, LPCWSTR key, BOOL& isLink)` (fs5.cpp)

An empty `key` (a root) is no link. Else opens `root\key` with `REG_OPTION_OPEN_LINK`,
`KEY_ENUMERATE_SUB_KEYS` (only the last element as a link): open error -> that error
(`ERROR_FILE_NOT_FOUND` = no key); else `OpenedRegKeyIsLink`. 296's `SafeCheckTargetLink` uses it.

## `BOOL SafeRegKeyIsLink(int root, LPWSTR key, BOOL& isLink, int errorTitle, BOOL& skip, BOOL& skipAll)`

`RegKeyIsLink` with the existing open-error box (`IDS_OPEN`, Retry / Skip / Skip All / Cancel);
`ERROR_FILE_NOT_FOUND` is no error (`isLink` FALSE, TRUE returned - the caller's own open reports it).
FALSE = do not go on with this key (`skip` tells Skip from Cancel).

## `BOOL SafeDeleteRegLink(int root, LPWSTR key, int errorTitle, BOOL& skip, BOOL& skipAll)`

Opens `root\key` with `REG_OPTION_OPEN_LINK`, `DELETE | KEY_ENUMERATE_SUB_KEYS`; checks that handle
again with `OpenedRegKeyIsLink` (no link -> `ERROR_NOT_SUPPORTED`, never deleted here);
`NtDeleteKey(handle)`; NTSTATUS mapped by `RtlNtStatusToDosError`. Errors in the existing box
`IDS_DELETE` (Retry repeats the whole sequence). TRUE = removed.

## Delete (`CPluginFSInterface::DeleteKey`, fs3.cpp)

First thing of every level (after the cancel test): `SafeRegKeyIsLink(..., IDS_DELKEY, ...)`; a link
-> `return SafeDeleteRegLink(...)`; nothing is enumerated or deleted through it.

## Move (`CopyOrMoveKeyRec`, fs5.cpp, `move` TRUE)

First thing of every level (after the cancel test): `SafeRegKeyIsLink(source)`; while a link:
`RegOperationError(ERROR_NOT_SUPPORTED, IDS_REMOVESOURCE, errorTitle, sourceRoot, source, &skip,
&skipAllErrors)` - Retry checks again, Skip / Skip All / Cancel return FALSE before anything is
opened for copying or written. Copy (`move` FALSE): no test, unchanged.
