# Fix log: 220 - SFTP leftovers: F3 on an unreadable file, the teardown of a dead session

Backlog (`specs/NEXT-WORK.md`): left by 140 - "F3 on a file that cannot be opened shows nothing",
"one unclosed handle per lost connection stays allocated until exit", "a reply shorter than the
protocol allows leaves a request half-done until the next timeout"; left by 217's review -
"`Disconnect` tears down with a 1 ms deadline on a dead or cancelled connection - the whole session
leaks".

## Measured (before)

Against the test container (`tandem-sftp`):
- `probe/sftp220_probe.ps1` (205's driver; `probe/fixture220.sh` makes a file of mode 000):
  **VIEW-DENIED - F3 on it: nothing at all** (no error, no viewer); VIEW-OK (a readable file: a
  viewer) and DL-DENIED (F5: "Cannot download ... Permission denied", no local file) as expected
  (`probe/result_before.txt`; its DL-DENIED "local files 1" was the probe's count of an empty
  list - fixed in the probe).
- `probe/sftp220_stall_probe.ps1` + `probe/fakessh.py` mode `stallT` (217's proxy to the container,
  the server's bytes no longer passed 6 s after the connection; then Change Directory waits out the
  plug-in's 30 s timeout): **STALL - "Detected memory leaks!" at the exit, the exit not ending**
  (`probe/result_before_stall.txt`): `Disconnect` gives a dead session 1 ms; the channel's close
  returned EAGAIN, nothing was freed - the SFTP structure, the channel, the whole session.

## Work

`src/plugins/sftp/`:
- `fs.cpp` `ViewFile`: every failure is said ("Cannot download "x": reason") - the cache file not
  made (Windows' reason), the remote file not opened (the server's reason), a read failed (the
  session's reason when it was lost, else "Cannot read from the remote file." - as the download),
  a local write failed (Windows' reason; a short write: disk full); a cancel is not a failure;
- `session.cpp` `Disconnect` (+ `ShutDownSocketForTeardown`, `session.h`): a teardown step that
  fails within its deadline is repeated after `shutdown(SD_BOTH)` of the socket (the handle stays
  valid - libssh2 never reaches another connection reusing a closed handle): the read then fails
  at once, the channel's close callback frees the SFTP structure, the channel and the session are
  freed; a failure even then is logged.

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 6 / 0 (VIEW-DENIED: "Cannot download "secret.txt": Permission denied.");
`probe/result_after_stall.txt` 4 / 0 (STALL: a clean exit, no leak box). Regressions: 205's SFTP
probe 14 / 0, 217's probe 18 / 0 (`probe/regress_*.txt`).

## Review

Refute-first review: accept after one MUST, taken - a read that failed on a live session showed an
old reason (`Read` keeps no reason while connected): now "Cannot read from the remote file." as
the download does. Checked: a second `libssh2_sftp_shutdown` / `libssh2_session_free` after a
timeout resumes their state machines (the packet pointers were cleared; channel_free returns only
0 or EAGAIN) - no double free; the shut socket gives a hard error, never EAGAIN; the same pattern as
`RequestCancel` (under `SocketLock`); a healthy teardown is unchanged (only a teardown that did not
finish within 2 s takes the new path - it leaked before; no "Bye" is sent then). Taken NIT: a short
write reports disk full. Recorded in `specs/NEXT-WORK.md` (libssh2, not covered): a partly sent
packet of an earlier request (a stalled upload) makes the repeated step refuse with EAGAIN - the
session still leaks; SFTP handles left open on a dead session are not freed (`sftp.c` TODO); a
server's SSH_MSG_DISCONNECT skips the channel's close (the SFTP structure leaks). Not measured here:
140's "a reply shorter than the protocol allows" (a wait, no wrong answer).
