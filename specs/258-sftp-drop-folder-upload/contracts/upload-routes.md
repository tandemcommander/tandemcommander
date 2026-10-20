# Contract - the upload's routes after feature 258

Extends the path table of `specs/139-sftp-no-silent-overwrite/impl-notes.md` section 8. Rule
(unchanged): the old content of a server file is never gone unless the complete new content is
under the final name or the user was told the name of the file that holds it; a Move removes the
local source only on a confirmed upload.

## Route choice at the target's `lstat`

| `lstat(target)` | Route |
|---|---|
| found | 139: the question, then temp + rename (or in place for the logged reasons) |
| no such file | 139: temp + rename |
| refused, permission status, session alive | **drop** (new) |
| any other failure | the item fails with the reason (139) |

## The drop route

| # | Step / outcome | Server | Result |
|---|---|---|---|
| D1 | stopped before the create | untouched | failed (no box: the user stopped) |
| D2 | exclusive create refused (exists, permission, unsupported, no answer) | untouched | failed; box: reason + "the server does not show whether a file of that name exists; nothing was replaced" |
| D3 | data / close fail, stopped, or not confirmed | partial file of ours under the name; one `Unlink` tried | failed; box (also after a stop) names it when it stays: "a partial file may remain" |
| D4 | confirmed (by size, or by acknowledgments when the size is refused) | the new file | ok (Move: source removed) |

The overwrite question is never asked on this route (nothing can be replaced).

A folder of an uploaded tree inside a drop folder: created by `Mkdir`; a refused `Mkdir` fails the
folder with its reason as in 139 (also when the folder exists from an earlier upload - the server
does not show it; a recorded limit). A Move keeps the local folder.

## Confirmation of a written file (every route)

`stat(written)`: size known -> 139's comparison. Refused with a permission status on a live
session -> confirmed when every byte of the local file and the close were acknowledged; one log
line. Anything else -> not confirmed (139).

## Left temporary files

Recorded: a temp whose `Unlink` failed on a dead session (UploadDropTemp). Not recorded: the
temp kept as the only copy (139 rows 12, 14, 17, 18) and a temp whose removal the server
refused on a live session; only a path of our name form (`SftpIsUploadTempPath`) is recorded.
Offered once, at the next upload on the same session: Yes = `lstat` each (not followed; a
regular file) -> `Unlink`; No = forgotten. One the session could not ask about is recorded again.

## The overwrite question

Adds, after the button legend: "It is replaced by a new copy where the server allows it: other
hard links to it keep the old content, and its ACL and extended attributes are not carried over."
