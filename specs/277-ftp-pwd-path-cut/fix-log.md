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

(see spec *Assumptions*)

## Analyze

Round 1: 0 CRITICAL, 0 HIGH; MEDIUM C1 (FR-010 had no check - added to T014), MEDIUM I1 (US3
scenario 3 vs clarification Q3 - aligned); LOW U1 (the item asked for a long *home* folder option,
the probe drives a linked folder - the home / panel route is masked by the core's ~260-byte limit,
research R1) accepted. Round 2: nothing left above LOW.
