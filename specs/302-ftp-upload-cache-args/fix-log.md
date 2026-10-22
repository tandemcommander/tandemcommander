# Fix log - 302-ftp-upload-cache-args

Backlog item `ftp-panel-mkdir-rename-skip-upload-listing-cache` - FTP: Create Directory and Quick
Rename in a panel never update the upload listing cache. Run started from `main` at 02eba55f.

## Measurement at HEAD (02eba55f), by reading

- `src/plugins/ftp/ctrlcon5.cpp`, `CControlConnectionSocket::CreateDir`: two calls
  `UploadListingCache.ReportCreateDirs(hostBuf, userBuffer, portBuf, ...)` (created / result
  unknown); `CControlConnectionSocket::QuickRename`: two calls
  `UploadListingCache.ReportRename(hostBuf, userBuffer, portBuf, ...)` (renamed / result unknown).
- Declarations (`operats.h`, `CUploadListingCache`): `(const char* user, const char* host,
  unsigned short port, ...)`. `CUploadListingCache::FindServer` (`operats9.cpp`) compares
  `server->Host` with the host argument (`StrICmp`) and `server->User` with the user argument
  (`strcmp`, anonymous = NULL). With the arguments swapped no server matches unless the user name
  equals the host name - the report is dropped.
- Every other `UploadListingCache.*` caller (Grep: `operats1/3/4/8/a/b.cpp`, `fs2.cpp`, `fs3.cpp`,
  `fs5.cpp`) passes `(user, host, port)` - only these four are swapped.
- Lifetime: the cache holds a server only while an upload operation to it exists
  (`CFTPOperationsList::DeleteOperation` -> `RemoveServer` when no upload to that server is left).
- Masking (by reading - **wrong, see the probe**): after F7 / Quick Rename the panel posts a change
  notification for the changed path; the panel's next listing of its own folder calls
  `UploadListingCache.AddOrUpdateListing(..., TRUE /* only update */)` (`fs2.cpp`) and replaces the
  cached listing; an upload into the panel's folder seeds the cache from the panel listing
  (`fs5.cpp`) - but only when no operation can change that folder
  (`!FTPOperationsList.CanMakeChangesOnPath`), which an open upload to it can. Reading expected
  the item's rename row to pass before the fix; it failed (below).
- Not masked: F7 with an absolute path outside the panel's folder (`/other/new` from `/src`): the
  panel refreshes only `/other/new` (CreateDir sets `changedPath` to the new path), and only
  `ReportCreateDirs` (absolute branch: `ReportCreateDir` on the cached listing of `/other` +
  an empty listing of `/other/new`) would tell the cache. An open upload operation then uploads a
  local folder `new` into `/other`: the worker reads the stale listing (`operatsa.cpp`,
  `fwssWorkStartWork`: `existingItem == NULL` -> `fwssWorkUploadCreateDir`) and sends `MKD new`
  instead of joining the existing folder (`UploadDirAlreadyExists = DIRALREADYEXISTS_JOIN` default).

## Probe `probe/ftp302_probe.ps1`

Hidden desktop, one 215 `ftpmini.py` (UTF-8, 127.0.0.1:2131, user `u`), left panel local, right
panel the server; upload 1 of `o1.txt` to a folder that has it keeps the operation open (overwrite
question; the probe leaves the operation threads' windows alone until the verdict, then closes them;
the exit question "Queue still contains some unfinished FTP operations" is expected and answered).

Command (PowerShell, from the repository root):

    powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\302-ftp-upload-cache-args\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\302-ftp-upload-cache-args\probe\ftp302_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"

Probe development (on the unchanged build): first run - both rows "not connected": the row's local
`$srv` (a folder) hid the script's `$Srv` (the server table) - PowerShell names ignore case - so the
URL had no port; renamed to `$FtpSrv`. Second run - END rows failed on the operation windows the
probe keeps open; added `Close-Ops` and `End-Row302` (098's End-Row with the unfinished-operations
exit question expected).

### First round (the argument fix; probe with rows MKD-ABS and REN-UP)

Before (02eba55f code, the fix stashed): PASS 2, FAIL 2 (both ROWs); after: PASS 4, FAIL 0. The
final numbers of all four rows are in *Review* below; the row details:

- `MKD-ABS` ROW FAIL: F7 `/MKD-ABS/other/new` from the panel at `/MKD-ABS/src` made the folder;
  upload 2 of the local folder `new` into `/MKD-ABS/other` sent `CWD /MKD-ABS/other / MKD new`
  (550) and stopped at "Error Creating Target Directory"; `f.txt` not uploaded.
- `REN-UP` ROW FAIL - **data loss**: Quick Rename `a.txt` -> `b.txt` done; upload 2 of the local
  `b.txt` sent `STOR b.txt` without any question; the server's `b.txt` (the renamed file, `SRV-A`)
  now holds `LOCAL-B`. The panel's own listing of the folder reached the server only after the
  STOR (`... STOR b.txt / NOOP / CWD /REN-UP / PWD / ... / LIST`), so the refresh did not mask it.
  Reproduced in all three runs on the old code. The item's severity 5 assumed no effect; its
  *Notes* asked to raise it to the data-loss band if this happened.
- END rows PASS (exit 0, no reports).

After the argument fix:

- `MKD-ABS` ROW PASS: upload 2 sent `CWD /MKD-ABS/other/new / PWD / TYPE A / PORT / STOR f.txt` -
  no `MKD`, joined the existing folder (default), `f.txt` = `F`.
- `REN-UP` ROW PASS: upload 2 sent `CWD /REN-UP / PORT / TYPE A / LIST` (the invalidated listing
  is fetched again) and no `STOR b.txt`; the operation's "Target File Already Exists" question for
  `b.txt` is open; the server's `b.txt` keeps `SRV-A`.
- END rows PASS; registry restored + identical (SHA-256 34FA77DB...).

### Regression

- `specs/288-ftp-per-server-encoding/probe/ftp288_probe.ps1` on the fixed build:
  `probe/regress_288.txt` PASS 20, FAIL 0 (as recorded by 288).

## Checks

- Build: `.\build.cmd` -> `BUILD SUCCEEDED` (`ftp.spl` rebuilt; `ctrlcon5.cpp` recompiled).
- Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- saltests: not run - nothing in the core or `src/common/` changed (the FTP plug-in is not linked
  into saltests; no pure decision to extract - four call sites' argument order).
- Line ends: Git Bash `sed -i` turned `ctrlcon5.cpp`'s CRLF into LF in the working copy; restored
  with a Python rewrite (the diff is the 4 lines).

## Analyze

- Round 1: no CRITICAL / HIGH. F1 (MEDIUM, SC-003 named 224 / 277 / 288, tasks ran 288 only) fixed
  in spec.md. C1 (MEDIUM): the "result unknown" calls (connection closed during MKD / RNTO) are
  not driven by the probe - accepted: the same argument-order change as the driven calls, checked
  by reading (the cache then invalidates instead of updating). A1 (LOW) no change.
- Round 2: no findings above LOW.

## Review

### Review 1 (refute-first, independent agent) - MUST 1, SHOULD 1, NOTEs 6

- **MUST 1** - the argument fix let Create Directory's report reach the cache, which records the
  new folder as an empty, ready listing (`AddEmptyListing(..., ulsReady)`); `ReportRename`
  invalidated only the panel folder's listing, so after a Quick Rename into that folder
  (`x.txt` -> `new/x.txt`) or giving another folder its name (`new` -> `new_old`, `full` -> `new`)
  the cache still said "empty" and the next upload sent `STOR` without a `LIST` and without the
  overwrite question - the server's file replaced. Measured by the reviewer (rows MKD-REN,
  REN-PATH). **Fixed**: `CUploadListingsOnServer::ReportRename` invalidates every listing of the
  server (`InvalidateAllListings()`, new; from the end - `InvalidateListing` deletes a ready
  listing). The same for `ReportUnknownChange` (Send FTP Command: a typed command may change any
  folder, also one F7 cached as empty) - by reading, not driven (the plug-in menu command is not
  reachable by the probe's command ids); recorded as owed to a person. Spec Clarification /
  FR-004 / edge cases / SC-004 updated. Rows MKD-REN and REN-PATH added to the probe (from the
  reviewer's `extra_rows.ps1`; PASS also requires the open overwrite question).
- **SHOULD 1** - the backlog item still says severity 5 and "masked". The item is removed at the
  closing (`BL remove`); the data loss is stated in the closing report, FEATURE-HISTORY and the
  CHANGELOG entry instead.
- NOTEs: the measurement reproduces (reviewer: fixed 4 / 0 on the first two rows; reverted
  `MKD new`, `SRV-A` -> `LOCAL-B`); the 4 swapped calls were the only ones (15 files checked);
  standing rules untouched; "result unknown" branches by reading; on the hidden desktop the
  panel's refresh after F7 is deferred (an explicit refresh, cmd 725, in the review rows) - the
  verdicts do not depend on it; 288 not re-run by the reviewer (re-run here).

### Final probe runs (`ftp302_probe.ps1`, four rows + END rows)

| Code | File | MKD-ABS | REN-UP | MKD-REN | REN-PATH | Rows |
|---|---|---|---|---|---|---|
| `main` (02eba55f) | `result_before.txt` | FAIL (`MKD new`) | FAIL (`b.txt` replaced) | PASS | PASS | 6 / 2 |
| argument fix only (review 1 state) | `result_review1_control.txt` | PASS | PASS | FAIL (`f.txt` replaced) | FAIL (`x.txt` replaced) | 6 / 2 |
| full fix | `result_after.txt` | PASS | PASS | PASS | PASS | 8 / 0 |

Every row fails on exactly one of the earlier versions - each is a negative control. END rows
PASS in all runs (exit 0, no reports; the expected exit question about the unfinished operations
the probe leaves). Registry restored + identical in every run. On `main`, MKD-REN / REN-PATH pass
because F7's report never reached the cache (no empty listing of `new`; the upload lists it).

Traps of this round: `Select-Object -First 5` on the output of `build.cmd` stops the pipeline and
killed the build before it compiled - the first "after" run tested the review-1 state (kept as
`result_review1_control.txt`, confirming the MUST); `git stash` of the source files left the
already committed `ctrlcon5.cpp` fixed - the `main` run took it from `main`
(`git checkout main -- ...`, restored with `git checkout HEAD -- ...`).

Checks after review 1: `.\build.cmd` -> `BUILD SUCCEEDED` (`ftp.spl` 08:37); encoding guard
`TOTAL: 0 finding(s)`; `ftp288_probe.ps1` -> `regress_288.txt` PASS 20, FAIL 0.
