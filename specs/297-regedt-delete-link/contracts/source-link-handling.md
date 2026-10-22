# Contract - source link handling (feature 297)

Internal to the `regedt` plug-in; no plug-in interface change.

## `int RegKeyIsLink(int root, LPCWSTR key, BOOL& isLink)` (fs5.cpp, file-static)

Opens `root\key` with `REG_OPTION_OPEN_LINK`, `KEY_QUERY_VALUE` (only the last element as a link),
queries `SymbolicLinkValue` without data. Returns a Win32 error:
- open fails -> that error (`ERROR_FILE_NOT_FOUND` = no key), `isLink` FALSE;
- value missing (`ERROR_FILE_NOT_FOUND`) or of another type -> `ERROR_SUCCESS`, `isLink` FALSE;
- type `REG_LINK` -> `ERROR_SUCCESS`, `isLink` TRUE;
- other query error -> that error.
296's `SafeCheckTargetLink` uses it with the same results as its former inline test.

## `BOOL SafeRegKeyIsLink(int root, LPWSTR key, BOOL& isLink, int errorTitle, BOOL& skip, BOOL& skipAll)`

`RegKeyIsLink` with the existing open-error box (`IDS_OPEN`, Retry / Skip / Skip All / Cancel);
`ERROR_FILE_NOT_FOUND` is no error (`isLink` FALSE, TRUE returned - the caller's own open reports it).
FALSE = do not go on with this key (`skip` tells Skip from Cancel).

## `BOOL SafeDeleteRegLink(int root, LPWSTR key, int errorTitle, BOOL& skip, BOOL& skipAll)`

Opens `root\key` with `REG_OPTION_OPEN_LINK`, `DELETE | KEY_QUERY_VALUE`; re-reads
`SymbolicLinkValue` on that handle (must be `REG_LINK`, else `ERROR_NOT_SUPPORTED` - never deletes a
handle that is no link); `NtDeleteKey(handle)`; NTSTATUS mapped by `RtlNtStatusToDosError`. Errors
in the existing box `IDS_DELETE` (Retry repeats the whole sequence). TRUE = removed.

## Delete (`CPluginFSInterface::DeleteKey`, fs3.cpp)

First thing of every level (after the cancel test): `SafeRegKeyIsLink(..., IDS_DELKEY, ...)`; a link
-> `return SafeDeleteRegLink(...)`; nothing is enumerated or deleted through it.

## Move (`CopyOrMoveKeyRec`, fs5.cpp, `move` TRUE)

First thing of every level (after the cancel test): `SafeRegKeyIsLink(source)`; while a link:
`RegOperationError(ERROR_NOT_SUPPORTED, IDS_REMOVESOURCE, errorTitle, sourceRoot, source, &skip,
&skipAllErrors)` - Retry checks again, Skip / Skip All / Cancel return FALSE before anything is
opened for copying or written. Copy (`move` FALSE): no test, unchanged.
