# Closing report - 277-ftp-pwd-path-cut
Backlog item: ftp-pwd-and-created-path-cut - FTP: a PWD reply or a created folder path that does not fit is cut and used
Outcome: closed

## What changed

- `src/common/salftppwd.h` (new, header-only, pure): `SalFtpPathFromPwdReply` reads the path of a
  "257" reply (RFC 959, VxWorks, German AIX forms; `""` escapes) only within the reply's size and
  refuses a path that does not fit the buffer or holds a NUL - never cuts; a path that fills the
  buffer exactly (300 bytes) is accepted.
- `src/plugins/ftp/ftputils.cpp`: `FTPGetDirectoryFromReply` on the header;
  `FTPDecodeServerReplyPathInPlace` fails when the UTF-8 form does not fit or the conversion could
  not be made; `FTPCompleteAbsolutePath` fails instead of cutting; `FTPAS400CutFileNamePart` takes a
  buffer size and fails instead of cutting (`ftputils.h`).
- `src/plugins/ftp/operats9.cpp`: `ReportCreateDirs` walks a long name whole in heap buffers and
  only invalidates; `CFTPOpenedFile::IsSameFile` compares names by `SalNameOrderEqualCI`.
- `src/plugins/ftp/fs4.cpp`, `operats6.cpp`: AS/400 member names whole (`3 * MAX_PATH`), a refusal
  instead of a cut. `src/plugins/ftp/fs5.cpp`: no link size from a cut source path.
- `src/saltests/saltests.cpp`: `TestFtpPwdReply277`.
- `specs/215-ftp-long-name-command/probe/ftpmini.py`: PWDMAP option (backward compatible);
  `specs/277-ftp-pwd-path-cut/probe/ftp277_probe.ps1`.
- No UI strings, resources or plug-in interface changed.

## Measurements (before / after, commands)

Probe (hidden desktop): `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\277-ftp-pwd-path-cut\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\277-ftp-pwd-path-cut\probe\ftp277_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`

| Row | Before (65c337dc / old plug-in code) | After |
|---|---|---|
| AIX (AIX form, 305 bytes) | local lnk\x.txt = **"ANCESTOR"** (after the reconnect `CWD <300 bytes>`) | refused, "Error Getting Working Path On Server" |
| CP (cp1250, 305 UTF-8 bytes) | cut on conversion, `CWD` to the cut path | refused |
| R301 (RFC, 305 bytes) | refused | refused |
| R300 (RFC, exactly 300) | refused | "DEEP300" |
| CTL (AIX, short) | "DEEP" | "DEEP" |

Totals: old code 7 / 3 (`probe/result_control_old_code.txt`; `result_before.txt` is the first
run in `before` mode), after 10 / 0 (`probe/result_after.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `build.cmd`: `BUILD SUCCEEDED` (Debug x64).
- `saltests.exe`: `saltests: 24929 checks, 0 failed` (negative control: the header with the old
  AIX cut and the old one-byte-early refusal - 7 failed).
- Probes: 277 10 / 0; regressions 215 12 / 0, 224 16 / 0 (as recorded), 233 DLT / DLC / UPT FAIL
  as recorded in 233 (its known probe defect). Registry restored and identical in every run.

## Reviews (findings and what was done)

One independent refute-first review: no MUST, no SHOULD; its own negative control (the old cuts
restored) failed saltests 3 and the probe 2 rows. NOTEs: a NUL inside the path of a raw reply
(fixed, saltests), the raw bytes of a failed conversion taken as UTF-8 (fixed), the unreachable
AS/400 refusal reported as low memory (accepted), folder comparison by the code-page fold (Inbox),
low-memory invalidation of one listing only (accepted), closing documents (done). Details in
`fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- `ftp-277-real-server-checks` - optional checks on real AIX / AS/400 / Windows (IIS) / OS/2 / VMS
  FTP servers (long PWD path through a link, AS/400 member names, the lock on case twins, an
  absolute Create Directory).

## New Inbox items (slug - title)

- `ftp-server-path-compare-code-page-fold` - FTP: server folder names compared by the code-page case rule on UTF-8 bytes
- `ftp-277-real-server-checks` - FTP 277 on real servers: long PWD paths, AS/400 member names, case-insensitive lock (person step)
