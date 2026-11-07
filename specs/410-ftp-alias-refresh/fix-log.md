# Fix log - 410-ftp-alias-refresh

Backlog item `ftp-panel-refresh-misses-change-under-another-name` (source review:341, severity 4).

## Measurement at 2ce004b9 (before)

Sites (by reading): a change-on-path notification reaches the FTP plug-in in
`CPluginInterface::AcceptChangeOnPathNotification` (`ftp.cpp`: `ListingCache.AcceptChangeOnPathNotification`
+ `RemoveFilesFromCache` of the notified name) and, once per FS in a panel or detached (core
`mainwnd3.cpp`), in `CPluginFSInterface::AcceptChangeOnPathNotification` (`fs3.cpp`: refresh when
`FTPHasTheSameRootPath` - user, host `StrICmp`, port as typed). `CListingCache::AcceptChangeOnPathNotification`
(`ctrlcon4.cpp`) compares the host too. The listing cache is on by default (`Config.UseListingsCache = TRUE`,
`ftp3.cpp`).

New probe `probe/ftp410_probe.ps1` (hidden desktop) with `probe/ftpmini_sess.py` (323's
`ftpmini_hide.py`, every log line carries the number of its control connection, so the panel's
connection is told from the upload's workers). Panel `ftp://u@127.0.0.1:2143/...`, uploads typed to
`ftp://u:p@localhost:2143/...`.

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_main.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File ...\ftp410_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"
```

`probe/result_main.txt` (PASS 8, FAIL 2), `probe/result_main_view.txt` (VIEW rows added later, run on
the same old build: PASS 3, FAIL 1):

| Row | at 2ce004b9 | what was seen |
|---|---|---|
| REFRESH-ALIAS | FAIL | upload STOR n.txt via localhost; the panel's connection sent nothing - the panel keeps the old listing |
| REFRESH-SAME | PASS | control: the panel's connection lists again |
| REFRESH-ELSE | PASS | upload to another folder: no listing (path rule) |
| CACHE-ALIAS | FAIL | Enter on `sub` after a change via localhost: no LIST - the stale cached listing shown |
| CACHE-SAME | PASS | control |
| VIEW-ALIAS | FAIL | F3 on x.txt again after a change via localhost: no RETR - the stale viewed copy shown (finding, see below) |
| VIEW-SAME | PASS | control: RETR x.txt again |

All END rows PASS; registry restored, hash identical.

## Decisions

- Rule (spec Clarifications): another host with the same user and port is "another name of the
  server" (the item's *Expected*, 341's maybe-the-same-server). Another user / port: unchanged.
- Pure rule `src/common/salftproot.h` (`SalFtpSameUser`, `SalFtpSamePortText`, `SalFtpRootMatchOf`);
  `FTPRootPathMatch` (`ftputils.cpp`) splits the two roots and applies it; `FTPHasTheSameRootPath`
  is now `== SAL_FTP_ROOT_SAME` (its other caller `IsOurPath`, `fs2.cpp`, unchanged in effect).
- `fs3.cpp`: refresh also on `SAL_FTP_ROOT_OTHER_HOST` with the same path rule and timing;
  `NextRefreshWontClearCache` stays TRUE (the notification itself drops the path's caches for every
  host - revised after review 1, see *Review*); under another host name a panel whose connection is
  closed is not refreshed (review 1).
- `ctrlcon4.cpp`: the listing cache drops entries of the same user and port whatever the host.

## Findings fixed on the way

- **Viewer cache under another name** (severity 4, stop-rules rule 11): files viewed (F3) through a
  connection are cached under its own name; a change via another name dropped only the notified
  name's files, so viewing again showed the old copy (row VIEW-ALIAS FAIL at 2ce004b9). Now
  `CPluginFSInterface::AcceptChangeOnPathNotification` drops, for every FS of another host with the
  same user and port (panel or detached), the viewed files of the notified path under its own root
  (`ftp:` and `ftps:`, as `ftp.cpp` does for the notified name; a name that does not fit is skipped -
  nothing is cut). Row VIEW-ALIAS PASS after.

## Checks (after)

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 282637 checks, 0 failed` (`TestFtpRootMatch410`: 24 checks) |
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| probe | `ftp410_probe.ps1` -> `probe/result_after.txt` | PASS 14, FAIL 0; registry restored, identical |
| regression | 341's `ftp341_probe.ps1` -> `probe/regress_341.txt` | PASS 12, FAIL 0; registry identical |
| probe after review 1 | `ftp410_probe.ps1` -> `probe/result_after.txt` (overwritten) | PASS 16, FAIL 0 (row REFRESH-CLOSED added) |

## Negative controls (in place, restored and rebuilt after)

| Mutant | Change | Rows run | Result |
|---|---|---|---|
| A | `fs3.cpp`: refresh / viewer drop only for `SAL_FTP_ROOT_SAME` (the old rule) | REFRESH*, VIEW*, CACHE-ALIAS -> `probe/result_negative_a.txt` | REFRESH-ALIAS FAIL, VIEW-ALIAS FAIL; the others PASS |
| B | `ctrlcon4.cpp`: the host compared again | CACHE*, REFRESH-ALIAS -> `probe/result_negative_b.txt` | CACHE-ALIAS FAIL; the others PASS |

After restoring both files (CRLF checked; Git Bash `sed -i` had dropped the CRs of a mutated copy -
the restore was from a CRLF copy, line counts compared) the build was rebuilt and the whole probe run
again: PASS 14, FAIL 0 (the file was overwritten by the run after review 1, PASS 16).

## Limits

- Another user or another port of a server (feature 345's wider rule for the upload cache) is not
  refreshed and its cached listings are kept - the item names the host only (spec Clarifications).
- A panel at a parent folder of the changed one is not refreshed (as under its own name).
- Two unrelated servers with the same user, port and folder: a change on one refreshes a panel at
  that folder on the other (one extra listing) - 341's rule, the client cannot tell them apart.
- Viewed files cached under a name of a connection that is no longer open are not dropped (no FS
  holds that name any more); `ClearHostFromListingCacheIfFirstCon` drops them when that name is
  connected again first.
- Rename and delete are not driven by the probe; by reading they post the same notification
  (`operats2.cpp` `PostChangeOnPathNotifications`, `fs5.cpp` Quick Rename / delete) - review 1, NOTE 6.
- Two names of one server set to different server encodings (feature 288) give different bytes of
  the notified path: neither the refresh nor the viewed-file drop matches (review 1, NOTE 7; edge).
- The listing cache compares the port as a number, the panel / viewer rule as text (`021` vs `21`);
  older than this feature, harmless (review 1, NOTE 4).

- A panel of another host whose connection is closed shows nothing that its listing is outdated;
  only its caches are dropped, the next refresh or entering the folder lists again (review 2,
  NOTE 4 - the item's *Expected* "so that the next use lists it again").
- The closed-connection decision is made when the notification arrives: a soft refresh waiting for
  the main window's activation, or the `FSE_TIMER` wait, can still meet a connection closed in
  between (the reconnect question then, as before 410); a connection lent to the panel's own
  operation counts as closed, so a change under another name in that window leaves the panel
  stale until Ctrl+R (pre-410 behaviour; review 2, NOTE 3).
- No row proves the caches are dropped for a closed-connection panel; by reading the viewed-file
  drop runs before the `onlyOutdated` test and the listing-cache drop (`ftp.cpp`) does not depend on
  the connection (review 2, NOTE 2).

## Review

### Review 1 (refute-first agent) - MUST 0, SHOULD 1, NOTE 6

Its own measurements: `ftp410_probe.ps1` 14 / 0 on the branch build; the FTP plug-in of HEAD~1 built
in its own folder fails REFRESH-ALIAS, CACHE-ALIAS, VIEW-ALIAS (REFRESH-SAME PASS); saltests 282637 /
0; encoding guard 0; callers: `IsOurPath` (`fs2.cpp`) unchanged in effect, the listing cache's user
test equivalent (items store anonymous as NULL); no data can be lost (only caches dropped, the disk
cache marks files in use outdated).

| # | Finding | Done |
|---|---|---|
| SHOULD 1 | another host may be another server: a panel whose connection is closed (keep-alive ended) would ask "reconnect?" or log in again for a change made elsewhere | fixed: `fs3.cpp` refreshes an other-host panel only while its connection is open (`onlyOutdated`); its caches are dropped anyway. New row REFRESH-CLOSED (`ftpmini_sess.py` kick file closes the panel's connection): on the review-1 build FAIL - the reconnect question, Yes, session #4 logged in and listed (`probe/result_closed_before.txt`); after PASS |
| NOTE 2 | clearing `NextRefreshWontClearCache` for another host is redundant (mutant C kept TRUE: 14 / 0); comment stale | reverted to TRUE with a corrected comment; spec FR-003 / Clarifications, research R3 corrected |
| NOTE 3 | SC-004 claimed a "password ignored" check | SC-004 corrected (the password is split off in `FTPRootPathMatch`, not linkable) |
| NOTE 4 | port compared as number vs text | documented (*Limits*) |
| NOTE 5 | T011 ticked early | done at the close (records) |
| NOTE 6 | rename / delete not probed | documented (*Limits*, by reading) |
| NOTE 7 | different server encodings defeat the match | documented (*Limits*) |

### Review 2 (refute-first agent) - MUST 0, SHOULD 0, NOTE 4

Its own measurements: `ftp410_probe.ps1` 16 / 0 on the branch build (checked built from HEAD); the
FTP plug-in of HEAD~1 built in its own worktree fails REFRESH-CLOSED (the reconnect question, a new
session logs in and lists) and passes REFRESH-ALIAS - confirms `result_closed_before.txt`; 341's
`ftp341_probe.ps1` 12 / 0; saltests 282637 / 0; encoding guard 0. By reading: in the closed case an
upload into the stale panel still asks (341/345's `ChangedUnderOtherName`, SEED-ALIAS PASS);
`IsConnected()` takes a lock, used from the main thread elsewhere; same-name path and `IsOurPath`
unchanged; no buffer, cut or code-page call added.

| # | Finding | Done |
|---|---|---|
| NOTE 1 | plan.md, tasks.md T005, FR-001 and the success criteria still described the first design / missed REFRESH-CLOSED | corrected |
| NOTE 2 | no row proves the caches are dropped for a closed panel | documented (*Limits*); the order is stated in the `fs3.cpp` comment ("the viewed files above") |
| NOTE 3 | decision at notification time; a lent connection counts as closed | documented (*Limits*) |
| NOTE 4 | nothing on screen shows "outdated" | documented (*Limits*) |

No code changed after review 2 (documents only), so the build and probe results of the review-1
commit stand.
