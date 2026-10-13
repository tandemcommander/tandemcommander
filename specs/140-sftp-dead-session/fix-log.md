# Fix log: feature 140 - SFTP dead session, special files, refused attribute changes

## 2026-10-14

- Source: the final independent review of the SFTP operations (findings M1, M4, M7), left by 139.
- Spec, plan, tasks written before any code. Not taken: which mode a recursive Change
  Attributes gives to directories (needs interface and texts - a decision for the maintainer).

## Before (0.1.9 control build, `probe/before.txt`)

- SPZERO - copy of a link to `/dev/zero`: no message; the local file had 391,770,000 bytes
  when the probe stopped waiting and was still growing; the program did not answer `WM_NULL`
  at the end (the main thread is in the transfer) and had to be ended by the probe.
- SPFIFO - copy of a FIFO: no message, no local file; the program did not answer and had to
  be ended (the open never returns on the server side).
- The rows of the lost connection (DEADCOPY, DEADDEL, DEADMOVE) need the seam and have no
  "before"; the old behaviour is read from the code and the library (see `impl-notes.md`).

## Review

- Refute-first review (code only): no critical finding. Medium, all fixed: `ChangePath`
  returned FALSE on a lost session - on a refresh the core then leaves the file system (it
  reconnects once now); the list of "dead" return codes was a positive list and missed the
  raw results of the automatic keepalive / re-key while the request stays "sent" - inverted
  (dead = every negative code except SFTP_PROTOCOL, BUFFER_TOO_SMALL, BAD_USE); EAGAIN read
  from the session's last errno could end a live session (the library leaves it there after a
  successful read) - the errno route keeps the narrow list of 051. Low, fixed: a temporary
  upload file that stays is always named; refusals counted before a lost connection are still
  said; one stat per link; one log line per failed sub-listing.

## After

- Unit harness 217 / 0; `check_encoding.py` TOTAL 0; Debug build clean.
- SFTP probe, whole, on the build with the review fixes (`probe/after.txt`): **PASS 76,
  FAIL 0, NOT DRIVEN 0**. DEADCOPY: 24 local files, each with its own content, one box naming
  the lost connection, 30 files still on the server. DEADDEL: 6 files left (f10.txt among
  them), one box. DEADMOVE: 24 moved, 6 left, none lost, none in doubt. SPZERO / SPFIFO:
  refused at once with "not a regular file", nothing local, the program ends cleanly.
- Not driven: Ctrl+R on a connection that died while idle (needs a silent death); a refused
  Change Attributes (needs a file of another owner); a real network timeout (the rows use the
  seam, which goes through the same code path as `LIBSSH2_ERROR_TIMEOUT`).
