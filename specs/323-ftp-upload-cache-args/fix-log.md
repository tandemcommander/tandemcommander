# Fix log - 323-ftp-upload-cache-args

Backlog item `ftp-panel-mkdir-rename-skip-upload-listing-cache` - FTP: Create Directory and Quick
Rename in a panel never update the upload listing cache. Run started from `main` at 4c33e2fc.
Continues the stopped feature 302 (`origin/302-ftp-upload-cache-args`, stopped by its review 2
MUST); its record is `fix-log-302.md`, its probe results `probe/run302/`, review 2's reproduction
`probe/review2/`.

## Measurement at HEAD (4c33e2fc), by reading

- `src/plugins/ftp/ctrlcon5.cpp` (`CControlConnectionSocket::CreateDir`, `::QuickRename`): the four
  calls still pass `(hostBuf, userBuffer, portBuf, ...)` against the declared `(user, host, port,
  ...)`. `ctrlcon5.cpp` is unchanged since 02eba55f, where 302's probe measured the data loss
  (REN-UP: the renamed `b.txt` replaced by an upload without the question; MKD-ABS: `MKD` sent for
  an existing folder) - `probe/run302/result_before.txt`.
- `main` changed `operats9.cpp` / `operats.h` since 02eba55f only in `GetListing` (feature 303,
  case-only file names); `ReportCreateDirs` / `ReportRename` / `ReportUnknownChange` unchanged.
- `BL verify` recorded at 4c33e2fc.

## Carry-over (SKILL.md 4.6)

`git diff $(git merge-base main origin/302-ftp-upload-cache-args) origin/302-ftp-upload-cache-args`
without backlog / specs / feature.json / translations, `git apply -3`: applied cleanly
(`ctrlcon5.cpp`, `operats.h`, `operats9.cpp`; CRLF kept). Commit `[323] carry over the work of
302-ftp-upload-cache-args`. Carried: the argument order of the four calls; `ReportRename` /
`ReportUnknownChange` -> `InvalidateAllListings()` (302 review 1). Build of that state:
`.\build.cmd` -> `BUILD SUCCEEDED`.

## This run: 302 review 2 MUST (Create Directory with a path)

Finding (302 review 2, `fix-log-302.md`): `CUploadListingsOnServer::ReportCreateDirs` recorded
every component a cached parent listing did not show as created - inserted into the listing and
given an empty, ready listing. `MKD .cfg/new` succeeds because `.cfg` exists; a plain `LIST` hides
it (vsftpd / Pure-FTPd / ProFTPD), and on a case-insensitive server `docs/new` goes into `Docs`.
An upload of `f.txt` into `.cfg/` (or `docs/`) then trusted "empty" and sent `STOR` without a
`LIST` and without the question.

Fix:

- `src/common/salftpmkdirreport.h` (new, header-only, pure): `SalFtpMkdirIsNamedComponent` (not
  NULL / empty / `.` / `..`) and `SalFtpMkdirComponentAction(unknownResult, isLastNamed,
  parentListsIt)` -> invalidate (unknown result; an earlier component the listing does not show) /
  record as created (the last named component - the existing handling) / nothing (an earlier
  component the listing shows).
- `operats9.cpp`: `ReportCreateDirs` - the relative branch counts the named components of a copy
  of `newDirs` first and skips empty components (they create nothing; before, an empty component
  went through `ReportCreateDir("")`); the absolute branch cuts from the end, so the first named
  component is the last one. Each component at a cached parent listing goes through the new
  `ReportCreateDirComponent`: "the parent listing shows it" = the listing is ready (or holds a
  newer received listing, `ulsInProgressButObsolete` - the states in which `ReportCreateDir` reads
  items) and holds the name as a directory or link (a file of that name cannot have held the new
  folder); a listing still being received cannot tell -> invalidated.
- `operats.h`: declaration of `ReportCreateDirComponent`; the comment of
  `CUploadListingCache::ReportCreateDirs`.
- Callers of `CUploadListingCache::ReportCreateDirs` (Grep): `ctrlcon5.cpp` (panel, 2), the upload
  workers `operatsa.cpp` (4) and `operats3.cpp` (2) - always one name (the target folder's name or
  its auto-renamed name), so it is the last named component: unchanged handling.
- `saltests`: `TestFtpMkdirReport323` (every row of the decision table, the named-component cases).

## Probe

`probe/ftp302_probe.ps1` = 302 review 2's `ftp302_rv.ps1` (rows MKD-ABS, REN-UP, MKD-REN,
REN-PATH, MKD-HID, MKD-CASE) with the 098 library by a relative path; the server is
`probe/ftpmini_hide.py` (215's `ftpmini.py` that omits dot names from a plain `LIST`) for all rows
(the other rows have no dot names). Command (PowerShell, repository root):

    powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\323-ftp-upload-cache-args\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\323-ftp-upload-cache-args\probe\ftp302_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"

## Analyze

- Round 1: no CRITICAL / HIGH. C1 (MEDIUM): the "result unknown" reports (the connection closed
  during MKD / RNTO) are not driven by the probe - accepted: the unknown-result branch of
  `ReportCreateDirs` is unchanged (every reached listing invalidated) and the argument order is the
  same change as in the driven calls; checked by reading. C2, T1 (LOW): covered by the 288
  regression probe; the probe keeps its 302 name for continuity.

## Probe runs (`ftp302_probe.ps1`, six rows + END rows)

| Code | File | MKD-ABS | REN-UP | MKD-REN | REN-PATH | MKD-HID | MKD-CASE | Rows |
|---|---|---|---|---|---|---|---|---|
| `main` 4c33e2fc (`git checkout main -- src/plugins/ftp`, rebuilt) | `result_main.txt` | FAIL (`MKD new`, 550) | FAIL (`b.txt` = `LOCAL-B`, no question) | PASS | PASS | PASS | PASS | 10 / 2 |
| 302's state (carried over, before this run's change) | `result_302state.txt` | PASS | PASS | PASS | PASS | FAIL (`STOR f.txt`, `.cfg/f.txt` = `LOCAL-F`) | FAIL (`Docs/f.txt` = `LOCAL-F`) | 10 / 2 |
| this feature | `result_after.txt` | PASS | PASS | PASS | PASS | PASS (`CWD /MKD-HID/.cfg / PORT / LIST`, question open) | PASS (`LIST`, question open) | 12 / 0 |

Every ROW fails on exactly one of the earlier versions - each is a negative control. The `main` run
is the item's measurement at HEAD: the data loss reproduces at 4c33e2fc. END rows PASS in all runs
(exit 0, no reports, the expected exit question about unfinished operations). Registry restored and
identical in every run (SHA-256 CF14BE9E...). After the `main` run the sources were restored with
`git checkout HEAD -- src/plugins/ftp` and rebuilt (`BUILD SUCCEEDED`).

## Checks

- Build: `.\build.cmd` -> `BUILD SUCCEEDED` (`ftp.spl`, `saltests`); no new warnings in the touched
  files (the C4267 lines are `fs2.cpp` / `parser2.cpp`, untouched).
- saltests: `saltests: 27793 checks, 0 failed` (with `TestFtpMkdirReport323`).
- Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- clang-format: the touched lines are formatted (the remaining differences in `operats9.cpp` are
  feature 303's lambda, in `operats.h` older lines).
- Regression: `ftp288_probe.ps1` on the fixed build -> `probe/regress_288.txt` PASS 20, FAIL 0.
- Translations: no UI string, menu or dialog changed - no `.slt` refresh.

## Review

### Review 1 of 323 (refute-first, independent agent) - MUST 0, SHOULD 1, NOTEs 4

- Re-ran: build up to date, saltests 27793 / 0, encoding guard 0, `ftp302_probe.ps1` 12 / 0.
  Own rows (copy under `%TEMP%`): RV-HIDABS (F7 `/RV-HIDABS/.cfg/new`, absolute) and RV-UPHID
  (panel at `src`, F7 `../.cfg/new`, parent cached) PASS 4 / 0 on the branch. Negative control:
  a worktree of HEAD with the absolute branch passing `TRUE` instead of `lastNamed` (302's
  behaviour) - RV-HIDABS FAILS (`STOR f.txt`, `.cfg/f.txt` = `LOCAL-F`). Kept as
  `probe/review323/rv_head.txt`, `rv_mut.txt`.
- Callers enumerated by the reviewer: `ReportCreateDirs` (panel 2, workers `operatsa.cpp` 4 /
  `operats3.cpp` 2 - single names), `ReportRename` (panel 2), `ReportUnknownChange` (Send FTP
  Command, `fs3.cpp` 2); no other `MKD` / `RNFR` sender; `InvalidateAllListings` from the end is
  safe.
- **SHOULD S1 - fixed**: the absolute branch had no distinguishing probe row. Rows MKD-HIDABS and
  MKD-UPHID (the reviewer's) added to `ftp302_probe.ps1`; full run `result_after.txt` PASS 16,
  FAIL 0, registry restored + identical. The reviewer's mutant shows MKD-HIDABS fails without the
  absolute-branch change.
- NOTE N1: the safety comes from not recording an earlier component as new and empty; the parent
  invalidation is an extra re-list (harmless, helps an outdated parent listing) that no row
  distinguishes - accepted (conservative, costs one `LIST`).
- NOTE N2: the panel's Create Directory now relies on the old assumption that the last component
  of a successful `MKD` is new and empty (a server answering success for an existing folder would
  break it; the upload workers already rely on it; not reproducible with the test server) - no
  action.
- NOTE N3: "result unknown" reports and Send FTP Command are not driven (spec C1 / Assumptions);
  the reviewer's reading agrees. Send FTP Command -> person-step item
  `ftp-323-by-hand-send-ftp-command-during-an-open-upload-then`.
- NOTE N4: `a/../new`, `~/x/new` invalidate the parent instead of recording `a` / `~`; empty
  components are skipped instead of `ReportCreateDir("")`.
- Tree left clean by the reviewer.

## Owed to a person / Inbox

- `ftp-323-by-hand-send-ftp-command-during-an-open-upload-then` (person-step): Send FTP Command
  into an F7 folder while an upload is open.
- `ftp-an-upload-to-a-server-named-another-way-localhost-vs-127` (bug, review:302 NOTE, by
  reading): the cache is keyed by the host as typed.
