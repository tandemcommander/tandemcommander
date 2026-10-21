# Fix log - 277-ftp-pwd-path-cut

Backlog item `ftp-pwd-and-created-path-cut`. Run at `main` = 65c337dc (autonomous run).

## Measured before (65c337dc, build up to date: `build.cmd` 4 s, nothing rebuilt)

Probe `probe/ftp277_probe.ps1` (hidden desktop), server = 215's `ftpmini.py` extended with a
PWDMAP option (feature 277: a folder "reached through a link" - its PWD / MKD reply names another
path, a client path starting with that path means the folder again; a one-shot session drop after
the folder's listing). Each row: F5 of the server's `<row>/lnk` (x.txt "DEEP") to the local
panel. `A` = a 300-byte path the server names `<row>/anc` by (x.txt "ANCESTOR").

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\277-ftp-pwd-path-cut\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\277-ftp-pwd-path-cut\probe\ftp277_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Expect before"
```

(run from the session scratchpad with `-Lib` / `-Server` before the branch existed; the files are
the same.)

| Row | PWD reply in lnk | Before |
|---|---|---|
| AIX | AIX form, `A/deep` 305 bytes | **local lnk\x.txt = "ANCESTOR"**: after the reconnect `CWD <300 bytes>` (= anc), `RETR x.txt` |
| CP | cp1250 RFC form, `A/deep` (157 cp1250 bytes, 305 UTF-8) | cut on conversion; after the reconnect `CWD` to the cut path (sent as UTF-8 here - 550 "Error Changing Working Path") |
| R301 | RFC form 305 bytes | refused: "Error Getting Working Path On Server" (control) |
| R300 | RFC form exactly 300 bytes | **refused** (should be accepted) |
| CTL | AIX form, short path | "DEEP", after the reconnect `CWD /CTL/elsewhere` (control: the map and the form work) |

First attempts of the probe (recorded): the map used lower-case folders while the rows are upper
case (no remap - all rows downloaded); then without the drop the worker never sent `CWD` again
(its working path was already the cut one) and the right file came - the cut is visible only once
the worker goes back by the path, hence the drop.

By reading at 65c337dc:
- `ftputils.cpp` `FTPGetDirectoryFromReply`: AIX branch `if (len >= dirBufSize) len = dirBufSize - 1;` + `return TRUE`; quoted loop `while (++s < end && d < endDir)` stops at 300 bytes before seeing the closing quote (refuses exactly-300); `FTPDecodeServerReplyPathInPlace` `lstrcpyn(dirBuf, u8, dirBufSize)`; the AIX branch's `strrchr` / `strchr` ignore `replySize`.
- Callers: `ctrlcon3.cpp` `GetCurrentWorkingPath` (FALSE -> connection closed, "cannot get the working directory"), `ctrlcon5.cpp` `CreateDir` (FALSE -> no focus name, refresh), `operats7.cpp` explore (FALSE -> item fails ITEMPR_UNABLETOPWD-like), `operatsa.cpp` upload target (FALSE -> ITEMPR_UNABLETOPWD).
- `operats9.cpp` `CUploadListingsOnServer::ReportCreateDirs`: `lstrcpyn(relPath, newDirs, FTP_MAX_PATH)` and `lstrcpyn(path, newDirs, FTP_MAX_PATH)`; callers ctrlcon5.cpp (Create Directory, x2), operats3.cpp (x2), operatsa.cpp (x4).
- `FTPCompleteAbsolutePath`: one caller (`ReportCreateDirs`); shortens `l` for OS/2 and VMS.
- `FTPAS400CutFileNamePart`: `lstrcpyn(..., MAX_PATH)`; callers `fs4.cpp` (panel download, target name) and `operats6.cpp` (explore of a folder for copy / move - a download, not the upload as the item says).
- `CFTPOpenedFile::IsSameFile`: `SalamanderGeneral->StrICmp(Name, name)` on case-insensitive servers.
- `fs5.cpp` upload: `lstrcpyn(linkName, sourcePath, MAX_PATH)` then the size of `linkName + name`.
- The item's note "fs4.cpp download target name cut at a byte": the target name is `targetName[3 * MAX_PATH]` with a "filled to its last byte" refusal (215) - not cut; dropped (the AS/400 branch above is the one cut left there).

## Decisions

See spec *Clarifications* / *Assumptions*. In code:
- `src/common/salftppwd.h` `SalFtpPathFromPwdReply` (pure, saltests): the three forms as before,
  read only within `replySize`; a path of `dirBufSize - 1` bytes fits, one more is `TOOLONG`.
- `FTPGetDirectoryFromReply` uses it; `FTPDecodeServerReplyPathInPlace` returns FALSE when the
  UTF-8 form does not fit or on low memory (it kept the code-page bytes before - conservative).
- T005 callers, by reading - unchanged, all treat FALSE as before: `ctrlcon3.cpp`
  `GetCurrentWorkingPath` (closes the connection, "cannot get the working directory");
  `ctrlcon5.cpp` `CreateDir` (no focus name, refresh of the working path); `operats7.cpp`
  explore (item fails: "Error Getting Working Path On Server" - seen in the probe);
  `operatsa.cpp` upload target (ITEMPR_UNABLETOPWD).
- `ReportCreateDirs`: heap buffers of `max(FTP_MAX_PATH, strlen(newDirs) + strlen(workPath) + 3)`,
  a name of FTP_MAX_PATH bytes or more -> `unknownResult` (invalidate only); low memory ->
  invalidate the workPath listing. The absolute branch looks up only paths < FTP_MAX_PATH.
- `FTPCompleteAbsolutePath`: FALSE + path unchanged when it does not fit (one caller, whose heap
  buffer always fits; its existing handling of FALSE for a relative workPath kept).
- `FTPAS400CutFileNamePart(mbrName, mbrNameSize, name)` -> BOOL; callers pass `3 * MAX_PATH`
  (> FTP_MAX_NAME_U8); fs4 FALSE -> IDS_TOOLONGPATH, operats6 FALSE -> no item (explore error).
- `CFTPOpenedFile::IsSameFile`: `SalNameOrderEqualCI` (salnameorder.h) for case-insensitive
  servers; the host compare unchanged.
- fs5 upload: the link size only when `strlen(sourcePath) + 1 < MAX_PATH`.

## Implementation attempts

1. saltests did not compile: a test buffer named `small` (a macro of rpcndr.h) - renamed.
   Restoring a comment with PowerShell 7 `Set-Content -Encoding utf8` dropped saltests.cpp's BOM -
   restored with the shell.
2. The probe's `-Lib` / `-Server` defaults used `$PSScriptRoot` in the param block - empty in
   PowerShell 5.1 under the hidden-desktop runner; resolved in the body.
3. The probe's "refused" judge accepted the CP row of the old code (missing file + any dialog,
   while the old code had sent `CWD` to the cut path): tightened to "Error Getting Working Path"
   and no `CWD <long>` - then the control below.

## Measured after

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| build | `build.cmd` | `BUILD SUCCEEDED` |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 24926 checks, 0 failed` |
| saltests negative control | header with the old cut (AIX) + the old one-byte-early refusal | `7 failed` - restored |
| probe after | `ftp277_probe.ps1` (`probe/result_after.txt`) | **PASS 10, FAIL 0**: AIX / CP / R301 refused at the PWD ("Error Getting Working Path On Server", no `CWD` to a cut path), R300 "DEEP300" (after the reconnect `CWD <300 bytes>`), CTL "DEEP"; registry identical |
| probe control, old code | `git checkout main -- src/plugins/ftp`, build, the same probe (`probe/result_control_old_code.txt`), sources restored, rebuilt | **PASS 7, FAIL 3**: AIX "ANCESTOR", CP (cut CWD), R300 refused |
| regression 215 | `ftp215_probe.ps1` (`probe/regress_215.txt`) | PASS 12 / FAIL 0 (as recorded) |
| regression 224 | `ftp224_probe.ps1` (`probe/regress_224.txt`) | PASS 16 / FAIL 0 (as recorded) |
| regression 233 | `ftp233_probe.ps1` (`probe/regress_233.txt`) | DLT / DLC / UPT FAIL - as recorded in 233 (its probe defect, `result.txt` + `result_dlc_control.txt`) |

Not driven (no AS/400, OS/2, VMS server; the lock and the link size need two concurrent
operations / a local path of 260+ bytes with a file link): the AS/400 member name, the
created-folder report, the lock, the link size - by reading; the reply rule by saltests.

## Analyze

Round 1: 0 CRITICAL, 0 HIGH; MEDIUM C1 (FR-010 had no check - added to T014), MEDIUM I1 (US3
scenario 3 vs clarification Q3 - aligned); LOW U1 (the item asked for a long *home* folder option,
the probe drives a linked folder - the home / panel route is masked by the core's ~260-byte limit,
research R1) accepted. Round 2: nothing left above LOW.
