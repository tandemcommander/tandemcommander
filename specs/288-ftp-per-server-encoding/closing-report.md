# Closing report - 288-ftp-per-server-encoding
Backlog item: ftp-per-server-encoding-flag - FTP: one process-wide name encoding instead of a per-server flag
Outcome: closed

## What changed

- Each FTP server (host without ASCII case, port, user; anonymous = none) has its own encoding
  state - unknown / UTF-8 / legacy / mixed - and its own remembered names (`CFTPServerEnc`,
  `src/plugins/ftp/ftputils.cpp`; the pure rule header-only in `src/common/salftpsrvenc.h`).
  Feature 224's one set for the whole program is gone.
- A legacy server (its listings show only code-page names) gets new names - created folders,
  Quick Rename's new name, uploads, typed paths - in the code page; UTF-8, unknown and mixed
  servers get UTF-8; a name a server listed in the code page goes back so (224); what one server
  showed no longer decides another.
- Evidence: listing name fields (a valid UTF-8 name, unless this client sent it in UTF-8 = UTF-8
  evidence; a name read in the code page = legacy evidence) and code-page 257 paths; no FEAT.
- Never a best-fit look-alike: the code-page form is used only when it is exact
  (`SalFtpWToCodePageExact`), else UTF-8 (review 1, data loss found and fixed).
- A name sent to a server in UTF-8 while it was unknown stays UTF-8 later (review 2).
- Plumbing: `PrepareFTPCommand(srv, ...)` at all 55 call sites, `FTPGetDirectoryFromReply(.., srv)`,
  `CFTPListingServerScope` around the panel / worker / upload-cache parses,
  `CControlConnectionSocket::GetServerEnc`, `CFTPOperation::GetServerEnc`; the lock is documented
  in `servers/critsect.txt`.

## Measurements (before / after, commands)

Probe `specs/288-ftp-per-server-encoding/probe/ftp288_probe.ps1` on the hidden desktop
(`tools/run_on_hidden_desktop.ps1`, two of 215's `ftpmini.py`: cp1250 on 127.0.0.1:2121, UTF-8 on
:2122; ACP 1250):
- before (f9da572f): `result_before.txt` PASS 8 / FAIL 4 (LEG-MKD, LEG-REN, LEG-UP, CROSS-DEL);
- first version: `result_after.txt` 12 / 0; review rows on it: BF-UP, BF-MKD, ECHO FAIL
  (`review_bestfit_result.txt`, `review_echo_result.txt`);
- after review 1: `result_after_review1.txt` 18 / 0; ECHO-RMD on it FAIL (`review2_echo_result.txt`);
- final: `result_after_review2.txt` **PASS 20 / FAIL 0** (10 rows), registry restored, identical;
- negative control (224's rule in the header): `result_control_rule224.txt` 9 / 3.
Regressions on the final build: `regress_224.txt` 16 / 0, `regress_269.txt` 14 / 0,
`regress_277.txt` 10 / 0.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `build.cmd` (Debug x64): BUILD SUCCEEDED (C4267 warnings only on untouched upstream lines).
- saltests: `saltests: 25226 checks, 0 failed` (`TestFtpServerEncoding288`: states, the decision
  table with negative controls for the rules of 224 and of review 1, the exact conversion with a
  negative control of the best-fit trap, the server identity).
- clang-format of the changed lines: applied.
- Probes: as above; no NOT DRIVEN row.

## Reviews (findings and what was done)

- Review 1: rejected - MUST 1 best-fit mapping (`señor.txt` sent as `senor.txt`, an upload
  replaced the server's `senor.txt` without the question): fixed; SHOULD 1 the listing echo of a
  name sent in UTF-8 made a legacy server mixed: fixed; NOTE 1 only name columns count: fixed;
  NOTE 2-5 limits / closing tasks.
- Review 2: no MUST; SHOULD 1 (a regression of the echo fix: a folder made in UTF-8 unreachable
  once the server was legacy): fixed; NOTE 1 re-assigned parser columns counted as evidence:
  fixed (and the pre-existing join defect -> Inbox); NOTE 2 sent names fill the bound: fixed;
  NOTE 3-5 limits recorded.
Details: `fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

- `ftp-288-real-server-checks` - FTP 288 on real servers: names to a code-page server, mainframe
  listings (a real IIS 6 / old Serv-U style server; AS/400, z/VM, VxWorks not driven).
- `ftp-ask-server-utf8-feat-decision` - the maintainer's decision whether the plug-in sends FEAT.

## New Inbox items (slug - title)

- `ftp-ask-server-utf8-feat-decision` - FTP: should the plug-in ask a server whether it speaks UTF-8 (FEAT)?
- `ftp-panel-mkdir-rename-skip-upload-listing-cache` - FTP: Create Directory and Quick Rename in a panel never update the upload listing cache
- `ftp-listing-rule-joins-utf8-with-raw-bytes` - FTP: a name a listing rule extends (z/VM, AS/400, VxWorks) mixes UTF-8 with raw server bytes
- `ftp-288-real-server-checks` - FTP 288 on real servers: names to a code-page server, mainframe listings
