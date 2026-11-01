# Closing report - 385-ftp-path-name-rule
Backlog item: ftp-server-path-compare-code-page-fold - FTP: server folder names compared by the code-page case rule on UTF-8 bytes
Outcome: closed

## What changed

- `src/common/salftpsrvpath.h` (new, header-only): `SalFtpServerPathIsPrefix` - server paths of
  the case-insensitive path types walked separator by separator and name by name, each name
  compared by the file system's rule of feature 092 (`SalNameOrderEqualCI`); byte counts never
  compared across the two paths; the old trailing-separator, root, `[000000` and VMS escape rules
  kept; Unix / unknown types byte-exact as before.
- `src/plugins/ftp/ftputils.cpp`: `FTPIsPrefixOfServerPath` maps the server path type to the
  header's kind and calls it (behind `FTPIsTheSameServerPath`, `FTPIsTheSamePath`; 22 callers
  unchanged). AS/400 included (case-insensitive too).
- `src/saltests/saltests.cpp`: `TestFtpServerPath385`.
- Probe `specs/385-ftp-path-name-rule/probe/ftp385_probe.ps1` + `ftpmini385.py` (SYST from
  `FTPMINI_SYST`).

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\385-ftp-path-name-rule\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\385-ftp-path-name-rule\probe\ftp385_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe"`

- before (main 6428f7e9): PASS 5, FAIL 1 - CROSS: upload into `/CROSS/Ĝ` while an upload into
  `/CROSS/Č` was open sent `STOR x.txt` without the question, the server file replaced (data loss);
  CASE: the cache missed `/CASE/čaj` (listed again).
- after: PASS 6, FAIL 0 - CROSS lists `/CROSS/Ĝ` and asks, the file intact; CASE uses the cache.
- Reviewer's negative control (old plug-in built from 8bd858ba): 5 / 1, the same CROSS failure.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED.
- saltests: 30,586 checks, 0 failed (ASCII equivalence with the old rule: 0 differences over
  1.2 M - 4.9 M pairs per kind; 38 non-ASCII rows; the old rule fails exactly the 22 marked rows on
  code page 1250).
- Probes: 385 6 / 0; regressions 215 12 / 0, 224 16 / 0, 233 3 / 3 (DLT / DLC / UPT, as recorded
  in 233 and 277), 277 10 / 0. These four use a UNIX-type server and do not reach the changed kinds.
- No UI strings changed: no `.slt` refresh.

## Reviews (findings and what was done)

Review 1: no MUST. SHOULD 1 (regression probes do not reach the changed kinds) - stated in the
fix-log. SHOULD 2 (VMS / AS/400 case rule unknown) - spec *Assumptions*, accepted. NOTE 3 - Inbox
item. NOTE 4 - recorded. NOTE 5 - header formatted, rebuilt, saltests 30,586 / 0. NOTE 6 - the
records say data loss.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below. `CHANGELOG.md` has no `## [Unreleased]` section, and versions are
  the maintainer's.

## CHANGELOG entry (to be added by a person - `CHANGELOG.md` has no `## [Unreleased]` section)

- **FTP: an upload into one server folder could replace a file without asking because another
  folder's listing was used** (feature 385). On a server with case-insensitive paths (Windows,
  NetWare, OS/2, VMS, MVS, z/VM, Tandem, AS/400), folder names with letters outside ASCII were
  compared by a code-page byte table: on code page 1250 the folders `Č` and `Ĝ` counted as one, so
  an upload into `/Ĝ` while an upload into `/Č` was still open could store over an existing file
  without the overwrite question; `Č` and `č` counted as two folders. Folder names are now compared
  the way Windows compares file names; ASCII names behave as before. Not verified on a real VMS or
  AS/400 server.

## New Inbox items (slug - title)

- ftp-upload-listing-cache-lookup-remembers-a-slot-number - FTP: upload listing cache lookup
  remembers a slot number instead of the listing index
