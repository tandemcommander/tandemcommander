# Fix log - 347-ftp-lock-two-names

Backlog item `ftp-opened-file-lock-two-names-of-one-server` (severity 6 -> 7 by its note, after
the measurement). Branch from `main` 794b3207.

## Measurement before (main 794b3207)

- Site: `CFTPOpenedFile::IsSameFile` (`src/plugins/ftp/operats9.cpp`) -
  `strcmp(User, user) == 0 && StrICmp(Host, host) == 0 && Port == port && FTPIsTheSameServerPath(...)
  && name rule`. `CFTPOpenedFiles::OpenFile` refuses only when an entry `IsSameFile` and
  `IsInConflictWith`.
- Consumers of the lock (Grep `FTPOpenedFiles.OpenFile`): upload `operatsb.cpp` (fwssWorkUploadLockFile,
  and two resume / existing-target branches), download / copy-move from the server
  `operats8.cpp` (source read, and the Move's delete), delete `operats4.cpp`, panel view / quick
  rename `ctrlcon5.cpp` (download for viewing; rename locks both names). All pass the operation's
  or connection's user / host / port; all go through the one `IsSameFile`.
- Reachable: two Copy (F5) uploads, one typed to `ftp://u:p@localhost:<port>/...`, one into a panel
  at `ftp://u@127.0.0.1:<port>`.
- Probe `probe/ftp347_probe.ps1` (new; based on 341's review-3 probe), server
  `probe/ftpmini_hold.py` (323's `ftpmini_hide.py` + a 20 s hold before creating a `hold*` file +
  `stor-begin` / `stor-done` log events). Command (PowerShell, hidden desktop):
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\347-ftp-lock-two-names\probe\result_main.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <probe> -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`
  (run from a scratch copy with `-Repo`). Result `probe/result_main.txt`: **PASS 5, FAIL 1**:
  - ALIAS-LOCK FAIL: 2 STOR hold.txt, 1 while the other was in flight; server file 'UP2'; both
    operations "(100 %)" - upload 1's content silently replaced.
  - SAME-LOCK PASS: 1 STOR; upload 2 asked "Target File Already Exists" (the listing cache knew).
  - OTHER-USER (facts only): upload 1 as user v, upload 2 as u at the same host: 2 STOR, 1
    overlapping, server 'UP2' - the same loss under another user; outside the item's scope
    (Expected: "the same user and port") -> Inbox item.
  - Registry restored, identical hash.

## Decisions

- Identity of the lock: same user (exact, as before), same port, same path / name rules; the host
  no longer decides (any other host may be the same server - feature 341's rule, the item's
  *Expected*). Refusal stays the answer (existing `ITEMPR_TGTFILEINUSE` etc.).
- No header under `src/common/`: the decision is dropping one term of a plug-in-internal
  comparison that also needs the plug-in's path rule (`FTPIsTheSameServerPath`); the probe is the
  test. Recorded here per stop-rules §2.5.

## Analyze

speckit-analyze: CRITICAL 0, HIGH 0. Accepted: C1 MEDIUM (US2 - other access types under two
names - by reading only: one decision serves every access type, `IsInConflictWith` unchanged),
C2 LOW (each caller's refusal answer recorded under T007), C3 LOW (FR-005 checked by the diff).

## Change (T003, T004)

- `src/plugins/ftp/operats9.cpp` `CFTPOpenedFile::IsSameFile`: the term
  `SalamanderGeneral->StrICmp(Host, host) == 0` removed (the parameter stays - no caller changes);
  comment names 341's rule and the cost.
- `src/plugins/ftp/operats.h`: `IsSameFile` comment ("may be the same file ... under any host
  name") and the `Host` field ("kept for diagnostics; not part of the identity").

## Callers (T007)

Every `FTPOpenedFiles.OpenFile` passes the operation's / connection's own user, host, port, as
before; each keeps its refusal answer:
- upload `operatsb.cpp` (lock before store, resume / existing-target branch): item failed
  `ITEMPR_TGTFILEINUSE` ("Target File Is Locked By Another Operation" - seen in the probe);
  auto-rename loop: a locked candidate name counts as taken, the next name is tried.
- download / Move source `operats8.cpp` (ffatRead) and Move's delete (ffatDelete):
  `ITEMPR_SRCFILEINUSE`.
- delete `operats4.cpp` (ffatDelete): `ITEMPR_SRCFILEINUSE`.
- panel view `ctrlcon5.cpp` (ffatRead): `IDS_DOWNLOADFILEERROR` + "locked by another operation";
  Quick Rename (ffatRename on both names): `IDS_QUICKRENAMEFILEERR` + suffix.
`IsInConflictWith` unchanged: two reads still run together.

## Measurement after (branch, build of the change)

- `.\build.cmd` -> BUILD SUCCEEDED (only the FTP plug-in's pre-existing C4267 warnings);
  `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Probe `probe/result_after.txt`: **PASS 6, FAIL 0**:
  - ALIAS-LOCK PASS: 1 STOR hold.txt, 0 overlapping; upload 2 sent `CWD / PORT / LIST / CWD / QUIT`
    and its window shows "Target File Is Locked By Another Operation" `/ALIAS-LOCK | hold.txt`;
    server file 'UP1'.
  - SAME-LOCK PASS (unchanged: the overwrite question).
  - OTHER-USER (facts): still 2 STOR, 1 overlapping, 'UP2' - outside the scope ->
    Inbox `ftp-two-uploads-as-another-user-or-port-of-one-server-can`.
  - Registry restored, identical hash.
- Negative control (T009): the same probe on `main` 794b3207 (`probe/result_main.txt`) -
  ALIAS-LOCK FAIL (2 STOR, 1 overlapping, 'UP2').
- saltests: not run - no change under `src/common/` or the core.
- Regressions (T008): 341's `ftp341_probe.ps1` -> `probe/regress_341.txt` PASS 12 / FAIL 0; 345's
  `ftp345_probe.ps1` -> `probe/regress_345.txt` PASS 16 / FAIL 0; registry restored + identical in
  both.
