# Data model - feature 310

## Grouped member

A newc / crc member that is a regular file (`(mode & 0170000) == 0100000`) with `c_nlink` > 1
(`SalCpioIsLinkGroupMember`). Key: (`c_devmajor`, `c_devminor`, `c_ino`).

## Group (per extraction, in `DoUnpackArchive`)

| Field | Meaning |
|---|---|
| state | `NONE` - no data seen yet; `WRITTEN` - the data was written to `writtenTarget`; `LOST` - the data passed and was not written (not asked with nobody waiting, Skip, error) |
| writtenTarget | relative target path the data was written to (source of the copies) |
| dataName | archive name of the member that carried the data (shown in a report) |
| waiting | asked names stored with size 0 that wait for the data: archive name, relative target path, last-write time, attributes |

## Decision (`SalCpioLinkDecide(asked, hasData, state, anyWaiting)`)

| hasData | state | asked | anyWaiting | Action |
|---|---|---|---|---|
| yes | WRITTEN | yes | - | `WRITE` (its own data, as before) |
| yes | WRITTEN | no | - | `SKIP` |
| yes | NONE / LOST | yes | - | `WRITE`, then copy the waiting names (or report them if not written) |
| yes | NONE / LOST | no | yes | `WRITE_FOR_WAITING` (data under the first waiting name, the rest copied) |
| yes | NONE / LOST | no | no | `SKIP` - state becomes `LOST` |
| no | NONE | yes | - | `WAIT` |
| no | WRITTEN | yes | - | `COPY` from `writtenTarget` |
| no | LOST | yes | - | `REPORT` ("file not found", `name -> dataName`); the operation fails |
| no | any | no | - | `SKIP` |

After a `WRITE` / `WRITE_FOR_WAITING`: written -> state `WRITTEN`, every waiting name copied;
not written (Skip, error) -> state `LOST`, the first waiting name reported, the operation fails.

End of the archive (trailer or end of data): every group still `NONE` writes its waiting names as
empty files. An operation that fails before (error, Cancel) writes nothing more.
