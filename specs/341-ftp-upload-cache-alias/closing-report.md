# Closing report - 341-ftp-upload-cache-alias

Backlog item: ftp-an-upload-to-a-server-named-another-way-localhost-vs-127 - FTP: an upload to a server named another way (localhost vs 127.0.0.1) misses the panel changes
Outcome: closed

Started by the backlog loop (run of 2026-10-24 12:50); the run failed after its third reviewer was
killed three times by `claude -p`'s 10-minute background-task ceiling; finished in a maintainer
session the same day (review 3, closing, merge of `main`).

## What changed

- `src/plugins/ftp/operats9.cpp`, `operats.h`: every change report of the upload listing cache
  (`ReportCreateDirs`, `ReportRename`, `ReportDelete`, `ReportStoreFile`, `ReportFileUploaded`,
  `ReportUnknownChange`) calls `InvalidateOtherNamesOfServer`: every cached server entry with the
  same user (anonymous normalised) and port under another host name invalidates all its listings
  (the running upload lists the folder again before an existence check), and the change is stamped
  (`StampChange`, `ChangeStamps`).
- `AddOrUpdateListing` (the panel's listing seeded into an upload into the panel) refuses a listing
  that started before a change stamped under another host name (`ChangedUnderOtherName`); past
  1,000 stamped names or on low memory every such listing is refused (`ChangeStampsLost`, fails
  closed).
- No name lookup, no new network traffic, nothing stored.

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log <file> -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\341-ftp-upload-cache-alias\probe\ftp341_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`

- `main` (3034d82f), `probe/result_main.txt`: PASS 4, FAIL 2 - ALIAS-REN (upload 1 to `localhost`
  held, Quick Rename `a.txt` -> `b.txt` in the panel at 127.0.0.1, upload 2 sent `STOR b.txt`, the
  server's `b.txt` = LOCAL-B, no question) and ALIAS-UP (a store through 127.0.0.1, then an upload
  via localhost replaced it without the question).
- After, `probe/result_after.txt`: PASS 12, FAIL 0 (ALIAS-REN, ALIAS-UP, SAME-REN, MULTI-REN,
  SEED-ALIAS, SEED-SAME; ROW and END). ALIAS-REN now: `CWD /ALIAS-REN / PORT ... / TYPE A / LIST`,
  the question for `b.txt` open, server `b.txt` = SRV-A.

## Checks (encoding guard, build, saltests, probes - with numbers)

See `fix-log.md` *Checks (after review 2, final code)* and *After merging main*: encoding guard
`TOTAL: 0`; build succeeded; saltests 0 failed; probe 12 / 0; mutants - fan-out off: ALIAS-REN,
ALIAS-UP, MULTI-REN, SEED-ALIAS FAIL (`result_negative.txt`), stamps off: SEED-ALIAS FAIL
(`result_negative_seed.txt`); regression 323's `ftp302_probe.ps1` 16 / 0 (`regress_302.txt`);
review 3's own rows INFLIGHT-ALIAS / INFLIGHT-SAME 4 / 0 (`probe/review3/inflight_result.txt`).

## Reviews (findings and what was done)

- Review 1: MUST - known disjoint addresses do not prove two servers (one server on 127.0.0.1 and
  127.0.0.2); the address-recording design was removed, every other host of the same user and port
  is taken as maybe the same server. SHOULD - severity raised to 7.
- Review 2: MUST - the panel's listing seeded after the fan-out brought the stale listing back; the
  change stamps were added. NOTEs -> two Inbox items.
- Review 3 (three attempts killed by the session limit, the fourth finished): no MUST, no SHOULD;
  a new in-flight STOR probe passes (the store is stamped before it is sent); NOTEs on races that
  exist with one name too, lock order, the bound, memory paths.

## Owed to a person (with the new person-step items)

- nothing (every row was driven on the hidden desktop).

## New Inbox items (slug - title)

- `ftp-opened-file-lock-two-names-of-one-server` - FTP: two operations under two names of one server can open one file at the same time
- `ftp-panel-refresh-misses-change-under-another-name` - FTP: a panel is not refreshed after a change made under another name of its server
- `ftp-upload-cache-other-user-or-port-of-one-server` - FTP: an upload as another user or on another port of one server misses the panel changes
