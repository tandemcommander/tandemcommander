# Data model - 348-ftp-lock-user-port

## Opened-file lock entry (`CFTPOpenedFile`, in memory, per program instance)

| Field | Role after 348 |
|---|---|
| UID | identifier returned to the caller, used by `CloseFile` |
| AccessType | read / write / delete / rename - decides conflicts (`IsInConflictWith`, unchanged) |
| User | stored for diagnostics; **not** part of the identity (348) |
| Host | stored for diagnostics; not part of the identity (347) |
| Port | stored for diagnostics; **not** part of the identity (348) |
| Path, PathType | identity: `FTPIsTheSameServerPath(PathType, Path, path)` |
| Name | identity: exact for case-sensitive server types, `SalNameOrderEqualCI` otherwise |

Rule: two entries are maybe the same file when path and name match; a new access is refused when
such an entry exists and the access types conflict. No state transitions change.
