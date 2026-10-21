# Fix log: 288 - FTP names go to each server in that server's own encoding

Backlog item `ftp-per-server-encoding-flag` (leftover of 224): one process-wide set of code-page
names; new names went in UTF-8 to legacy servers, a name seen in the code page on one server went
in the code page to another.

## Measured (before) - f9da572f, on main

Build: `build.cmd` (Debug x64) BUILD SUCCEEDED (the tree at HEAD).
Probe `probe/ftp288_probe.ps1` (new; 224's driver, two of 215's `ftpmini.py` at once: cp1250 on
127.0.0.1:2121, UTF-8 on :2122; ACP 1250), run on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\288-ftp-per-server-encoding\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\288-ftp-per-server-encoding\probe\ftp288_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

`probe/result_before.txt`: PASS 8, FAIL 4; registry restored, identical.
- LEG-MKD FAIL: `MKD novĂ˝` (UTF-8 bytes read as cp1250) - the server created `novĂ˝`;
- LEG-REN FAIL: `RNTO ÄŤaj.txt`;
- LEG-UP FAIL: `STOR ÄŤaj.txt` (worker);
- CROSS-DEL FAIL: the UTF-8 server got `DELE caf�.txt` (cp1250 byte) - "550 No such file";
- UTF-MKD PASS (`MKD nový` in UTF-8), UNK-MKD PASS (no evidence: UTF-8, the limit).

Reading: the plug-in sends no FEAT / OPTS UTF8 (grep). Consumers enumerated: `PrepareFTPCommand`
57 call sites (ctrlcon1/2/3/4/5, operats4/6/7/8/a/b), name-carrying commands CWD, DELE, RMD,
SITE CHMOD (2 forms), RETR, STOR, APPE, MKD, RNFR, RNTO, SIZE; `FTPListingFieldToU8` from
`AssignStringToColumn` (parser2.cpp; `GetNextItemFromListing` loops in fs2.cpp, operats6.cpp,
operats9.cpp, dialogs4.cpp) and `FTPDecodeServerReplyPathInPlace`; `FTPGetDirectoryFromReply`
callers ctrlcon3.cpp (PWD), ctrlcon5.cpp (MKD), operats7.cpp, operatsa.cpp.

## Decisions

- Evidence from listings and 257 replies only - FEAT would be new network traffic
  (maintainer-owned): a decision item at closing.
- A 257 path never gives UTF-8 evidence (it can echo the client's bytes).
- Unknown and mixed servers: UTF-8 for new names (224's policy).
- Found on the way (outside the scope): `ctrlcon5.cpp` passes `(hostBuf, userBuffer, ...)` to
  `UploadListingCache.ReportCreateDirs` / `ReportRename`, which take `(user, host, ...)` -> Inbox.

## Work
