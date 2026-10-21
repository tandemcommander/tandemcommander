# Research: 279 - a folder uploaded again into an upload-only folder

## R1 - When is a folder "unconfirmed"?

- **Decision**: the `mkdir` failed with SSH_FX_FAILURE (4) or SSH_FX_FILE_ALREADY_EXISTS (11) on a
  live session, AND the following `stat` (followed) failed with a permission status (3 / 12, 258's
  `SftpTargetStatRefused`) on a live session.
- **Rationale**: 4 is what OpenSSH and paramiko answer for an existing name (EEXIST), 11 the
  protocol's own status; 3 / 12 is how an upload-only folder refuses to show. Any other pair
  (mkdir refused for a right, no space, no status = lost) keeps today's box.
- **Alternatives**: take every failed mkdir + refused stat (rejected: a refusal for a right means
  the folder cannot be made - nothing below can arrive); `stat` with lstat (rejected: the
  folder is followed today; a link to a folder is a folder for the upload).
- **Note**: the old code used `Stat`, which does not record the server's status; `StatEx` does
  (and answers the same "found / not" for the existing branches).

## R2 - What is "confirmed"?

- **Decision**: a file whose upload ended `xrOk` before the Move's local removal (the server
  confirmed every byte - by size, or by 258's acknowledgments), a subfolder whose `mkdir`
  succeeded or whose `stat` showed a folder, a subfolder that is unconfirmed with at least one
  confirmed item. Reported by the item through a `CUploadItemNote` (`Arrived`).
- **Rationale**: each proves the parent folder exists on the server. A Move whose local
  removal failed still confirmed the file (FR-003).
- **Alternatives**: count `r == xrOk` of the item (rejected: in a Move, xrOk = uploaded AND
  removed; a file uploaded but not removed would not count, and the folder box would say
  "nothing confirmed" wrongly).

## R3 - Which creation refusal ends the folder?

- **Decision**: SSH_FX_NO_SUCH_FILE (2) / SSH_FX_NO_SUCH_PATH (10) on a live session, for the
  creation of a file (258's drop route `OpenWriteNew`, or the temporary file of the ordinary
  route) or of a subfolder (`mkdir`), only while the folder has no confirmed item. No box for
  that item; the folder's box names the folder.
- **Rationale**: the item's Approach. OpenSSH answers ENOTDIR (a file in the way) and ENOENT as
  NO_SUCH_FILE. A refusal for a right is not taken: SFTPGo without "overwrite" answers it for a
  file that is already there - the main case of this feature (a folder uploaded AGAIN).
- **Consequence (limit)**: plain OpenSSH, a folder with files moved onto a symbolic link into an
  unreadable folder: every file's create is refused for a right -> one box per file, then the
  folder box; everything stays.

## R4 - The folder's box

- **Decision**: `IDS_ERR_MKDIR` ("Cannot create directory "%s": %s") with the mkdir's reason and
  an English tail: nothing confirmed - "the server does not show whether the folder is there;
  nothing of it was confirmed to arrive"; not there - "a file or folder could not be created in
  it (<reason>): the folder is not there". Shown through `ShowRequestError` (one connection box
  rule of 140).
- **Rationale**: no new UI string (no `.slt` refresh); 258 appended English reasons the same way.

## R5 - The test servers

- **Decision**: a copy of 258's `dropsftp.py` in this feature's probe folder, changed only so that
  `NotADirectoryError` answers SSH_FX_NO_SUCH_FILE (OpenSSH's mapping of ENOTDIR; paramiko's
  `convert_errno` gives FAILURE). Real OpenSSH rows on `tandem-sftp`, prepared as root with
  `docker exec` (a root 0700 folder and a link to it in `/home/tctest/tc279`).
- **Rationale**: the reviewer's OpenSSH case of 258 must be run on OpenSSH itself.
