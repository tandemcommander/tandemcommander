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
