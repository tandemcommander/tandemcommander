# Data model - 264-remembered-drive-reconnect

## Remembered connection (Windows' data, read-only for this feature)

| Field | Source | Notes |
|---|---|---|
| letter | `WNetEnumResourceW` `lpLocalName` ("Z:") | |
| remote path | `WNetEnumResourceW` `lpRemoteName` | wide, exact; at most 259 UTF-16 units for the SMB redirector (research R1); heap |
| saved remote path | `HKCU\Network\<letter>\RemotePath` (REG_SZ) | matched to the remote path by `SalNetDriveSameRemote` |
| saved user name | `HKCU\Network\<letter>\UserName` (REG_SZ) | empty / missing -> the current user |
| provider | `HKCU\Network\<letter>\ProviderName` (REG_SZ) | missing -> none (Windows finds it) |

States of a letter for this feature: *remembered and not listed* (reconnect),
*remembered and listed but not answering* (the "listed" recovery via the UNC path),
*not remembered* (nothing to do). Windows updates the profile on a successful reconnection
(`CONNECT_UPDATE_PROFILE`), as before; the program writes nothing.
