# Data model - feature 258

## Left temporary file record (per `CSFTPSession`, memory only)

| Field | Meaning |
|---|---|
| `LeftTemps[16]` | heap copies (malloc) of full server paths of `.tcpart-XXXXXXXX` files |
| `LeftTempCount` | 0..16 |

- Added by `UploadDropTemp` when `Unlink(temp)` failed AND the session is no longer connected
  (the removal could not be asked), and the path is an upload temporary name
  (`SftpIsUploadTempPath`). A duplicate path is not added twice; a 17th is only logged.
- Taken (all at once, record emptied) at the start of `SFTPUploadToFS` when the session is
  connected; the user's answer decides (No = never asked again; a deletion the server refuses
  is named in one box and logged). A file whose deletion could not be asked because the
  session died meanwhile is recorded again (the same rule as above).
- Freed in `~CSFTPSession`. `Disconnect` keeps it (the FS reconnects through
  `Disconnect` + `Connect` on the same object).

## Pure helpers (`sftputils`)

- `SftpTargetStatRefused(connected, status)`: TRUE = connected and status 3 / 12
  (PERMISSION_DENIED, WRITE_PROTECT) - the drop route.
- `SftpUploadConfirmation(sizeKnown, remoteSize, sizeRefused, bytesSent, localSize)` ->
  `ucBySize` (as `SftpUploadConfirmed`), `ucByAcks` (size not known, the request was refused
  with a permission status, `bytesSent == localSize`), `ucNo`.
- `SftpIsUploadTempPath(path)`: the base name is exactly `.tcpart-` + 8 lower-case hex digits
  (the form `SftpTempPath` makes).
