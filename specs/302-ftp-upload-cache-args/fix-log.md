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

### Before (02eba55f code; final probe, run with the fix stashed) - `result_before.txt`: PASS 2, FAIL 2

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

### After (fix) - `result_after.txt`: PASS 4, FAIL 0

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
