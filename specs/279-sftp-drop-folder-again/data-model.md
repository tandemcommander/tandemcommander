# Data model: 279

## CUploadItemNote (operats.cpp, in the heap block CUploadLevel of one folder level)

| Field | Direction | Meaning |
|---|---|---|
| `FolderConfirmed` | in | the items of the unconfirmed folder confirmed so far; with none, a creation refused with "no such file / path" is not shown, only reported (`SftpEndsUnconfirmedDir`; review 1 SHOULD-1: the count reaches the rule) |
| `Arrived` | out | the server confirmed the item (file: written whole; folder: created, shown as a folder, or unconfirmed with >= 1 confirmed item) |
| `NoFolder` | out | (only with `FolderConfirmed` 0) the creation was refused with "no such file / path"; no box was shown |

Passed only by an unconfirmed level to its items; every other call passes NULL (today's behaviour).

## Unconfirmed folder level (UploadDirLevel locals)

| Value | Meaning |
|---|---|
| `unconfirmed` | R1 holds for this level's `mkdir` + `stat` |
| `confirmed` | number of items with `Arrived` |
| `noFolder` | an item reported `NoFolder`: the level stops |

Verdict at the end (pure: `SftpUnconfirmedDirVerdict(confirmed, noFolder)`):

| noFolder | confirmed | verdict | effect |
|---|---|---|---|
| TRUE | (0) | `udNotThere` | box "... the folder is not there", xrFailed, local kept |
| FALSE | 0 | `udNothingConfirmed` | box "... nothing of it was confirmed to arrive", xrFailed, local kept |
| FALSE | >= 1 | `udConfirmed` | as a folder that exists: the Move removes it when every item was moved |

A stop by the user (`Cancelled`) or a lost session ends the level before the verdict: no folder box.
