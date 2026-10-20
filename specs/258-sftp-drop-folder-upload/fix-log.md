# Fix log: feature 258 - SFTP upload into drop folders, limits of a replacement, left temporary files

From backlog item `sftp-replace-keeps-links-acls-drop-dirs` (review leftover of 139).

## 2026-10-20 - measured on main at 2807bbc4 (before specify)

- Docker Desktop was not running; started with `docker desktop start` (container `tandem-sftp`
  came up; to be stopped again at the end of the run).
- **Unix write-only folder on OpenSSH works**: in the container, `/home/tctest/m257/drop733`
  (root:root 0733) and `drop1733` (1733). A paramiko replay of the plug-in's request sequence
  (`seq.py`: lstat target -> "no such file", open `.tcpart-12345678` CREAT|EXCL -> ok, lstat /
  stat temp -> ok, posix-rename -> ok; only the listing is refused). So the review's "drop
  directory fails the size confirmation" does not hold for OpenSSH.
- **A server that refuses to show files in an upload-only folder** (SFTPGo "upload" without
  "list", hosted drop boxes) - modelled by `probe/dropsftp.py` (paramiko server; `/drop` refuses
  stat, lstat, fstat, opendir, rename, remove, setstat with PERMISSION_DENIED, allows an
  exclusive create). Replay: lstat target DENIED, open temp ok, stat temp DENIED, posix-rename
  DENIED.
- **GUI probe before** (`probe/sftp258_probe.ps1`, then still named sftp257 in a temp folder -
  the header line of `probe/result_before.txt` says so; Debug build of 2807bbc4, hidden desktop):
  PASS 7, FAIL 5:
  - DROPNEW / DROPMOVE / DROPDIR FAIL: `Cannot upload "/drop/up.txt": Permission denied.` - the
    item fails at the FIRST lstat of the target (`StatEx` = sxError), before any data; nothing
    arrives, the Move keeps its source.
  - DROPEXIST PASS (guard row: the existing drop file is untouched - because nothing works).
  - REPL FAIL: the question is "The file already exists on the server: /pub/r.txt Overwrite it?
    (Yes = this file, No = skip; Cancel = skip the rest)" - no word of links or ACL.
  - CUT FAIL: `Cannot upload "/cut/c.txt": The connection to the server was lost. (close: Error
    waiting for status message) (the temporary file .tcpart-0a1c25be could not be removed)`;
    the file stayed on the server. The second Copy of the row showed no dialog at all (to be
    looked at with the fixed build).
- **Hard links** (container, replay): `a.txt` + hard link `b.txt` ("OLD"); temp written "NEW",
  posix-rename over `a.txt` -> `a.txt` "NEW" (new inode 312765), `b.txt` "OLD" (312767, link
  count 1). Split, as the item says.
- **ACL / extended attributes**: no ACL tools in the container; by reading - SFTP version 3
  attributes carry neither, a new inode has none of the old file's.
- `BL verify` recorded.

## Decisions (autonomous run)

See spec *Clarifications* / *Assumptions*: links and ACL stated in the question; left temps
remembered in memory per session and offered at the next upload; drop route only on a
permission status; confirmation by acknowledgments only when the size request is refused with
a permission status.

## Analyze

- Run 1: HIGH F1 (spec edge case "the rest stay recorded" vs data model "nothing is put back"),
  MEDIUM F2 (SC-001 counted the guard row), MEDIUM U1 (negative control vague), LOW C1 (FR-004
  without a task). All fixed in spec / data-model / tasks.
- Run 2: no finding; coverage 100 % (10 requirements, 16 tasks).

## Implementation (2026-10-20)

- `sftputils.h/.cpp`: `SftpUploadConfirmation` (ucNo / ucBySize / ucByAcks),
  `SftpTargetStatRefused`, `SftpIsUploadTempPath`. Harness (`test/build_and_run.cmd`):
  **239 passed, 0 failed** (22 new checks, among them the negatives: a wrong reported size is
  never outvoted by acknowledgments, status 0 / 2 / 4 / 7 / 8 / 10 and a dead session are no drop
  route, upper-case / 7 / 9 hex digits / a temp-like folder name are not ours).
- `operats.cpp`:
  - `UploadSendAndConfirm`: `StatEx` instead of `Stat`; a size request refused with a permission
    status (live session) confirms by the acknowledged bytes (+ the checked close), one log line.
  - `UploadOneFileImpl`: `lstat` refused with a permission status -> `UploadDropRoute`
    (exclusive create under the name, no fallback; send + confirm; on failure / stop one
    `Unlink`, the box says when a partial file may remain). The Move tail moved into
    `UploadFinishMove` (shared by both routes, unchanged code).
  - `ConfirmOverwriteRemote`: one more paragraph (hard links, ACL, extended attributes).
  - `UploadDropTemp`: a temp whose removal failed on a dead session is remembered
    (`CSFTPSession::NoteLeftTemp`); `UploadOfferLeftTemps` at the start of `SFTPUploadToFS`
    (before the wait window): one Yes / No question with the full paths; Yes = `lstat` (not
    followed) -> regular file -> `Unlink`; failures logged, the first named in one box; a file
    whose deletion could not be asked because the session died again is remembered again.
- `session.h/.cpp`: `LeftTemps[16]` + `LeftTempCount`, `NoteLeftTemp`, `TakeLeftTemps`; freed in
  the destructor, untouched by `Disconnect` (a reconnect reuses the object).
- No new UI strings (English literals, as 139). No plug-in interface change.
- Build: `build.cmd` BUILD SUCCEEDED; the three SFTP sources recompiled with /W3: no warning.
- Encoding guard: `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).

## Measured after

- Probe `probe/sftp258_probe.ps1` (hidden desktop, Debug build of the branch): DROPNEW,
  DROPEXIST, DROPMOVE, DROPDIR, REPL, CUT all PASS (12 / 0 with the END rows). Server log:
  `lstat /drop/up.txt DENIED` -> `open flags=0x501` (WRITE|CREAT|EXCL) -> `close` -> `stat
  DENIED` -> confirmed; DROPEXIST: `open ... FileExistsError` -> box "SFTP error 4: Failure -
  the server does not show whether a file of that name is there; nothing was replaced", the old
  file keeps "OLD-DROP". REPL's question shows the new paragraph. CUT: after the cut, the second
  Copy asks "Earlier uploads lost the connection ... /cut/.tcpart-24d95865 Delete them now?",
  Yes -> the temp is gone, `c.txt` arrives.
- Row DROPFAIL added afterwards (139's debug seam `TC_SFTP_PROBE_XFER_FAIL=big.bin;1000`): the
  write fails after 1,000 bytes, `remove /drop/big.bin DENIED`, the box: "Cannot write to the
  remote file. - a partial file may remain on the server under this name (Permission denied.)";
  the local file stays. PASS.
- Probe trap: in the first after-run the CUT row's second Copy (posted right after the
  reconnect that the refresh of the failed operation made) opened no dialog - as in the before
  run. The row now reads the active panel's path (`Get-Loc`, a Change Directory round trip)
  before a repeated command and presses Tab if the server panel is active; the Tab was never
  needed - the round trip alone made the command arrive. Cause not determined (timing of the
  probe against the refresh); nothing of the product changed for it.

## Checks (final)

- Feature probe `probe/result_after.txt`: **PASS 14, FAIL 0, NOT DRIVEN 0** (DROPNEW, DROPEXIST,
  DROPMOVE, DROPDIR, DROPFAIL, REPL, CUT + their END rows); registry restored + identical
  (SHA-256 CBAC630F...8C15E8); fixture removed.
- Before (`probe/result_before.txt`, build of 2807bbc4): PASS 7, FAIL 5 - DROPNEW, DROPMOVE,
  DROPDIR, REPL, CUT fail (DROPFAIL did not exist yet; DROPEXIST is a guard row).
- Negative control for CUT (the offer call disabled with `FALSE &&`, rebuilt, `-Only CUT`,
  `probe/result_negative_cut.txt`): FAIL - `.tcpart-1ac87a98` stays, no question - while its
  second Copy did run (c.txt arrived): the row detects a missing offer, not only a lost
  command. Code restored (grep "NEGATIVE CONTROL" = 0), rebuilt, the whole probe run again.
- Regression: 133's SFTP probe on the container `tandem-sftp` (`probe/regress_133.txt`): **PASS
  76, FAIL 0** - the same count as 205's last run; the 139 rows UPASKNO, UPASKYES, UPFAIL,
  UPNEWFAIL, UPSYM, UPMV, UPMOVE, UPLINK pass.
- Harness 239 / 0 (241 / 0 after review 1); encoding guard TOTAL 0; `build.cmd` BUILD SUCCEEDED.
- 133 regression re-run after review 1 (UploadDirLevel changed): **PASS 76, FAIL 0** (UPMOVE, the
  folder the server cannot create, still fails that folder with its reason).
- saltests: not run - nothing in the core or `src/common/` changed.

## Not driven / owed

- A real upload-only service (SFTPGo with only the "upload" permission, a hosted drop box):
  modelled by `dropsftp.py`; owed to a person with access to one.
- An ACL / extended attributes on a replaced file: no tools in the container; by reading.

## Review

### Review 1 (independent agent, refute-first) - no MUST

It re-ran the harness (239 / 0), the probe (14 / 0), 133's probe (76 / 0), and a mutation of the
drop route (`OpenWriteNew` -> `OpenWrite` with truncation), restored by `git checkout` and rebuilt.
- **SHOULD-1** DROPEXIST tested the test server, not the product: `dropsftp.py` itself refused a
  truncating open of an existing `/drop` file, so the mutated build passed the row. With a server
  allowing the overwrite (an "upload + overwrite, no list" account) the mutated build FAILED
  (`drop\up.txt` became 'DROP-NEW') and the real build passed. -> **Fixed**: `dropsftp.py` now
  allows any write open in `/drop`; DROPEXIST passes only through the exclusive create (server
  log: `open /drop/up.txt flags=0x501 exists=True` -> `FileExistsError`).
- **SHOULD-2** "an existing file is never touched" holds only on a server that honours EXCL; one
  that ignores it would be written over (and a failed upload would unlink it). No client-side
  remedy -> **CHANGELOG limitation qualified**; the check on a real service is owed to a person.
- NOTE-1 the offer's "they hold only copies" assumes an atomic rename (unlikely otherwise) - kept.
- NOTE-2 drop-route branches "removal succeeded" / "stopped" not driven - recorded here.
- NOTE-3 a temp is remembered only when `IsConnected()` is already false (older 139/140 limit).
- **NOTE-4** a folder uploaded again into a drop folder failed at `Mkdir` ("SFTP error 4") ->
  **fixed in scope** (the item: "succeeds (or says why)"): `SftpMkdirMayExist` (FAILURE /
  FILE_ALREADY_EXISTS) + a `stat` refused for want of a right = the folder is taken as there,
  its files take the drop route. A Mkdir refused for a right still fails with its reason (no
  box per file). Harness 241 / 0 (2 new checks); new row DROPDIR2. Negative control: DROPDIR2 on
  the build without the change (`probe/result_negative_dropdir2.txt`) FAILS ("Cannot create
  directory"); DROPEXIST there PASSES against the permissive server (the exclusive create).
- NOTE-5 a target in a folder the account cannot enter on plain OpenSSH now reads "Permission
  denied. - the server does not show whether a file of that name is there; nothing was
  replaced" - true, kept.
- NOTE-6 contract drift (name form checked at recording; text position) -> contract corrected.
- NOTE-7 the lost command after the reconnect -> Inbox item
  `sftp-a-copy-posted-right-after-a-failed-upload-and-its` (measure:258).
- After the fixes: build clean (no warning), harness 241 / 0, probe `probe/result_after.txt`
  **16 / 0** (DROPDIR2 added), encoding guard TOTAL 0.

### Review 2 (independent agent, refute-first) - MUST-1 in the code added after review 1

- **MUST-1** the folder "taken as there" (a5100148): a Move of an EMPTY local folder whose `Mkdir`
  answered FAILURE and whose `stat` was refused deleted the local folder - nothing had reached
  the server, no box; also on plain OpenSSH (an empty folder moved onto a symbolic link into a
  root 0700 folder: `mkdir` -> 4, `stat` -> 3). Reproduced by the reviewer on the a5100148 build
  (rows RVEMPTYMV, RVOSSH FAIL; RVEMPTYCTL in `/pub` PASS).
- NOTE-1 the same branch gave one box per file (also on OpenSSH).
- Verified sound: the drop route, the confirmation by acknowledgments, the left-file record and
  offer (every `UploadDropTemp` caller walked), the callers, UTF-8 / path rules; probe 16 / 0,
  harness 241 / 0 reproduced.
- **Fix: the change of `UploadDirLevel` is reverted** (sources = 3ef7774a, the state review 1
  checked; `SftpMkdirMayExist` and its 2 checks gone). A folder uploaded again into a drop folder
  fails with "Cannot create directory" as in 139 - a recorded limit, Inbox item
  `sftp-a-folder-uploaded-again-into-an-upload-only-folder` (leftover:258) with the reviewer's
  cases and an approach. Rows: DROPDIR2 is now a Move that must fail with the folder named and
  keep the local files; new row DROPHOLE = the reviewer's RVEMPTYMV (Move of an empty folder
  onto a file in `/drop`: box, local folder kept, the server's file unchanged). Their negative
  control is the reviewer's run on the a5100148 build (RVEMPTYMV FAIL).
- After: harness **239 / 0**; build clean; probe `probe/result_after.txt` **PASS 18, FAIL 0**;
  registry restored + identical.
- 133 regression after the revert: **PASS 76, FAIL 0** (`probe/regress_133.txt`).

### Review 3 (independent agent, refute-first) - no MUST

Re-ran: revert complete (`git diff 3ef7774a HEAD -- src` empty), harness 239 / 0, encoding guard
0, probe 18 / 0 (registry identical), libssh2 acked-bytes semantics, every caller of the changed
functions, session reuse across accounts (refused by `fs.cpp`), path / UTF-8 rules.
- **SHOULD-1** on a server that ignores EXCL the drop route wrote the new bytes over the old file
  without truncating: reproduced (`newOLDOLDOLD`, Move deleted the source, no box). **Fixed**:
  the drop route's create adds TRUNC (`OpenWriteNew(path, mode, TRUE)`; the temp route keeps
  `0x501`). New test-server folder `/dropnx` (ignores EXCL) and row DROPNOEXCL. Negative control
  on the build without TRUNC (`probe/result_negative_noexcl.txt`): FAIL, `NEW-NXOLDOLDOLD`, the
  source gone; with the fix PASS, `NEW-NX`. CHANGELOG limitation now says such a server lets the
  upload replace the file (old content lost, the new file complete).
- NOTE-1 a create without an answer may leave an empty file under the name -> contract row D2a.
- NOTE-2 not driven: FR-007 (a kept only-copy temp never recorded - by reading: those paths never
  pass through `UploadDropTemp`), FR-008 (a recorded path no longer a regular file), the "No"
  answer, re-recording when the connection dies during the offer. Recorded here as not driven.
- **NOTE-3** low memory in the offer: two conversions of one path (size, copy) could differ ->
  `strcat_s` overflow; a failed message counted as "No". **Fixed**: each path converted once
  (`SplLegacyToU8Alloc`), the list copied by `memcpy` with the measured lengths; when the list or
  the message cannot be made, nothing is decided - the files are remembered again and offered at
  the next upload (log line).
- NOTE-4 the question's paragraph warns also when the route will be "in place" (a link, set-id
  bits) - it errs toward warning; kept.
- After: harness 239 / 0; build clean (no warning); probe `probe/result_after.txt` **PASS 20,
  FAIL 0** (DROPNOEXCL added); registry restored + identical.
- 133 regression after the review 3 fixes: **PASS 76, FAIL 0** (`probe/regress_133.txt`).
