# Contract: the unconfirmed folder of an SFTP upload (feature 279)

Internal to the SFTP plug-in; no plug-in interface change. Status numbers are SFTP v3.

## Pure rules (sftputils.h)

| Rule | TRUE exactly when |
|---|---|
| `SftpUnconfirmedDir(mkdirConnected, mkdirStatus, statConnected, statStatus)` | `mkdirConnected` and `mkdirStatus` is 4 or 11, and `SftpTargetStatRefused(statConnected, statStatus)` (3 / 12 on a live session) |
| `SftpEndsUnconfirmedDir(connected, status, confirmed)` | `confirmed == 0`, `connected`, `status` is 2 or 10 |
| `SftpUnconfirmedDirVerdict(confirmed, noFolder)` | `noFolder` -> `udNotThere`; else `confirmed <= 0` -> `udNothingConfirmed`; else `udConfirmed` |

Negatives checked: mkdir 0 / 2 / 3 / 7 / 8 / 12 / 14 / 15, a dead session at either request, a
stat answered 0 / 2 / 4 / 7; a creation refused with 3 / 4 / 11 / 0, or with 2 after a confirmed
item.

## Behaviour (UploadDirLevel)

| # | mkdir | stat (followed) | Behaviour |
|---|---|---|---|
| B1 | ok | - | as today (the folder is made; Arrived) |
| B2 | refused | a folder | as today (it exists; Arrived) |
| B3 | refused (2 / 10) in an unconfirmed parent with nothing confirmed | - | no box; the parent ends `udNotThere` |
| B4 | refused 4 / 11 | refused 3 / 12, live | unconfirmed: items tried, counted; verdict as data-model.md |
| B5 | any other | any other | as today: box "Cannot create directory" with the mkdir's reason, xrFailed, nothing below tried |

## Messages (IDS_ERR_MKDIR + English tail)

- `udNothingConfirmed`: `<mkdir reason> - the server does not show whether the folder is there; nothing of it was confirmed to arrive`
- `udNotThere`: `<mkdir reason> - a file or folder could not be created in it (<creation reason>): the folder is not there`
- Log on B4: `The folder <path> could not be created (<reason>) and the server does not show whether it exists (<stat reason>); its items are tried.`
