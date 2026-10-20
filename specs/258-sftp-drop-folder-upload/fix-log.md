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
- Harness 239 / 0; encoding guard TOTAL 0; `build.cmd` BUILD SUCCEEDED.
- saltests: not run - nothing in the core or `src/common/` changed.

## Not driven / owed

- A real upload-only service (SFTPGo with only the "upload" permission, a hosted drop box):
  modelled by `dropsftp.py`; owed to a person with access to one.
- An ACL / extended attributes on a replaced file: no tools in the container; by reading.
