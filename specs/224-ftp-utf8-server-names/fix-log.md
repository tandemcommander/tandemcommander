# Fix log: 224 - FTP sends a name to a server in the encoding the server uses

Backlog (found by 215's audit): `FTPU8NameToServer` (`ftputils.cpp`) sends a name the ANSI code
page can hold in that code page even to a UTF-8 server - another name.

## Measured (before)

Probe `probe/ftp224_probe.ps1` with 215's test server `ftpmini.py` (now with an encoding argument:
`utf-8` - FEAT announces UTF8 - or a legacy `cp1250`; and a start folder), the build at 223
(`probe/result_before.txt`, system code page 1250):
- **DEL-ACC / REN-ACC / DL-ACC on a UTF-8 server: delete, Quick Rename and download of "cafe.txt"
  with an e-acute all failed** - the server got `DELE`, `RNFR`, `RETR caf\xE9.txt` (the cp1250
  byte): "550 No such file". Every name with Czech letters on a UTF-8 server (the usual one today)
  was out of reach;
- DEL-CJK (a name the code page cannot hold - sent in UTF-8 already): as expected.

## Work

`src/plugins/ftp/ftputils.cpp` (+ `ftputils.h`, `ftp.cpp`):
- `FTPListingFieldToU8` remembers every text it read through the code page (its bytes were not
  UTF-8 - a legacy server; also a PWD path through `FTPDecodeServerReplyPathInPlace`) in a
  process-wide set (an SRW lock; at most 200,000; freed at the plug-in's release);
- `FTPU8NameToServer` converts to the code page only a name - or a path with a component or
  (review) a leading part - from that set; anything else goes in UTF-8.

**The decision (a policy change):** a name that did not come from a code-page listing - a new
folder (MKD), Quick Rename's new name (RNTO), an uploaded local name (STOR), a typed path or a
bookmark - now goes in UTF-8 also to a legacy code-page server (before: the code page when it fitted).
UTF-8 servers are the common case (RFC 2640; IIS 7.5+, ProFTPD, FileZilla Server announce it;
vsftpd and Pure-FTPd keep raw bytes, which round-trip UTF-8); old servers that convert through
the ANSI code page (IIS 6, old Serv-U) get such new names garbled. The right model - a per-server
flag (unknown / UTF-8 / legacy, by host, port and user; evidence: FEAT UTF8 or a listing) as WinSCP
and FileZilla do - needs the server's identity at the listing parser and at the 56 callers of
`PrepareFTPCommand`: recorded in `specs/NEXT-WORK.md`.

Build: BUILD SUCCEEDED.

## Measured (after)

`probe/result_after.txt` 16 / 0 (the final build): the UTF-8 server's rows send UTF-8; LEG-DEL /
LEG-REN / LEG-DL (the cp1250 server) send the listed name in cp1250; LEG-HOME (the legacy server's
home folder `/jiri` with Czech letters, known only from PWD; Enter on its subfolder) opens it.
Regression: 215's probe 12 / 0 (`probe/regress_215.txt`).

## Review

Refute-first review: not ready at first - **MUST, taken**: a folder under a non-ASCII path known
only from PWD could not be opened (only whole names and components were looked up, not leading
parts): `CWD /jiri/x` went in UTF-8 - reproduced on the first version
(`probe/result_review_m1_control.txt`) and fixed. SHOULD recorded: the set is shared by all servers
(a name seen in the code page on one server goes in the code page to another - a migration from a
legacy server to a new one uploads such names wrongly); the policy above. NITs taken: the length
kept in the node, a trace at the bound. Kept: a rare double entry (two threads), VMS / MVS paths
not split, owner / group / month texts in the set (harmless).
