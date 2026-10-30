# Fix log - 345-ftp-upload-cache-user-port

Backlog item `ftp-upload-cache-other-user-or-port-of-one-server` (source review:341). Autonomous run
of `/tandem-backlog-implement`, 2026-10-30, `main` at ad3eb597.

## Measurement before the fix (main, ad3eb597)

- Build: `build.cmd` (Debug x64) -> BUILD SUCCEEDED.
- Probe `probe/ftp345_probe.ps1` (a copy of 341's `ftp341_probe.ps1`): two `ftpmini_hide.py`
  servers on 127.0.0.1:2145 and :2146 serving ONE folder; the panel `u@127.0.0.1:2145`; the
  uploads typed per row. Run on the hidden desktop:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File ...\ftp345_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`
- Result `probe/result_main.txt`: **PASS 11, FAIL 5**, registry restored identical.
  - USER-REN (uploads as `v`): upload 2 `USER v / ... / STOR b.txt`, no LIST, no question; server
    `b.txt` = `LOCAL-B` (was `SRV-A`) - the item's data loss reproduced.
  - PORT-REN (uploads as `u` to :2146): the same.
  - ALL-REN (uploads as `v` to `localhost:2146`): the same.
  - SEED-USER / SEED-PORT (upload 2 of a new `n.txt` as `v` / to :2146, then F5 into the panel):
    `STOR n.txt` without the question, server `n.txt` = `UP3`.
  - Controls ALIAS-REN (341), SAME-REN, SEED-SAME: PASS.

## Sites (enumerated at HEAD)

`src/plugins/ftp/operats9.cpp`:
- `CUploadListingCache::InvalidateOtherNamesOfServer` - called by every `Report*` of the cache
  (`ReportCreateDirs`, `ReportRename`, `ReportDelete`, `ReportStoreFile`, `ReportFileUploaded`,
  `ReportUnknownChange`); invalidated only entries with the same user and port and another host.
- `CUploadListingCache::ChangedUnderOtherName` - called only by `AddOrUpdateListing` (the panel
  seed, `fs5.cpp`, and refreshes during an upload); counted only stamps with the same user and port.
- `FindServer` / `StampChange` - exact identity (host, user, port): unchanged, they must keep
  finding the entry / stamp of the identity itself.

## Decisions

See spec *Clarifications*: every other identity (host, user or port differs) is maybe the same
server - item *Expected* ("the uploads do not trust their cached listings ... they list the folder
again") and rule 098 (fail closed), as 341. The item's *Notes* middle way (only the same host)
would leave ALL-REN losing data, because 341 already treats any other host name as maybe the same
server. Cost: concurrent uploads under different identities list again after each other's changes.

## The fix (commit 2c54ae13)

`src/plugins/ftp/operats.h`, `src/plugins/ftp/operats9.cpp`:
- new static `CUploadListingCache::SameIdentity(entryUser, entryHost, entryPort, user, host, port)`
  - the one definition of "own" (host `StrICmp`, user exact with `anonymous` = no user, port);
  used by `FindServer`, `StampChange` (unchanged behaviour) and `ChangedUnderOtherName`;
- `InvalidateOtherNamesOfServer`: every entry except `exact` (the reported connection's own entry,
  the only one `FindServer` can return for it) invalidates all its listings - the same-user /
  same-port filter is gone;
- `ChangedUnderOtherName`: a stamp newer than the listing's start counts when its identity is not
  the listing's own (`!SameIdentity`) - before: only another host with the same user and port.
- No pure-rule header (research R4): the rule left is the three-field equality `FindServer` always
  used.

## Checks

- `build.cmd` (Debug x64) -> BUILD SUCCEEDED.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `saltests.exe` -> `saltests: 28952 checks, 0 failed`.
- The maintainer started the installed Tandem Commander during the run: the first after-run
  printed `NOT RUN: tandemcommander.exe already runs` (exit 3, nothing touched); the run waited
  until it exited (about 35 s) and ran the probes then.
- `probe/result_after.txt` (ftp345_probe.ps1 on the fix): **PASS 16, FAIL 0** (8 ROW + 8 END);
  USER-REN, PORT-REN, ALL-REN: upload 2 lists the folder again, no `STOR b.txt`, the overwrite
  question for `b.txt` open, server `b.txt` = `SRV-A`; SEED-USER / SEED-PORT: no second `STOR n.txt`,
  question open, server `n.txt` = `UP2`; controls PASS; registry restored identical.
- Negative control (SC-003): the same probe on `main` at ad3eb597 - the code without the fix -
  `probe/result_main.txt`: the five rows FAIL (STOR without the question), the controls PASS.
- Regression `probe/regress_341.txt` (341's `ftp341_probe.ps1`): PASS 12, FAIL 0.
- Regression `probe/regress_302.txt` (323's `ftp302_probe.ps1`): PASS 16, FAIL 0; registry restored identical in all three runs.
- Note on `probe/result_main.txt` (review 1, NOTE): it was produced on `main` by the probe while it
  still lived in the run's scratch folder (its banner reads `ftpup_probe`); the committed
  `ftp345_probe.ps1` differs only in that banner line and its location. T007's negative control is
  this measurement of the code without the fix (not a separate revert build); review 1 added two
  partial mutants (below).

## Review

### Review 1 (refute-first, independent agent) - MUST 0, SHOULD 1, NOTE 3

- Re-ran on the branch build: USER-REN, PORT-REN, SAME-REN, SEED-USER - PASS 8 / FAIL 0, registry
  identical (`probe/review1/result_head.txt`).
- Partial negative controls (own worktree and build folder, `ftp.spl` swapped into a copy of the
  tree): only `ChangedUnderOtherName` reverted -> SEED-USER, SEED-PORT FAIL (`STOR n.txt`, `UP3`),
  USER-REN PASS (`probe/review1/result_negseed.txt`); only `InvalidateOtherNamesOfServer` reverted
  -> USER-REN, PORT-REN FAIL (`STOR b.txt`, `LOCAL-B`), SEED-USER PASS
  (`probe/review1/result_neginv.txt`). Both halves are needed and the probe separates them.
- Callers enumerated (Report*: `ctrlcon5.cpp`, `fs3.cpp`, `operats3/4/8/a/b.cpp`;
  `AddOrUpdateListing`: `fs2.cpp` update-only and the panel seed `fs5.cpp`); upload workers' own
  listings go through `ListingFinished`, which ignores the stamps. `SameIdentity` = the old rule.
  The cache now trusts a strict subset of what it trusted on `main`: no new data-loss path.
- SHOULD (done): the cost was understated - an in-progress listing invalidated by another
  connection's change is thrown away and downloaded again with no limit
  (`InvalidateListing` -> `ulsInProgressButMayBeOutdated`, `ListingFinished` removes it), so an
  upload can wait for its listing of a large folder as long as another upload under another
  connection keeps storing files (a stall while it runs, not a hang; by reading). Spec
  *Clarifications* (cost) and *Edge Cases* now say so; the mitigation is the maintainer's choice ->
  Inbox decision item `ftp-two-uploads-under-different-connections-can-stall-each`.
- NOTE: `result_main.txt` banner - recorded above.
- NOTE: closing entries (CHANGELOG, FEATURE-HISTORY) were not yet written - done at closing.
- NOTE: old review worktrees of earlier features (`%TEMP%\rev325` ... `rev341r3`) are still
  registered in git - not this feature's; left alone.

No MUST: no second review needed (SKILL step 7). `git status` after the review: only this run's
files.
