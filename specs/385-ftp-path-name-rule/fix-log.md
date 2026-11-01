# Fix log - 385-ftp-path-name-rule

Backlog item `ftp-server-path-compare-code-page-fold` (source review:277). HEAD0 = 6428f7e9.

## Measurement before the fix (on main 6428f7e9, build of that tree)

- Reading: `FTPIsPrefixOfServerPath` (`src/plugins/ftp/ftputils.cpp`) compares VMS / MVS / z/VM /
  Tandem paths with `SalamanderGeneral->StrNICmp(prefix, path, l1)` and Windows / NetWare / OS/2
  and AS/400 paths with `LowerCase[*s1] == LowerCase[*s2]` - both `CharLowerA` per byte, over
  UTF-8 bytes; the length tests compare the prefix's byte count with the path's.
- Byte table (python ctypes `CharLowerA`, ACP 1250): `Č` C4 8C -> E4 9C, `č` C4 8D -> E4 9D
  (different), `Ĝ` C4 9C -> E4 9C (= `Č`), `ĥ` == `Ĺ`. `CompareStringOrdinal(TRUE)`: U+0250
  (2 UTF-8 bytes) == U+2C6F (3 bytes); `ſ`, `ı`, the Kelvin sign != ASCII letters.
- Callers: 22 sites, table in research.md R2.
- GUI probe `probe/ftp385_probe.ps1` (new; 345's driver, a copy of 323's server `probe/ftpmini385.py`
  answering SYST `215 Windows_NT` -> Windows path type), run with
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\385-ftp-path-name-rule\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\385-ftp-path-name-rule\probe\ftp385_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`:
  `probe/result_before.txt` **PASS 5, FAIL 1**:
  - CROSS **FAIL**: upload 1 of o1.txt into `/CROSS/Č` held at its question; upload 2 of x.txt typed
    into `/CROSS/Ĝ` (which holds x.txt `SRV-X`): `CWD /CROSS/Ĝ`, `STOR x.txt` - no question, the
    server's x.txt became `LOCAL-X`. The upload listing cache answered with `/CROSS/Č`'s listing.
    **Data loss**, not only the "severity 4" the item assumed.
  - ASCII PASS (control, `/ASCII/a` -> `/ASCII/b`: LIST, question).
  - CASE PASS, upload 2 listed: True - `/CASE/Čaj` cached, upload 2 into `/CASE/čaj` (the same NTFS
    folder) missed the cache and listed again (the old fold's other direction).
  - Registry restored identical (SHA-256 0014109...20B4).
- Probe traps met: PowerShell variable names ignore case (`$Ccaron` and `$ccaron` were one variable:
  the first run compared `č` with `Ĝ`, which the fold does not join, and passed); `-OutFile` must
  not name the `-Log` file of `run_on_hidden_desktop.ps1` (it holds it open).

## The fix

- `src/common/salftpsrvpath.h` (new, header-only): `SalFtpServerPathIsPrefix(kind, prefix, path,
  mustBeSame)` - the old `FTPIsPrefixOfServerPath` body, with the byte fold replaced by a walk
  separator by separator and name by name (`SalNameOrderEqualCI`, 092); every length test that
  compared the prefix's byte count with the path's uses the position the walk reached in the path.
  Separators: VMS `.` `[` `]` (unescaped), MVS `.` `'`, Windows / NetWare / OS/2 `/` = `\`, z/VM /
  Tandem `.`, AS/400 `/`. Unix / unknown: the old byte rule unchanged. VMS: the old read of
  `prefix[-1]` for an empty prefix is guarded (`l1 > 0`).
- `src/plugins/ftp/ftputils.cpp`: `FTPIsPrefixOfServerPath` maps `CFTPServerPathType` to the kind
  and calls the header. AS/400 included (case-insensitive, the same per-byte fold; the item's
  *Expected* says "case-insensitive server types").
- Callers (research.md R2, 22 sites): none changed. The explore's cycle check (`operats7.cpp`,
  "the server's path is a proper ancestor of the expected one") detects every cycle the old rule
  detected for real (byte-identical or case-equal names) plus the case twins the old fold missed;
  the fold's extra matches (`Č` / `Ĝ`) are different folders, not cycles; `CExploredPaths`
  (byte-exact) stays the backstop - conservative as the item asks.

## Checks after the fix

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (ftp.spl and saltests.exe rebuilt 23:46).
- `saltests.exe` -> `saltests: 30586 checks, 0 failed` (17.7 s). `TestFtpServerPath385`:
  - ASCII equivalence with a copy of the old function (`OldPrefix385`, the legacy byte fold of
    salnameorder = the core's `LowerCase`): every pair of a generated set per kind, both modes -
    Slashes 788 paths, AS/400 785, VMS 1564, MVS 1369, z/VM-Tandem 1369, Unix 1095 (1.2 M - 4.9 M
    pairs each, all > 1 M): 0 differences.
  - 38 non-ASCII rows (case twins, the fold collisions `Č`/`Ĝ` and `ĥ`/`Ĺ`, U+0250 / U+2C6F of
    different UTF-8 length, the Kelvin sign, NFC / NFD, text that is not UTF-8, VMS escapes and
    `[000000]`, MVS, z/VM, Tandem, AS/400, Unix stays case-sensitive) - all as expected.
  - **Negative control** (inline, ACP 1250): the old rule answers the other way in exactly the 22
    rows marked so (`oldFailed == 22` checked).
  - A 600-byte non-ASCII name (over salnameorder's 519-byte stack buffer) compared whole.
- Probe `probe/result_after.txt`: **PASS 6, FAIL 0** - CROSS: `CWD /CROSS/Ĝ`, `LIST`, the question
  for x.txt, server x.txt `SRV-X`; ASCII unchanged; CASE: upload 2 listed: **False** (the cached
  listing of `/CASE/Čaj` now answers for `/CASE/čaj`). Registry restored identical.
- Regressions (`probe/regress_*.txt`): 215 PASS 12 / 0; 224 PASS 16 / 0; 233 PASS 3 / FAIL 3 -
  DLT / DLC / UPT, the rows 233 recorded as its probe defect and 277 recorded the same way
  (`specs/277-ftp-pwd-path-cut/probe/regress_233.txt` 3 / 3); 277 PASS 10 / 0.
  These four probes use a server answering `215 UNIX Type: L8` (215's `ftpmini.py`), which takes
  the unchanged byte rule: they show that the Unix path type and the rest of the plug-in did not
  move, nothing about the changed kinds (review 1, SHOULD 1). The changed code is proven in the GUI
  by this feature's probe only (upload listing cache, Windows type) and at function level by
  saltests for every kind and every caller's comparison.
- Not driven: the opened-file lock (two concurrent operations on one file) - it goes through the
  same function (`CFTPOpenedFile::IsSameFile` -> `FTPIsTheSameServerPath`), covered by saltests;
  VMS / MVS / z/VM / Tandem / AS/400 servers by saltests only (no such server here).

## Review

- Review 1 (independent, refute-first, general-purpose agent): **no MUST**. It built the old FTP
  plug-in (8bd858ba) in its own worktree: `ftp385_probe.ps1` 5 / 1, CROSS `STOR x.txt` without
  the question, server x.txt `LOCAL-X`; on the fix 6 / 0; saltests 30,586 / 0; its own harness over
  z/VM, Tandem, MVS, AS/400, VMS with case pairs of different UTF-8 length, OS/2 drive, `ß`: all
  by the 092 rule (100,000 non-ASCII calls 16 ms). Callers enumerated by itself: the 22 of R2,
  every changed answer conservative or the right one.
  - SHOULD 1 (the regression probes use a UNIX-type server, they do not reach the changed kinds):
    stated above under *Checks after the fix*.
  - SHOULD 2 (VMS / AS/400: whether the server joins `Č` / `č` is unknown; the new rule joins
    them): recorded in spec.md *Assumptions* as accepted (the item asks for the 092 rule on every
    case-insensitive type).
  - NOTE 3 (`FindPath` stores the slot instead of the index - speed only, older than 385): Inbox
    `ftp-upload-listing-cache-lookup-remembers-a-slot-number`.
  - NOTE 4 (`FTPIsCaseSensitive` takes unknown / empty types as case-insensitive, the path rule as
    byte-exact; the lock errs towards more conflicts, older than 385): recorded, no change.
  - NOTE 5 (clang-format of the new header): formatted (0 warnings); build + saltests 30,586 / 0
    again (formatting only).
  - NOTE 6 (the closing record says data loss): done in the history and changelog entries.
