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

## Analyze

Run 1: CRITICAL D1 (no CHANGELOG task - constitution *Release Documentation*), CRITICAL D2 (no
clang-format check - *Development Workflow*), MEDIUM E1 (FR-006 not verified), LOW U1 (the
1,000-server bound only in the plan). Fixed: T022, T016, T021, spec Edge Cases. Run 2: no
findings.

## Work

- `src/common/salftpsrvenc.h` (new, header-only): `SalFtpServerEncState` (unknown / UTF-8 /
  legacy / mixed), `SalFtpNameGoesInCodePage` (a server's own code-page name, or any name to a
  legacy server), `SalFtpSameServer*` (host without ASCII case, port, user with NULL / "" /
  "anonymous" one user - the upload listing cache's identity). saltests `TestFtpServerEncoding288`.
- `ftputils.cpp`: 224's process-wide set replaced by `CFTPServerEnc` (a list of servers, at most
  1,000, each with `SawUtf8` / `SawCodePage`) and one hash table of code-page names tagged with
  their server (bound 200,000 kept); one SRW lock `FTPServerEncLock` (a primitive lock - added to
  `servers/critsect.txt`); freed at release (`FTPFreeServerEncodings`, ftp.cpp).
  `FTPListingFieldToU8` records evidence for the server of `CFTPListingServerScope` (thread-local,
  nests): a valid non-ASCII field = UTF-8 evidence, a field read in the code page = code-page
  evidence + its name. `FTPGetDirectoryFromReply(.., srv)`: a 257 path read in the code page =
  code-page evidence + name; a UTF-8 one nothing (it may echo the client's bytes).
  `FTPU8NameToServer(.., srv)`: `SalFtpNameGoesInCodePage(state, the name / a component / a
  leading part is srv's)`, then the code page only if it holds the name (as 224); NULL srv = UTF-8.
- `PrepareFTPCommand(srv, ...)` (ctrlcon.h / ctrlcon2.cpp): all 55 call sites updated (a script;
  the compiler checks each - a `char*` does not convert to `CFTPServerEnc*`): the 12 name commands
  get `GetServerEnc()` (panel connection, ctrlcon3/4/5) or `Oper->GetServerEnc()` (workers,
  operats4/7/8/a/b), the others NULL. New `CControlConnectionSocket::GetServerEnc()` (under
  SocketCritSect) and `CFTPOperation::GetServerEnc()` (under OperCritSect).
- Listing scopes: fs2.cpp (the panel's parse, before `LockServerTypeList` - first placed inside
  `ParseListing`, which runs with ServerTypeListCS held; critsect.txt forbids SocketCritSect
  there: moved), fs5.cpp (Quick Rename's target check, likewise), operats6.cpp
  (`ParseListingToFTPQueue`, `Oper->GetServerEnc()` - OperCritSect is allowed inside
  ServerTypeListCS and WorkerCritSect), operats9.cpp (`CUploadListingsOnServer::AddOrUpdateListing`
  / `ListingFinished`, the entry's own Host / Port / User - only the SRW lock inside
  UploadLstCacheCritSect). dialogs4.cpp (server-type test dialog): no scope, no evidence.
- T014 (reading): every lookup (`FTPIsCodePageNameN`, `FTPHasCodePageName`, `FTPAddCodePageName`)
  takes the server and compares it; no server-less path is left. T015: the test dialog parses
  with the thread-local NULL; comments of 224 / 269 / 277 sites still true; the protocol-boundary
  comment of ftputils.h updated.
- clang-format (VS 2022 LLVM, `--style=file`, only the changed lines): only the test's lambda
  rewrapped. Line endings kept CRLF.

## Measured (after)

- `build.cmd` (Debug x64): BUILD SUCCEEDED (warnings C4267 at fs2.cpp 815 / 1325 / 1369 and
  parser2.cpp 369 are untouched upstream lines, shown because the whole plug-in recompiled).
- saltests: `saltests: 25200 checks, 0 failed`.
- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- Probe `probe/result_after.txt`: **PASS 12, FAIL 0** (before 8 / 4): LEG-MKD `MKD nový` in cp1250
  -> `nový` on the server; LEG-REN `RNTO čaj.txt`; LEG-UP `STOR čaj.txt` (worker), content kept;
  CROSS-DEL the UTF-8 server got `DELE café.txt` in UTF-8 and deleted it, the legacy server's file
  untouched; UTF-MKD UTF-8; UNK-MKD still UTF-8 (the limit). Registry restored, identical.
- Regressions: `probe/regress_224.txt` 16 / 0, `regress_269.txt` 14 / 0, `regress_277.txt`
  10 / 0 (as recorded by those features); registry identical each time.
- Negative control (T020): `SalFtpNameGoesInCodePage` set back to 224's rule (only remembered
  names) -> saltests `25200 checks, 2 failed` (the two lines of the decision table); the probe on
  that build `probe/result_control_rule224.txt` 9 / 3: LEG-MKD, LEG-REN, LEG-UP FAIL, CROSS-DEL
  PASS (the per-server set alone fixes it) - each half of the fix is measured by its own rows.
  Restored; rebuilt; saltests 25200 / 0.
- FR-006: the servers' logs show the same command kinds as before (USER, PASS, SYST, PWD, CWD,
  PORT, TYPE, LIST, MKD / RNFR / RNTO / STOR / DELE, NOOP, QUIT) - no FEAT / OPTS; the diff adds no
  registry or file write (in-memory state only).

## Review

### Review 1 (refute-first, independent agent) - rejected: 1 MUST, 1 SHOULD, 5 NOTE

Confirmed by the review: build, saltests 25200 / 0, the before / after / control results, all 57
`PrepareFTPCommand` sites (every name command gets its server), the same server key at every
listing parse and 257 reply, the lock order against critsect.txt, the scope's nesting, NULL and
memory bounds.

- **MUST 1 (data loss, taken)**: `WideCharToMultiByte(CP_ACP, 0, ..)` best-fits without setting
  the default-character flag - `señor.txt` -> `senor.txt`, `øre` -> `ore`, `naïve` -> `naive` in
  cp1250. Under 224 only listed code-page texts took that path (they round-trip); 288 sends every
  new name to a legacy server through it. Reproduced (`probe/review_bestfit_result.txt`): BF-UP -
  the legacy server's `senor.txt` = OLD, F5 of the local `señor.txt` = NEW sent `STOR senor.txt`
  and replaced it without the overwrite question (the upload's "exists?" check compares UTF-8
  names); BF-MKD `MKD senor`. **Fix**: `SalFtpWToCodePageExact` (salftpsrvenc.h):
  `WC_NO_BEST_FIT_CHARS` + the default-character flag + a round trip (the bytes read back are the
  name); otherwise UTF-8. saltests: cp1250 café / nový / č / ASCII exact; señor, øre, naïve, CJK,
  ř in cp1252 refused (buf = ""); a buffer one byte short refused, never cut; negative control:
  the old call yields `senor.txt` with no default flag (documents the trap).
- **SHOULD 1 (taken, inside the item)**: a listing echoes the UTF-8 bytes of a name the client
  sent while the legacy server was unknown -> `SawUtf8` -> mixed -> new names in UTF-8 again.
  Reproduced (`probe/review_echo_result.txt`, ECHO). **Fix**: every non-ASCII component the client
  sends a server in UTF-8 is remembered for that server (`FTPNAME_SENTUTF8`, the same bounded
  table); a listed name equal to one gives no UTF-8 evidence.
- NOTE 1 (taken in part): evidence came from every string column (owner, group, ...) - now only
  the name column changes a server's state (`FTPListingFieldToU8(.., nameField)`, parser2.cpp);
  every field's code-page text is still remembered (224's link targets etc.). Fields of a parser
  that autodetection tries and then rejects still count (recorded as a limit).
- NOTE 2 (limit, recorded by 269): a cp1250 name whose bytes are valid UTF-8 reads as UTF-8 and
  now also counts as UTF-8 evidence.
- NOTE 3 (taken): integration covered by the probe rows BF-UP, BF-MKD, ECHO (added to
  `ftp288_probe.ps1`) and the exact-conversion checks in saltests.
- NOTE 4: the Inbox items (the ctrlcon5 host / user swap, the FEAT decision) are written at closing.
- NOTE 5 (accepted): past 1,000 servers a legacy server's listed names go in UTF-8.

After the fixes: `build.cmd` BUILD SUCCEEDED; saltests `25213 checks, 0 failed`; encoding guard
TOTAL 0; probe `probe/result_after_review1.txt` **PASS 18, FAIL 0** (BF-UP: `STOR seĂ±or.txt` -
the UTF-8 name, garbled on the legacy server, `senor.txt` still OLD; BF-MKD likewise; ECHO: `MKD
čaj` in cp1250 after the echo); regressions 224 16 / 0, 269 14 / 0, 277 10 / 0. The rows BF-UP,
BF-MKD, ECHO failed on the first version (the reviewer's runs) - their negative control.

## Limits

- An unknown server (no non-ASCII listing field yet) gets UTF-8 for new names and typed paths
  (UNK-MKD); a mixed server too (224's policy).
- No FEAT: a decision item for the maintainer.
- The state lasts for the plug-in's life (not stored); the code page is the system ANSI one.
- A server listed under one user name and used under another is two servers.

