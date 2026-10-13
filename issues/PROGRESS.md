# GitHub issues job - progress (working file of the agent)

Task (2026-10-13, the maintainer is away): fix `issue_3`, `issue_5`, `issue_6`, `issue_7`,
`issue_8` one by one. Each is its own Spec Kit flow (specify, plan, tasks, implement) on its own
branch, with independent tests and a report `issues/issue_X_report.md` (the text to paste into
the GitHub thread). Fixes go out in 0.1.10. Nothing is pushed or published.

How the work is organised

- Branches are stacked: `124-...` from `main`, each next one from the previous. Local commits
  only, messages `[NNN] ...`.
- Baseline for "before" measurements: `build\tandemcommander\Debug_x64_v019` (copy of the Debug
  tree of the 0.1.9 release commit, made 2026-10-13).
- Shared probe helper for owner-drawn text (capture + Windows text recognition):
  `specs/124-regedt-key-text/probe/shotocr_lib.ps1`.
- A session cron job re-enters the work every 30 minutes if the session went idle (usage limit).

| Issue | Feature | State |
|-------|---------|-------|
| #3 regedt KEY text | 124-regedt-key-text | **done** - committed on the branch, report `issues/issue_3_report.md` |
| #5 `\\server\` | 125-unc-server-shares | **done** - core fallback (share list), plug-in policy untouched and recorded in NEXT-WORK section D; report `issues/issue_5_report.md` |
| #6 Windows 7 start | 126-package-api-late-bind | **done** - the two functions resolved at run time; report `issues/issue_6_report.md` |
| #7 mixed templates | 127-mixed-template-texts | **done** - about 45 places + Registry Editor + guard; report `issues/issue_7_report.md` |
| #8 shortcuts | 128-shortcut-target-unicode | **done** - Enter and Go to Shortcut Target read the target wide; report `issues/issue_8_report.md` (Czech) |

## Finished 2026-10-13

All five issues are done; each is one local commit on its own branch, stacked
`124` -> `125` -> `126` -> `127` -> `128` (the last branch holds everything). Nothing is pushed,
merged or released. What is left for the maintainer is in `specs/NEXT-WORK.md`, section D
(decisions and steps owed to a person), and in each report under `issues/`.

## Second verification 2026-10-13 (asked for by the maintainer)

Clean rebuilds (Debug, Release), every probe again on the fixed build and on 0.1.9, five
independent refute-first agents with tests of their own, a review of the follow-up fixes. No
blocker. Follow-up fixes are one more commit on `128-shortcut-target-unicode`:

- 124: Copy Name / Full Name / Path of the Registry Editor (clipboard as Unicode), the Find
  window's size cell;
- 125: unusable share names, a refused list reported, an end for an endless list;
- 127: five more places in the core (viewer, regular expressions, variables, all messages of
  the external archivers, Ctrl+C in a message box), `src/common/salinserts.h`;
- answers `issue_3/5/7/8_report.md` corrected where they claimed too much; new items in
  `specs/NEXT-WORK.md` section D.

Final numbers: saltests 18,395 / 0 failed; guard 0; probes on the final build - 124: 81 / 0;
125: 26 / 0 (1 not driven); 127 Czech 19 / 0, English 17 / 0 (clipboard rows not driven);
128: 18 / 0; 126: 5 / 5 and no import in 218 files. Rows for the visible desktop exist but the
workstation was locked - owed to a person.

## Feature 129 (2026-10-13, asked for by the maintainer after the verification)

`129-regedt-wide-inserts`, one local commit on top of `128`: the Registry Editor's empty
"create the target key?" question, the cut key errors and the shared cache file of viewed
values (names with a letter above U+00FF). Probe: 0.1.9 FAIL 4, fixed PASS 19 (Czech and
English); saltests 18,447; an independent review refuted the first version (lower case by a
byte table on UTF-8) - fixed. Record: `specs/129-regedt-wide-inserts/fix-log.md`.

## Feature 130 (2026-10-13, asked for by the maintainer)

`130-plugin-mixed-templates`, on top of `129`: the defect of issue #7 in the plug-ins. Thirteen
plug-ins changed (about 115 sites), a shared helper, the core's progress dialog title. Probe:
0.1.9 Czech FAIL 4 and Slovak FAIL 2, fixed 19 / 0 and 4 / 0, English identical; saltests
18,471; regressions 127, 117, 113 clean. Two independent reviews: one regression found in SFTP
(download error with a non-UTF-8 remote name) and fixed. **FTP is left** as its own step
(`specs/130-plugin-mixed-templates/triage/ftp.md`). Record:
`specs/130-plugin-mixed-templates/fix-log.md`.

## Feature 131 (2026-10-13, asked for by the maintainer)

`131-plugin-defect-batch`, on top of `130`: the defects 130 saw on the way, each measured first.
Fixed: an FTP crash on a host name with `%` (0.1.9 crashes in the probe), a ZIP favourite lost
at a long name, SFTP operations on cut paths and its missing error reasons, PictView *Update
Thumbnail* on accented paths, and about fifteen smaller ones in eleven plug-ins and the core;
two translation errors. Several notes were not defects (recorded). Three independent reviews,
no blocker. Record: `specs/131-plugin-defect-batch/fix-log.md`.

## Feature 132 (2026-10-13, asked for by the maintainer: point 1 of four)

`132-pictview-thumbnail-verify`, on top of `131`. The suspected loss in PictView's *Update
Thumbnail* was real in the Exif library and unreachable in the program (the command was dead
since 006). The command is repaired and protected by a rule checked independently of the
library. Record: `specs/132-pictview-thumbnail-verify/fix-log.md`.

## Feature 133 (2026-10-13, asked for by the maintainer: point 2 of four)

`133-sftp-server-verify`, on top of `132`. The SFTP plug-in driven in the program against the
test container: the fixes of 131 hold; a listing that ended with an error was taken for the
whole directory (fixed); a move loses nothing (the recommendation's worry was wrong) but leaves
a moved directory on the server (recorded). Record: `specs/133-sftp-server-verify/fix-log.md`.

## Release preparation and feature 134 (2026-10-13, points 3 and 4 of four)

- `release-0.1.10`: the tree prepared for 0.1.10 (build 194, features 124-133); tag, build and
  publication are the maintainer's, after the person steps in `specs/NEXT-WORK.md`.
- `134-ftp-mixed-templates`, on top of it (for the version after): the FTP client's part of
  GitHub #7 - messages, operation window and the log; measured before and after against the
  probe's own FTP server. Record: `specs/134-ftp-mixed-templates/fix-log.md`.

## Feature 135 (2026-10-13, "fix what you can", the first critical point)

`135-pictview-real-photos`: Update Thumbnail measured on 91 real camera files - the Exif code
of 132 damaged the maker's data in 30 of 82. The thumbnail is now swapped without moving a byte
of the Exif block; 82 of 82 keep everything. **Must ship with 132.** Record:
`specs/135-pictview-real-photos/fix-log.md`.

## Feature 136 (2026-10-13)

`136-ftp-verify-rows`: five more rows of the FTP probe (bookmarks, password prompt, login
error, saved log). 31 / 0 in Czech and English on the final build; nothing to fix.

## Feature 137 (2026-10-13)

`137-names-cut-at-byte`: Quick Rename on a server (dialog and in-place line) refuses a name
that does not fit instead of sending a cut one; FTP's automatic rename cuts at a whole letter.
Record: `specs/137-names-cut-at-byte/fix-log.md`.

## Feature 138 (2026-10-13)

`138-sftp-move-directory`: a moved directory leaves the SFTP server; nothing is removed that
did not arrive whole (size confirmed), and two server names that are one Windows name are not
merged. Record: `specs/138-sftp-move-directory/fix-log.md`.

## Feature 139 (2026-10-13)

`139-sftp-no-silent-overwrite`: from the final independent review - an SFTP upload asks before
it replaces a server file and replaces it only by a complete new one; a download over a local
file goes through a temporary file; Quick Rename refuses an existing name; a move to the server
removes each local source only after its own upload is confirmed. Record:
`specs/139-sftp-no-silent-overwrite/fix-log.md`.

## Feature 140 (2026-10-14)

`140-sftp-dead-session`: a timed-out SFTP request ends the operation (the library would answer
the next request with the late reply); devices, FIFOs and sockets are not downloaded; refused
attribute and owner changes are reported. Record: `specs/140-sftp-dead-session/fix-log.md`.

## Feature 141 (2026-10-14)

`141-mask-name-cut`: names long in UTF-8 (up to 255 letters of any script) are copied, moved
and renamed whole; a name that does not fit is refused, never cut; FTP's automatic rename on
upload cuts at a whole letter. Record: `specs/141-mask-name-cut/fix-log.md`.

## Feature 142 (2026-10-14)

`142-pictview-thumb-unicode`: PictView's Update Thumbnail and Exif information work for names
outside the system code page and for long paths (wide exports in EXIF.DLL); failures offer
Skip / Skip all / Cancel; `PRIVACY.md` names the temporary file. Record:
`specs/142-pictview-thumb-unicode/fix-log.md`.
