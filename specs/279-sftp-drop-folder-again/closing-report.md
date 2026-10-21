# Closing report - 279-sftp-drop-folder-again
Backlog item: sftp-a-folder-uploaded-again-into-an-upload-only-folder - SFTP: a folder uploaded again into an upload-only folder fails with Cannot create directory
Outcome: closed

## What changed

- `src/plugins/sftp/sftputils.h/.cpp`: three pure rules - `SftpUnconfirmedDir` (the folder's
  creation refused with FAILURE / FILE_ALREADY_EXISTS and its `stat` refused for want of a right,
  both on a live session), `SftpEndsUnconfirmedDir` ("no such file / path" while nothing of the
  folder is confirmed), `SftpUnconfirmedDirVerdict` (confirmed / nothing confirmed / not there).
- `src/plugins/sftp/operats.cpp`: `UploadDirLevel` takes such a folder as "unconfirmed": its items
  are uploaded (files by 258's exclusive create) and report through `CUploadItemNote` whether the
  server confirmed them. Zero confirmed -> one "Cannot create directory" box naming the folder
  ("the server does not show whether the folder is there; nothing of it was confirmed to arrive",
  or "... the folder is not there"), xrFailed - a Move keeps the local folder. Something confirmed
  -> as a folder that exists (a Move removes it when every item was moved). Every other path
  (every other caller passes NULL) behaves as before.
- `src/plugins/sftp/test/harness.cpp`: 26 checks with negatives.
- No UI string, no plug-in interface, no stored data changed.
- `CHANGELOG.md` (0.1.11 — unreleased), `specs/FEATURE-HISTORY.md`, 258's probe header (DROPDIR2
  superseded).

## Measurements (before / after, commands)

- Before (3541e7ad, `.\build.cmd`, 258's probe `-Only DROPDIR2,DROPHOLE,DROPDIR`): DROPDIR2 -
  `mkdir /drop/pack2` FAILURE, `stat` DENIED, box "Cannot create directory "/drop/pack2": SFTP
  error 4: Failure", `c.txt` not sent.
- Feature probe `specs/279-sftp-drop-folder-again/probe/sftp279_probe.ps1` (hidden desktop;
  `dropsftp.py` + OpenSSH container `tandem-sftp`):
  - before (plug-in sources of 3541e7ad): PASS 12, FAIL 8 (`probe/result_before.txt`);
  - after: **PASS 20, FAIL 0, NOT DRIVEN 0** (`probe/result_after.txt`, also after review 1's fix);
  - negative control (zero confirmed taken as there, as the rejected a5100148): DROPHOLE,
    DROPEMPTY, OSSHLINK FAIL - the local folder DELETED (`probe/result_negative.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED, no warning in the SFTP sources.
- SFTP rule harness (`src/plugins/sftp/test/build_and_run.cmd`): 265 passed, 0 failed (239 before).
- saltests: not run - nothing in the core or `src/common/` changed.
- Feature probe 20 / 0; 258's probe (`probe/regress_258.txt`): every row but DROPDIR2, whose
  expectation was the limit removed here; 133's probe (`probe/regress_133.txt`): 76 / 0. Registry
  restored and identical in every run.

## Reviews (findings and what was done)

- Review 1 (refute-first): no MUST. SHOULD-1 (the "only while nothing is confirmed" rule did not
  reach the product - a literal 0) fixed: the note carries the folder's count. SHOULD-2 (the
  temporary-file site not driven) recorded as by reading. NOTE-1 / NOTE-2 (extra / misleading
  folder box) -> Inbox. NOTE-3, NOTE-4 recorded. The reviewer drove FR-007 (lost connection: no
  folder box, data kept) and its own negative control (the stop after "not there" removed ->
  detected). Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- `sftp-a-folder-uploaded-again-into-a-real-upload-only-service` - check on a real upload-only
  service (SFTPGo / a hosted drop box).

## New Inbox items (slug - title)

- `sftp-a-folder-uploaded-again-whose-files-are-all-there-ends` - SFTP: a folder uploaded again
  whose files are all there ends with a misleading folder box
- `sftp-a-folder-uploaded-again-into-a-real-upload-only-service` - SFTP: a folder uploaded again
  into a real upload-only service (279)
