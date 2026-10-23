# Closing report - 323-ftp-upload-cache-args
Backlog item: ftp-panel-mkdir-rename-skip-upload-listing-cache - FTP: Create Directory and Quick Rename in a panel never update the upload listing cache
Outcome: closed

## What changed

Continues the stopped feature 302 (`origin/302-ftp-upload-cache-args`, carried over three-way).

- `src/plugins/ftp/ctrlcon5.cpp` (302): the panel's Create Directory and Quick Rename report to the
  upload listing cache with `(user, host, port)` - before, host and user were swapped and every
  report was dropped.
- `src/plugins/ftp/operats9.cpp`, `operats.h` (302 review 1): a reported Quick Rename or unknown
  change (Send FTP Command) invalidates every cached listing of the server.
- `src/plugins/ftp/operats9.cpp`, `operats.h` (this run, 302 review 2 MUST): `ReportCreateDirs`
  records only the last named component of a created path as a new, empty folder; an earlier one
  that its cached parent listing does not show as a folder (or a listing still being received)
  invalidates that listing (`ReportCreateDirComponent`); empty components are skipped.
- `src/common/salftpmkdirreport.h` (new, header-only pure rule) and `saltests`
  (`TestFtpMkdirReport323`).
- Probe `probe/ftp302_probe.ps1` with 8 rows, server `probe/ftpmini_hide.py`.
- `CHANGELOG.md` (0.1.11 unreleased), `specs/FEATURE-HISTORY.md`.

The user-visible effect: an FTP upload no longer replaces a file just renamed in the FTP panel
without the overwrite question (measured data loss on `main`), a folder made by F7 is joined, and
a folder created with a path never hides the existing folders on its way.

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\323-ftp-upload-cache-args\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\323-ftp-upload-cache-args\probe\ftp302_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`

| Code | File | Rows |
|---|---|---|
| `main` 4c33e2fc | `result_main.txt` | 10 / 2 - MKD-ABS (`MKD new`, 550), REN-UP (`b.txt` = `LOCAL-B`, no question) |
| 302's state | `result_302state.txt` | 10 / 2 - MKD-HID, MKD-CASE (`f.txt` overwritten, no question) |
| this feature | `result_after.txt` | 16 / 0 (with the review's MKD-HIDABS, MKD-UPHID) |

Reviewer's mutant (absolute branch as in 302): MKD-HIDABS fails (`probe/review323/rv_mut.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- `.\build.cmd` -> `BUILD SUCCEEDED`
- `saltests.exe` -> `saltests: 27793 checks, 0 failed`
- `ftp302_probe.ps1` 16 / 0; regression `ftp288_probe.ps1` 20 / 0 (`probe/regress_288.txt`);
  registry restored + identical in every run
- No UI text changed - no `.slt` refresh.

## Reviews (findings and what was done)

302 (record in `fix-log-302.md`): review 1 MUST (rename into an F7 folder) fixed by 302; review 2
MUST (Create Directory with a path) fixed here. Review 1 of 323: no MUST; SHOULD S1 (no probe row
for the absolute branch) fixed - rows MKD-HIDABS, MKD-UPHID; NOTEs N1-N4 recorded in `fix-log.md`.

## Owed to a person (with the new person-step items)

- `ftp-323-by-hand-send-ftp-command-during-an-open-upload-then` - Send FTP Command into an F7
  folder while an upload is open, then an upload asks before overwriting (the probe cannot reach
  the menu command).

## New Inbox items (slug - title)

- `ftp-323-by-hand-send-ftp-command-during-an-open-upload-then` - FTP 323 by hand: Send FTP
  Command during an open upload, then an upload asks before overwriting
- `ftp-an-upload-to-a-server-named-another-way-localhost-vs-127` - FTP: an upload to a server
  named another way (localhost vs 127.0.0.1) misses the panel changes
