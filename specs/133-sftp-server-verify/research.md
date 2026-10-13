# Research: feature 133

## R1 - What does a listing do when a read fails? (read)

- `CSFTPSession::ListDir` (`session.cpp`): `rc = libssh2_sftp_readdir_ex(...)`; `if (rc <= 0)
  break;` and the function returns TRUE. `rc == 0` is the end of the directory; `rc < 0` is an
  error (`LIBSSH2_ERROR_BUFFER_TOO_SMALL` for a name over 2,047 bytes, a socket or protocol
  error, a timeout). Out of memory for an entry also leaves the loop and returns TRUE.
- **Decision**: TRUE only after `rc == 0`. Cancel stays as it is (TRUE with the caller's cancel
  flag set - every caller checks the flag).

## R2 - Does a move delete what it did not download? (read; the probe confirms)

- `SFTPDownloadFromPanel` (`operats.cpp`): for each selected item, after `xrOk` and `move`:
  a file is unlinked; **for a directory only `Rmdir` is tried** ("best-effort; fails (kept) if
  not fully emptied"). `DownloadDir` deletes nothing.
- So a partial listing loses nothing on the server. It also means: **a move of a directory never
  removes the directory** - its files are downloaded and all stay on the server, silently. That
  is a functional gap, safe; whether it is intended is recorded, not changed here (deleting
  children needs its own "everything of this subtree was transferred" rule and tests).
- **Decision**: the recommendation's "second place where data may be at stake" is wrong as
  stated; the fix of R1 is still due (a partial copy reported as complete; a partial panel).

## R3 - How does a probe connect?

- A typed address `sftp://tctest@localhost:2222/home/tctest/...` reaches
  `CPluginFSInterface::ChangePath`; with no matching bookmark it asks for the password
  (`IDD_PASSWORD`, edit 630) and, for an unknown host, shows the host key dialog (`IDD_HOSTKEY`,
  buttons 643 "trust" / 644 "once"). Both are ordinary dialogs the probe can answer; the host
  key store is in the product's registry key, which the probe restores.
- The server's state is read and prepared with `docker exec -u tctest tandem-sftp bash -c ...`.

## R4 - Which rows of 131 can be driven?

- R1 delete in a read-only directory, R2 create directory there, R3 download of an unreadable
  file, R4 upload into the read-only directory, P1 enter the deep link, P4 delete the tree,
  P5 download the tree: F-key commands and dialogs of the core - drivable.
- R5 (stale reason after a failed Quick Rename) and P2 / P3 (typed names of 250 characters)
  need the Quick Rename / Create Directory fields: attempted with the dialog's edit control; a
  row that cannot be driven is recorded as NOT DRIVEN with the step owed to a person.

## R5 - A name longer than 2,047 bytes

- Linux file systems limit a name to 255 bytes (`getconf NAME_MAX` in the container: 255), so
  the test server cannot hold one. Covered by the unit check of the classification
  (`LIBSSH2_ERROR_BUFFER_TOO_SMALL` = error) and the seam; recorded as not measured for real.
