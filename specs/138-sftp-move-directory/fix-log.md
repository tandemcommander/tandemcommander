# Fix log: feature 138 - SFTP, a moved directory leaves the server

Branch `138-sftp-move-directory` from `137-names-cut-at-byte`. Session 2026-10-13 ("fix what you
can"). Spec, plan and tasks first.

## 1. Before (`probe/move_before.txt`, the build of 137)

| Row | Result |
|---|---|
| M1 - move a directory of 30 files | 30 files local; **the directory and all 30 files still on the server**, no message |
| MTREE - a tree with sub-directories and an empty directory | copied; the whole tree still on the server |
| MKEEP - a tree with one unreadable file | the readable files copied; **everything** still on the server |
| MSKIP - a local file exists, answer No | the local file untouched; everything still on the server |
| M2 - move one file | moved (a top-level file was unlinked without any check of the copy) |

## 2. The change (`src/plugins/sftp/operats.cpp`)

- Every item removes its own source when - and only when - it arrived whole:
  `RemoveMovedFile` asks the server for the source's size again, reads the local file's size,
  and unlinks only when both are known and equal (`SftpMoveMayRemove`, `sftputils.cpp`, checked
  in the harness). A directory is removed when every item in it was moved.
- With a move the local file is flushed before it counts; a failed close is reported (it was
  not seen at all, also in a plain copy).
- The top level's "best-effort `Rmdir`" and unchecked `Unlink` are gone.

## 3. Independent review - one real loss path, found before anything was committed

- **Two remote names that are one local file** (`A.txt` / `a.txt`; `a:b` / `a?b` -> `a_b`;
  trailing dots; an 8.3 alias): the second download asked the ordinary "the local file already
  exists - overwrite?" (or "resume?"), replaced the first one's content, and the move removed
  **both** sources with one content left. Inside a directory this became possible with this
  feature. Now the operation remembers the files it wrote by identity (volume and file
  index, `COperationCtx::Written`); a local file of that list is never written again - the
  second item fails with a message and its source stays.
- **Resume in a move** removed the source on a size match although only the tail came from the
  server: a move does not offer resume.
- **A local directory that could not be created** (a file in its place) and an empty remote
  directory: the remote one was removed with nothing local. The local directory is checked.
- An account that may not delete showed one box per file: the box is shown once per
  operation, the rest goes to the log.
- The panel was not refreshed after a move that did not end whole.
- Two messages named a reason that was not checked ("disk full", "its size differs").

Found sound: a read error is never taken for the end of a file; skipped items keep their
parents; a symbolic link to a file is unlinked as a link; the core does nothing destructive on
either return value; plain copy changes only in reporting a failed close.

## 4. Results (`probe/move_result.txt`)

| Row | Result |
|---|---|
| M1 | 30 files local, the directory gone from the server |
| MTREE | 3 files and the empty directory local, the tree gone |
| MKEEP | left on the server exactly `./sub ./sub/secret.txt`; the rest local and gone; the reason shown |
| MSKIP | left on the server exactly `./exists.txt`; the local file untouched |
| MCASE (`A.txt`, `a.txt`, `b.txt`) | one of the pair local with its own content, **the other still on the server**, `b.txt` moved, the collision said |
| MBLOCK (a file where the local folder should go) | the remote tree untouched, an error shown |
| LISTMOVE, P5M (rows of 133 that must not remove) | nothing removed |
| whole SFTP probe | 40 / 0 before the review fixes; the 7 move rows 14 / 0 after them |
| SFTP harness | 111 passed, 0 failed |

## 5. Left

- A move's source is confirmed by size, not by content (the protocol has no checksum).
- The fixed English reasons ("another item of this operation ...", "the local copy could not
  be confirmed complete ...") are not translated (a new string each).
- Upload direction (disk to server) was not changed or re-examined here.
