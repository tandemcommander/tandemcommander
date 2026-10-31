# Fix log - 348-ftp-lock-user-port

Backlog item `ftp-two-uploads-as-another-user-or-port-of-one-server-can` (severity 6). Branch from
`main` 4e2c8835.

## Measurement before (main 4e2c8835) - T001, T002

- Site: `CFTPOpenedFile::IsSameFile` (`src/plugins/ftp/operats9.cpp`) -
  `strcmp(User, user) == 0 && Port == port && FTPIsTheSameServerPath(...) && name rule` (the host
  dropped by 347). `CFTPOpenedFiles::OpenFile` refuses only when an entry `IsSameFile` and
  `IsInConflictWith`.
- Reachable: two Copy (F5) uploads of one file, one typed to `ftp://v:p@<host>:<port>/...` (another
  user) or through another port, one into a panel at `ftp://u@<host>:<port>`.
- Probe `probe/ftp348_probe.ps1` (new; based on 347's `ftp347_probe.ps1`), server
  `probe/ftpmini_hold2.py` (347's `ftpmini_hold.py` + an optional second listening port served by
  the same sessions, one folder, one log; every `connect` event names its port). Build: `.\build.cmd`
  at HEAD -> BUILD SUCCEEDED (up to date). Command (PowerShell, hidden desktop; run from a scratch
  copy with `-Repo`, before the branch existed):
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_main.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\ftp348_probe.ps1 -Exe <build>\tandemcommander.exe -Repo E:\Projects\tandemcommander"`.
  Result `probe/result_main.txt`: **PASS 7, FAIL 3** (exit 3):
  - OTHER-USER FAIL (upload 1 as `v:p@127.0.0.1:2148`, upload 2 into the panel `u@127.0.0.1:2148`):
    2 STOR hold.txt, 1 while the other was in flight, server file 'UP2', upload 2 not refused.
  - OTHER-PORT FAIL (upload 1 as `u:p@127.0.0.1:2149`, the same folder): the same.
  - ALL-OTHER FAIL (upload 1 as `v:p@localhost:2149`): the same.
  - ALIAS-LOCK PASS (347's row: another host name only) - refused by the lock, 'UP1'.
  - SAME-LOCK PASS (control: the overwrite question; the lock is not reached).
  - All END rows PASS; registry restored, identical hash.

## Decisions

- Identity of the lock: the server path (server type's rule) and the file name (server type's
  case rule) only; host, user and port no longer decide (feature 345's rule: every other connection
  is maybe the same server; the item's *Expected*). Refusal stays the answer.
- Cost accepted (item *Notes*, as 347 for host names): unrelated servers / accounts with the same
  server path and name refuse each other's conflicting access while one runs; the refused item can
  be retried; two reads still run together.
- No header under `src/common/`: the decision removes two terms of a plug-in-internal comparison
  that also needs the plug-in's path rule (`FTPIsTheSameServerPath`); the probe is the test
  (stop-rules §2.5, as 347).

## Analyze

speckit-analyze: CRITICAL 0, HIGH 0. Accepted: C1 LOW (FR-005 checked by the diff at closing), C2
LOW (US3 by reading - one decision serves every access type, `IsInConflictWith` unchanged), F1 LOW
(347's OTHER-USER row is facts only - its fact line is recorded under T009).

## Callers (T003, T008)

`FTPOpenedFiles.OpenFile` sites (Grep `src/plugins/ftp`): 9. Each passes its own operation's /
connection's user, host, port (unchanged) and keeps its refusal answer:
- upload `operatsb.cpp` (3: lock before store, auto-rename candidate loop, resume / existing-target
  branch; `ffatWrite`): item failed `ITEMPR_TGTFILEINUSE` ("Target File Is Locked By Another
  Operation" - seen in the probe); a locked auto-rename candidate counts as taken.
- download / Move source `operats8.cpp` (`ffatRead`) and Move's delete (`ffatDelete`, after the
  read lock is closed): `ITEMPR_SRCFILEINUSE`.
- delete `operats4.cpp` (`ffatDelete`): `ITEMPR_SRCFILEINUSE`.
- panel view `ctrlcon5.cpp` (`ffatRead`): `IDS_DOWNLOADFILEERROR` + "locked by another operation";
  Quick Rename (`ffatRename` on the from and the to name, one connection): `IDS_QUICKRENAMEFILEERR`.
No self-conflict is introduced: one connection has one user and port, so every pair of locks of
one operation / one connection compared equal on user and port before as well. Rename + rename
never conflicts (`IsInConflictWith`); no caller waits for a lock (no deadlock). `IsInConflictWith`
unchanged: two reads still run together.

## Change (T004, T005)

- `src/plugins/ftp/operats9.cpp` `CFTPOpenedFile::IsSameFile`: the terms `strcmp(User, user) == 0`
  and `Port == port` removed (parameters stay - no caller changes); identity = server path
  (`FTPIsTheSameServerPath`) + name (server type's case rule). Comment names 345's rule and the
  cost.
- `src/plugins/ftp/operats.h`: `User` / `Port` field comments ("kept for diagnostics; not part of
  the identity, feature 348"), `IsSameFile` comment.

## Measurement after (branch, build of the change) - T006, T007

- `.\build.cmd` -> BUILD SUCCEEDED; `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Probe (`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\348-ftp-lock-user-port\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\348-ftp-lock-user-port\probe\ftp348_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`)
  -> `probe/result_after.txt`: **PASS 10, FAIL 0**:
  - OTHER-USER, OTHER-PORT, ALL-OTHER PASS: 1 STOR hold.txt, 0 while another was in flight;
    upload 2 listed, its window "Target File Is Locked By Another Operation"; server file 'UP1'.
  - ALIAS-LOCK, SAME-LOCK PASS (unchanged).
  - Registry restored, identical hash.
- Negative control: the same probe on `main` 4e2c8835 (`probe/result_main.txt`) - the three rows
  FAIL (2 STOR, 1 overlapping, 'UP2').
- saltests: not run - no change under `src/common/` or the core.
- Regressions (T009), on the change's build, hidden desktop: 341's `ftp341_probe.ps1` ->
  `probe/regress_341.txt` PASS 12 / FAIL 0; 345's `ftp345_probe.ps1` -> `probe/regress_345.txt`
  PASS 16 / FAIL 0; 347's `ftp347_probe.ps1` -> `probe/regress_347.txt` PASS 6 / FAIL 0 - its
  facts-only row OTHER-USER now shows 1 STOR hold.txt, 0 while another was in flight, server 'UP1'
  (on 347's branch: 2 / 1 / 'UP2'). Registry restored + identical in all three.

## Review

Review 1 (independent agent, refute-first): **MUST 0**, SHOULD 2, NOTE 3.
- Re-ran the probe on the branch build: PASS 10 / FAIL 0. Own negative control: `ftp.spl` built
  from `main` 4e2c8835 in a separate worktree and build folder, dropped into a copy of the branch
  tree: OTHER-USER, OTHER-PORT, ALL-OTHER FAIL (2 STOR, 1 overlapping, 'UP2', upload 2 not
  refused); registry restored identical.
- Enumerated the 9 `OpenFile` sites and the release sites: the change only adds refusals; no
  waits (no deadlock); one operation = one connection (FTP-to-FTP copy unsupported, `fs4.cpp`), so
  no self-conflict; a refused upload item fails `ITEMPR_TGTFILEINUSE`, retryable; Move keeps its
  source. Path compare across two server types bounded (`FTPIsPrefixOfServerPath`).
- SHOULD 1 (done): limit - a shared folder seen at two different absolute paths (per-account
  chroot, a symbolic link) is still two files to the lock; the client cannot tell. Added to the
  spec's *Edge Cases*, the FEATURE-HISTORY entry and the changelog text. No Inbox item: no client
  rule can see it (comparing names alone would refuse every same-named file on every server).
- SHOULD 2 (done at closing): FEATURE-HISTORY entry, changelog text, closing report.
- NOTE 1: the cost is plausible (staging and production uploaded at once: a same-named item
  refused "in use" while the other stores; a long download of `/x` from server A refuses an
  upload / delete / rename / view of `/x` on B) - named in the history entry and the changelog
  text. NOTE 2: the open item `ftp-server-path-compare-code-page-fold` now applies across all
  connections (same kind of effect: an extra refusal or a missed non-ASCII case match) - named in the closing report (the
  item itself is left unchanged). NOTE 3: the probe is sound (one folder on two ports; refusal identified by its own
  window text).
- `git status --short` empty after the review.
