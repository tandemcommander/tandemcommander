# Closing report - 410-ftp-alias-refresh
Backlog item: ftp-panel-refresh-misses-change-under-another-name - FTP: a panel is not refreshed after a change made under another name of its server
Outcome: closed

## What changed

- `src/common/salftproot.h` (new, header-only): `SalFtpSameUser`, `SalFtpSamePortText`,
  `SalFtpRootMatchOf` - same root / same user and port under another host (maybe the same server,
  feature 341) / other.
- `src/plugins/ftp/ftputils.cpp/.h`: `FTPRootPathMatch` splits two user-part roots (passwords zeroed)
  and applies the rule; `FTPHasTheSameRootPath` = `== SAL_FTP_ROOT_SAME` (caller `IsOurPath` unchanged
  in effect).
- `src/plugins/ftp/fs3.cpp` `CPluginFSInterface::AcceptChangeOnPathNotification`: a panel of another
  host with the same user and port is refreshed by the same path rule and timing while its connection
  is open (a closed one is not reconnected - review 1); for every other-host FS the notified path's
  viewed files are dropped under its own name (`ftp:` / `ftps:`; a name that does not fit is skipped).
- `src/plugins/ftp/ctrlcon4.cpp` `CListingCache::AcceptChangeOnPathNotification`: the host is no
  longer compared (same user and port).
- `src/saltests/saltests.cpp`: `TestFtpRootMatch410` (24 checks).

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\410-ftp-alias-refresh\probe\<result>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\410-ftp-alias-refresh\probe\ftp410_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`

| Row | 2ce004b9 (`main`) | after |
|---|---|---|
| REFRESH-ALIAS (the item) | FAIL - the panel's connection sends nothing | PASS - it lists the folder again |
| REFRESH-SAME / REFRESH-ELSE | PASS / PASS | PASS / PASS |
| CACHE-ALIAS | FAIL - stale cached listing | PASS |
| CACHE-SAME | PASS | PASS |
| VIEW-ALIAS (finding) | FAIL - stale viewed copy | PASS |
| VIEW-SAME | PASS | PASS |
| REFRESH-CLOSED (review 1) | FAIL on the review-1 build - reconnect question, new login | PASS |

Totals: `main` 11 / 3 (`probe/result_main.txt`, `probe/result_main_view.txt`) -> 16 / 0
(`probe/result_after.txt`). Negative controls: mutant A (`fs3.cpp` old rule) fails REFRESH-ALIAS and
VIEW-ALIAS, mutant B (`ctrlcon4.cpp` host compared) fails CACHE-ALIAS (`probe/result_negative_*.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- `.\build.cmd` -> `BUILD SUCCEEDED` (last code change: the review-1 commit; review 2 changed documents only)
- `saltests.exe` -> `saltests: 282637 checks, 0 failed`
- `ftp410_probe.ps1` 16 / 0; 341's `ftp341_probe.ps1` 12 / 0 (`probe/regress_341.txt`); registry
  restored and identical after every run
- no UI strings, dialogs or menus changed: no `.slt` refresh needed

## Reviews (findings and what was done)

- Review 1: MUST 0, SHOULD 1 (closed connection of another host -> reconnect question / login) fixed
  with row REFRESH-CLOSED; NOTE 2 (redundant `NextRefreshWontClearCache` change) reverted; NOTE 3
  (SC-004 claim) corrected; NOTES 4, 6, 7 documented; NOTE 5 done at the close.
- Review 2: MUST 0, SHOULD 0, NOTE 4 - documents corrected (NOTE 1), limits documented (NOTES 2-4).

## Owed to a person (the lines added to the release checklist)

None - every row was driven on the hidden desktop.

CHANGELOG entry (no `## [Unreleased]` section exists in `CHANGELOG.md`; versions are the
maintainer's) - to be added when that section is opened:

```text
- **An FTP panel did not show a change made through another name of its server** (feature 410).
  - **Before:** after an upload, rename or delete through one name of a server (`localhost`), a panel showing the same folder through another name (`127.0.0.1`) with the same user and port kept the old listing until Ctrl+R; a folder visited earlier was shown from the listing cache and a file viewed earlier showed its old copy.
  - **Now:** such a panel is listed again, and the cached listings and viewed files of the changed folder are dropped under every name with the same user and port. A panel whose connection has already closed is not reconnected for it; it lists the folder again at its next refresh.
  - **Limitation:** another user or another port of the same server is not treated as the same server here; a panel at a parent folder of the changed one is not refreshed.
```

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- Viewed files cached under another name (severity 4): viewing a file again after a change through
  another name showed the old copy (row VIEW-ALIAS FAIL -> PASS).

## New Inbox items (slug - title)

None.
