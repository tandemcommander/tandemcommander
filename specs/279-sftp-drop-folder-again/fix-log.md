# Fix log: feature 279 - SFTP: a folder uploaded again into an upload-only folder

From backlog item `sftp-a-folder-uploaded-again-into-an-upload-only-folder` (leftover of 258).

## 2026-10-21 - measured on main at 3541e7ad (before specify)

- Read 258's record: review 1 NOTE-4 (the first attempt), review 2 MUST-1 (a Move of an EMPTY
  folder whose `mkdir` answered FAILURE and whose `stat` was refused deleted the local folder -
  also on OpenSSH through a symbolic link into a root 0700 folder), the revert in 03a7ee3d.
  The rejected attempt: `git show a5100148 -- src/plugins/sftp`.
- Site at HEAD: `UploadDirLevel` (`src/plugins/sftp/operats.cpp`) - after a failed `Mkdir`, a
  `Stat` that fails or is not a folder -> `ShowRequestError(IDS_ERR_MKDIR, ...)`, xrFailed,
  nothing below tried. Reached from Copy / Move (F5 / F6) of a local folder into an SFTP panel:
  `SFTPUploadToFS` -> `UploadDirRecursive` -> `UploadDirLevel`.
- `.\build.cmd` (Debug x64 of 3541e7ad): BUILD SUCCEEDED. 258's probe on the hidden desktop,
  `-Only DROPDIR2,DROPHOLE,DROPDIR` (dropsftp.py), PASS 6 / 0 - i.e. the limit is there:
  - DROPDIR2: server log `mkdir /drop/pack2 FileExistsError` -> `stat /drop/pack2 DENIED`; box
    `Cannot create directory "/drop/pack2": SFTP error 4: Failure`; `drop\pack2\c.txt` not
    created, local files kept.
  - DROPHOLE (empty folder onto the file `drop\hole`): the same box, the local folder kept.
  - DROPDIR (a first upload of a folder): arrives.
- Docker Desktop was not running; started with `docker desktop start` for the OpenSSH rows
  (container `tandem-sftp`). To be stopped again at the end of the run.
- `BL verify` recorded.

## Decisions (autonomous run)

See spec *Clarifications*: the folder box also after file boxes (item); only "no such file /
path" ends a folder (item; a refusal for a right is SFTPGo's answer for an existing file);
a subfolder counts when the server created / showed / confirmed something in it; the end by
"no such file" only while nothing is confirmed (conservative).

## Analyze

- Run 1: no CRITICAL / HIGH. MEDIUM I1 (SC-004 counted 258's DROPDIR2, whose expectation this
  feature removes) -> fixed in the spec. LOW U1 (FR-007: a stop / lost connection inside an
  unconfirmed folder has no probe row) and U2 (all items skipped; a file uploaded whose local
  removal failed) -> not driven, checked by reading; recorded here.

## Implementation (2026-10-21)

- `sftputils.h/.cpp`: `SftpUnconfirmedDir` (mkdir 4 / 11 on a live session + stat refused for a
  right on a live session), `SftpEndsUnconfirmedDir` (2 / 10, live, nothing confirmed yet),
  `SftpUnconfirmedDirVerdict` (`udConfirmed` / `udNothingConfirmed` / `udNotThere`). Harness
  (`src/plugins/sftp/test/build_and_run.cmd`): **265 passed, 0 failed** (239 before; 26 new
  checks, with the negatives of the contract: mkdir 0 / 2 / 3 / 7 / 8 / 10 / 12 / 14 / 15, a stat
  answered 0 / 2 / 4 / 7 / 8 / 10 / 11, a dead session at either request, a creation refused with
  0 / 3 / 4 / 11 / 12 or with 2 after a confirmed item, zero / negative confirmed never "there").
- `operats.cpp`:
  - `CUploadItemNote` (in: `QuietNoFolder`; out: `Arrived`, `NoFolder` + reason) and
    `UploadNoteNoFolder`. Passed only by an unconfirmed folder to its items; every other caller
    (`SFTPUploadToFS`, a confirmed folder) passes NULL - the item behaves as before.
  - `UploadDropRoute` and the temporary-file create of `UploadOneFileImpl`: a creation refused
    with 2 / 10 under `QuietNoFolder` -> logged, no box, `NoFolder`. `UploadOneFileImpl` sets
    `Arrived` from the upload's own result, before `UploadFinishMove` (a Move whose local removal
    fails still counts the file as arrived).
  - `UploadDirLevel`: after a refused `Mkdir`, `StatEx` (followed; `Stat` did not record the
    server's status) - a folder: as before; `SftpUnconfirmedDir`: unconfirmed, log line; anything
    else: today's box. A subfolder whose `Mkdir` is refused with 2 / 10 under `QuietNoFolder`:
    no box, `NoFolder`. The loop of an unconfirmed folder counts `Arrived` and stops on
    `NoFolder`. After the loop (Cancelled, list error, then `StopIfSessionLost` first - no folder
    box on a stop or a lost connection) the verdict: not `udConfirmed` -> ONE `IDS_ERR_MKDIR` box
    with an English tail, xrFailed (a Move keeps the folder); `udConfirmed` -> today's Move rule.
    The level's own `Arrived` for its parent: created / shown as a folder, or `udConfirmed`.
  - The new buffers (`MkdirWhy`, `NoFolderWhy`, `ItemNote`) live in the heap block
    `CUploadLevel`, not on the stack of the recursion (139's rule; SFTP_MAX_RECURSION 128).
- No new UI strings (English tails, as 258); no plug-in interface change.
- `.\build.cmd`: BUILD SUCCEEDED, no warning in the SFTP sources (/W3). clang-format (VS 2022
  LLVM) `--dry-run`: no finding in the new lines.
- Encoding guard `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- Test server: a copy of 258's `dropsftp.py`; `NotADirectoryError` also answers NO_SUCH_FILE
  (OpenSSH's ENOTDIR mapping). Measured: on Windows Python already raises FileNotFoundError
  (errno 2) for a path under a file, so the copy behaves like 258's there - the mapping is a
  safeguard only.

## Probe `probe/sftp279_probe.ps1` (hidden desktop)

- Rows: DROPDIR, DROPDIR2, DROPAGAIN, DROPNEST, DROPHOLE, DROPEMPTY, DROPHOLE2 (dropsftp.py on
  127.0.0.1:2279); OSSHCTL, OSSHLINK, OSSHLINK2 (container `tandem-sftp`, fixture279.sh as root:
  `/home/tctest/tc279/x` and `x2` are links into the root 0700 folder `lockd`).
- First after-run: 19 / 1 - DROPHOLE2 counted 2 creations: the test server logs a failed open
  twice (the request and its error); the product asked once (`open /drop/hole2/a.txt` then
  nothing for b.txt). The probe counts request lines only (`flags=`) now - a probe fix.
- **After** (`probe/result_after.txt`, feature build): **PASS 20, FAIL 0, NOT DRIVEN 0**;
  registry restored + identical (SHA-256 BA9B23CF...ADF74).
- **Before** (`probe/result_before.txt`, the plug-in sources of 3541e7ad stashed and rebuilt):
  **PASS 12, FAIL 8** - DROPDIR2 / DROPAGAIN / DROPNEST: the box "Cannot create directory" and
  nothing of the folder sent (the defect); DROPHOLE / DROPEMPTY / DROPHOLE2 / OSSHLINK /
  OSSHLINK2: the local data was kept there too, the rows fail on the box (no "nothing confirmed" /
  "not there" reason - the reason "says little about why", the item's Problem). DROPDIR, OSSHCTL
  pass on both.
- **Negative control** (`probe/result_negative.txt`): the verdict's zero-confirmed branch replaced
  by "taken as there" (what a5100148 did), marked NEGATIVE CONTROL, rebuilt, rows DROPHOLE*,
  DROPEMPTY, OSSHLINK*, DROPDIR2: **DROPHOLE, DROPEMPTY, OSSHLINK FAIL - the local folder is
  DELETED** (review 2 MUST-1 reproduced and detected), OSSHLINK2 FAIL (no folder box); DROPDIR2
  and DROPHOLE2 pass (not on that branch). Code restored (`grep -c "NEGATIVE CONTROL"` = 0), rebuilt.
- Regression, 258's probe (`probe/regress_258.txt`, rows DROPNEW, DROPEXIST, DROPMOVE, DROPDIR,
  DROPFAIL, DROPHOLE, DROPNOEXCL, REPL, CUT - `Want` also matched DROPDIR2 by prefix): PASS 19,
  FAIL 1 - only DROPDIR2's ROW, whose expectation was the limit this feature removes (the folder
  now arrives: "the local pack2\c.txt kept False", no box). 258's probe header says so now.
- Regression, 133's probe on the container (`probe/regress_133.txt`): **PASS 76, FAIL 0** (the
  same count as 258's last run); registry identical.
- After a readability change of `UploadDirLevel` (no empty statement; same logic): rebuilt
  (BUILD SUCCEEDED, no warning), harness 265 / 0, the whole feature probe again:
  `probe/result_after.txt` **PASS 20, FAIL 0, NOT DRIVEN 0**, registry restored + identical.

## Checks (before the review)

- Encoding guard TOTAL 0; `.\build.cmd` BUILD SUCCEEDED; SFTP harness 265 / 0; feature probe 20 / 0
  (before 12 / 8; negative control: the local folder deleted in 3 rows); 258's probe: all rows but
  the superseded DROPDIR2; 133's probe 76 / 0.
- saltests: not run - nothing in the core or `src/common/` changed.

## Not driven / owed

- A real upload-only service (SFTPGo "upload" without "list", a hosted drop box): modelled by
  `dropsftp.py` -> a step added to the person-step item
  `sftp-drop-folder-on-a-real-upload-only-service-and-an-acl-on` (258's).
- FR-007 (a stop or a lost connection inside an unconfirmed folder: no folder box), a folder whose
  items are all skipped, a file uploaded whose local removal fails in a Move: by reading.

## Limits

- A creation refused for want of a right inside an unconfirmed folder stays the file's own box
  (OSSHLINK2: the file's box, then the folder box; everything kept) - research R3: SFTPGo answers
  so for a file that is already there, the main case of "uploaded again".
- With nothing confirmed, the folder box comes also after the files' own boxes (the item's rule).
