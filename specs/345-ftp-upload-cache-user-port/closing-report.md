# Closing report - 345-ftp-upload-cache-user-port
Backlog item: ftp-upload-cache-other-user-or-port-of-one-server - FTP: an upload as another user or on another port of one server misses the panel changes
Outcome: closed

## What changed

`src/plugins/ftp/operats.h`, `src/plugins/ftp/operats9.cpp` (`CUploadListingCache`):
- `InvalidateOtherNamesOfServer`: a change reported for one connection (host, user, port)
  invalidates the cached listings of **every** other connection - before, only of those with the
  same user and port under another host name (feature 341).
- `ChangedUnderOtherName`: a panel listing offered to an upload's cache is refused when a change
  was stamped under any other connection after the listing started.
- New static `SameIdentity` - the one definition of "own" (host case-insensitive, user exact with
  `anonymous` = no user, port), used by `FindServer`, `StampChange` and `ChangedUnderOtherName`.

Reason (spec *Clarifications*): the client cannot tell which accounts, ports and host names share
folders; item *Expected* and rule 098 (fail closed), as in 341. No UI, string, registry, plug-in
interface or network change (no `.slt` refresh, no `PRIVACY.md` change).

## Measurements (before / after, commands)

Probe `probe/ftp345_probe.ps1` on the hidden desktop
(`powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\345-ftp-upload-cache-user-port\probe\ftp345_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`):
two `ftpmini_hide.py` servers on 127.0.0.1:2145 / :2146 serving one folder, the panel
`u@127.0.0.1:2145`.

| Row | main ad3eb597 (`result_main.txt`) | fix (`result_after.txt`) |
|---|---|---|
| USER-REN (uploads as `v`) | FAIL - `STOR b.txt`, no question, `b.txt` = `LOCAL-B` | PASS - question, `SRV-A` kept |
| PORT-REN (uploads to :2146) | FAIL - the same | PASS |
| ALL-REN (`v@localhost:2146`) | FAIL - the same | PASS |
| ALIAS-REN (341 control) | PASS | PASS |
| SAME-REN (control) | PASS | PASS |
| SEED-USER (panel seed after a store as `v`) | FAIL - `STOR n.txt`, `n.txt` = `UP3` | PASS - question, `UP2` kept |
| SEED-PORT | FAIL - the same | PASS |
| SEED-SAME (control) | PASS | PASS |
| Total (ROW + END) | 11 PASS / 5 FAIL | 16 PASS / 0 FAIL |

Registry restored identical in every run.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `build.cmd` (Debug x64): BUILD SUCCEEDED.
- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `saltests.exe`: `saltests: 28952 checks, 0 failed`.
- `ftp345_probe.ps1`: 16 / 0 (above). Regressions: 341's `ftp341_probe.ps1` 12 / 0
  (`probe/regress_341.txt`), 323's `ftp302_probe.ps1` 16 / 0 (`probe/regress_302.txt`).
- Negative controls: the code without the fix (`main`) 5 FAIL; review 1's partial mutants - only
  `ChangedUnderOtherName` reverted -> SEED-USER / SEED-PORT FAIL; only
  `InvalidateOtherNamesOfServer` reverted -> USER-REN / PORT-REN FAIL (`probe/review1/`).

## Reviews (findings and what was done)

Review 1 (refute-first, independent agent): MUST 0, SHOULD 1, NOTE 3.
- SHOULD: the cost of failing closed was understated - an in-progress listing invalidated by
  another connection's change is downloaded again with no limit, so an upload can stall while
  another upload under another connection keeps storing files. Documented in the spec and the
  feature history; the mitigation is the maintainer's choice -> Inbox decision item.
- NOTEs: `result_main.txt` was produced by the probe before it was moved into the repository
  (banner `ftpup_probe`; recorded in the fix-log); closing entries were still to be written (done);
  old review worktrees of earlier features are registered in git (not this feature's; left alone).

## Owed to a person (with the new person-step items)

- The CHANGELOG entry below: `CHANGELOG.md` has no `## [Unreleased]` section (0.2.0 is
  released; versions and sections are the maintainer's), so it was not added. Entry text:

  ```text
  - **An FTP upload as another user or on another port of a server could replace a renamed or newly uploaded file without asking** (feature 345).
    - **Before:** while an upload to an FTP server ran as one user (`ftp://v@...`) or on one port, a change made in an FTP panel connected to the same server as another user (two accounts that see the same folders) or on another port (a forwarded port) did not reach that upload: a file renamed in the panel to `b.txt` was then replaced by an uploaded `b.txt` without the "Target File Already Exists" question, and an upload into the panel could trust the panel's older listing after a file was stored as the other user or port.
    - **Now:** a change made through any FTP connection (Create Directory, Quick Rename, Delete, Send FTP Command, an upload) makes every running upload through any other connection - another server name, user or port - list the folder again before it decides whether a name exists, and a panel listing taken before such a change is not trusted - the overwrite question appears. Nothing new is sent over the network beyond listing the folder again.
    - **Limitation:** which accounts and ports share folders cannot be told, so two uploads through different connections - also to two unrelated servers - list their folders again after each other's changes, and a large folder's listing can be restarted for as long as the other upload keeps storing files - slower, never less safe. The panel's own refresh and the opened-file lock under two names are not covered yet (recorded for later fixes).
  ```

- The decision `ftp-two-uploads-under-different-connections-can-stall-each` (whether to mitigate
  the stall).
- No person-step item: every probe row was driven (no NOT DRIVEN rows).

## New Inbox items (slug - title)

- `ftp-two-uploads-under-different-connections-can-stall-each` - FTP: two uploads under different
  connections can stall each other while listing (decision, review:345).
