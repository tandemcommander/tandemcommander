# Fix log - 341-ftp-upload-cache-alias

Backlog item `ftp-an-upload-to-a-server-named-another-way-localhost-vs-127` (source review:302).

## Measurement at 3034d82f (before any change, `main`)

Build: `.\build.cmd` (Debug x64, incremental) -> BUILD SUCCEEDED.

Probe `probe/ftp341_probe.ps1` (new; built from 323's `ftp302_probe.ps1`, `ftpmini_hide.py` on
127.0.0.1:2141, user `u`, panel connected as `ftp://u@127.0.0.1:2141`), run on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_main.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\ftp341_probe.ps1 -Repo E:\Projects\tandemcommander -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe"
```

Result `probe/result_main.txt`: PASS 4, FAIL 2.

- ALIAS-REN ROW **FAIL**: upload 1 of `o1.txt` typed to `ftp://u:p@localhost:2141/ALIAS-REN` held
  at its overwrite question; Quick Rename `a.txt` -> `b.txt` in the panel (127.0.0.1); upload 2 of
  the local `b.txt` to localhost: `... CWD /ALIAS-REN / TYPE A / PORT ... / STOR b.txt / QUIT`, no
  question, the server's `b.txt` = `LOCAL-B` (was `SRV-A`, the renamed file). Data loss.
- ALIAS-UP ROW **FAIL**: upload 1 held at localhost; upload 2 stored a new `n.txt` (UP2) through
  127.0.0.1; local `n.txt` changed to UP3; upload 3 to localhost: `STOR n.txt` without the
  question, server `n.txt` = UP3. Data loss through an operation's own report, not the panel's.
- SAME-REN ROW PASS (one name everywhere - feature 323's REN-UP).
- All END rows PASS; registry restored, identical hash.

## Reading: the sites and the callers

`CUploadListingCache::FindServer` (`src/plugins/ftp/operats9.cpp`): `StrICmp(server->Host, host)`,
user exact (anonymous = NULL), port equal. Every report routes through it.

Callers (Grep `UploadListingCache\.` outside operats9.cpp), all via the cache's methods:

| Method | Callers |
|---|---|
| ReportCreateDirs | ctrlcon5.cpp x2 (panel F7), operats3.cpp x2, operatsa.cpp x4 (upload MKD) |
| ReportRename | ctrlcon5.cpp x2 (panel Quick Rename) |
| ReportDelete | operats3.cpp x2, operats4.cpp x4, operats8.cpp x2, operatsb.cpp x4 |
| ReportStoreFile | operatsb.cpp x1 |
| ReportFileUploaded | operats3.cpp x1, operatsb.cpp x2 |
| ReportUnknownChange | fs3.cpp x2 (Send FTP Command) |
| bookkeeping (not fanned out) | AddOrUpdateListing fs2/fs5, RemoveServer operats1, RemoveNotAccessibleListings operats1 x2, InvalidatePathListing operats1 x2 / operatsa x2 / operatsb x2, IsListingFromPanel operatsa x2, GetListing operatsa x2 / operatsb x3, ListingFailed operats3 / operats4 x2, ListingFinished operats7 |

Name lookups of the plug-in: `CSocket::GetHostByAddress` (`sockets.cpp`) - `inet_addr` for a typed
IPv4 (no lookup), else `CGetHostByNameThread` (`gethostbyname`). Callers: panel connect
(`ctrlcon1.cpp` `sccsGetIP`), operation workers (`operats6.cpp`), proxied data connections
(`sockets.cpp`). With a proxy the name looked up is the proxy's.

## Decisions

See spec *Clarifications* and research.md R1-R7: addresses remembered from existing lookups (no
new network traffic); maybe-same entries are invalidated, never given the precise report;
unknown address = maybe the same; user and port still identify the server.

Analyze (2 passes): no CRITICAL / HIGH. E1 (MEDIUM, SC-004 had no verification task) -> added to
T015. C1 (LOW): short IPv4 forms (`127.1`) are `inet_addr`'s in the plug-in - the pure rule gets
address lists; covered by reading.

## Implementation

- `src/common/salftpserverident.h` (new, header-only, pure): `SalFtpHostNameEqualAsciiCI`,
  `SalFtpCompareServerNames` (same host text -> same; an address list empty -> maybe the same;
  an address in common -> maybe the same; else different), `CSalFtpHostAddrTable` (64 slots x 8
  IPv4 addresses, host up to 255 bytes - a longer one is refused, never cut; latest lookup wins;
  full table: round robin).
- `src/plugins/ftp/ftputils.cpp/.h`: `FTPRecordHostAddrs` / `FTPGetHostAddrs` - the table behind
  an SRW lock (leaf); a typed IPv4 host is read with `inet_addr` (as `CSocket::GetHostByAddress`
  connects), else the table.
- `src/plugins/ftp/sockets.cpp` `CGetHostByNameThread::Body`: after a successful `gethostbyname`
  the name and up to 8 entries of `h_addr_list` (AF_INET, 4-byte addresses) are recorded, before
  the result is posted. No new lookup.
- `src/plugins/ftp/operats.h/operats9.cpp`: `CUploadListingCache::InvalidateOtherNamesOfServer`
  (inside `UploadLstCacheCritSect`): for every entry other than the exact one with the same user
  (anonymous normalised) and port, `sfsnMaybeSame` -> `InvalidateAllListings()`. Called by the
  six change reports (`ReportCreateDirs`, `ReportRename`, `ReportDelete`, `ReportStoreFile`,
  `ReportFileUploaded`, `ReportUnknownChange`), also when there is no exact entry.
- Lock order: `UploadLstCacheCritSect` -> `FTPHostAddrsLock` (leaf); the lookup thread takes only
  the leaf. `InvalidateAllListings` of another entry is what feature 302/323 already do inside
  the same section.

## Probe extended (US3)

"Unknown address = maybe the same" means ALIAS-REN / ALIAS-UP pass even when no lookup is ever
recorded - the probe rows of the item do not prove the recording. Row DIFF-KEEP added: a second
`ftpmini_hide.py` on 127.0.0.2 (same port) through `probe/ftpmini_at.py` (binds the given loopback
address, accepts a `PORT` of any 127.x address); upload 1 to `localhost` (server 1) held; Quick
Rename on server 2 (panel at 127.0.0.2); upload 2 of a new file to `localhost`: PASS = stored
without listing again (the localhost cache kept: {127.0.0.1} vs {127.0.0.2} = different). On
`main` this row passes trivially (nothing fans out) - it is a control against over-invalidation.
`result_main.txt` was made by the probe before this row and the `-Repo` default fix (the first
`-Repo` default used `$PSScriptRoot` inside `param()`, empty under Windows PowerShell 5.1 there;
the first run failed binding parameters, nothing touched - no backup file, no fixture).

## Checks (final code)

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| build | `.\build.cmd` | BUILD SUCCEEDED; no warning in the changed files (recompiled after touching them) |
| clang-format | clang-format of VS 2022 on the changed files | no deviation in the new lines (the include block of `ftputils.cpp` realigned as clang-format asks) |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 28926 checks, 0 failed` (`TestFtpServerIdent341`: 122 checks) |
| probe | `ftp341_probe.ps1` -> `probe/result_after.txt` | PASS 8, FAIL 0 (ALIAS-REN, ALIAS-UP, SAME-REN, DIFF-KEEP; registry identical) |
| regression | 323's `ftp302_probe.ps1` -> `probe/regress_302.txt` | PASS 16, FAIL 0 |
| negative control 1 | `InvalidateOtherNamesOfServer` returns at once, rebuilt; `-Only ALIAS-REN` -> `probe/result_negative.txt` | ALIAS-REN FAIL (STOR b.txt, server b.txt LOCAL-B) - restored, rebuilt |
| negative control 2 | `FTPRecordHostAddrs` call removed from the lookup thread, rebuilt; `-Only DIFF-KEEP` -> `probe/result_negative2.txt` | DIFF-KEEP FAIL (upload 2 listed again) - restored, rebuilt, full probe 8/0 |
| SC-004 | `git diff HEAD -- src/plugins/ftp`, added lines with gethostbyname / GetHostByAddress / getaddrinfo | one: a comment; `inet_addr` is a conversion, no lookup |

Before / after, the item's row: ALIAS-REN on `main`: `STOR b.txt`, server `b.txt` = LOCAL-B, no
question -> after: `... CWD /ALIAS-REN / PORT ... / TYPE A / LIST`, the question for `b.txt` open,
server `b.txt` = SRV-A.

## Limits

- Through a proxy the plug-in looks up only the proxy's name: the FTP server's name has no known
  address, so concurrent uploads under two names with the same user and port (even of two
  different servers) make each other list again after every change - slower, never less safe.
- Two uploads under two names of one server at once: each store makes the other list again.
- Two user accounts of one server, or one server on two ports: not recognised (out of scope).
- IPv4 only (the plug-in's connections are IPv4).
