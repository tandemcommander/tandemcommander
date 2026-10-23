# Closing report - 326-uniso-rrip-without-rr
Backlog item: iso-plug-in-rock-ridge-names-of-xorriso-images-are-not-read - ISO plug-in: Rock Ridge names of xorriso images are not read, the ISO 9660 names are listed
Outcome: closed

## What changed

- `src/common/salsusp.h` (new, header-only, saltests `TestSusp326`): the System Use area of a
  directory record, the SUSP `SP` entry, where a record's Rock Ridge entries start (`RR` first as
  before; on a volume with `SP` from its LEN_SKP), and `SalSuspCleanRockRidgeName` (feature 087's
  rule for one name component).
- `src/plugins/uniso/iso9660.cpp/.h`: `Open` recognises SUSP by the root `.` record's `SP`;
  `ExtractExtFileName` reads `NM` names of such volumes; a Rock Ridge file name keeps its `;`;
  `MakeListedName` converts a name to UTF-8 and then makes a Rock Ridge name safe (falls back to the
  plain ISO 9660 name if the cleaning cannot hold it); `ListDirectory` first runs a fit check pass
  (the core's `sallistingname.h` rule, quiet, adds nothing) and lists a volume whose Rock Ridge names
  the listing would refuse as before this feature.
- `src/plugins/uniso/uniso.cpp` `ListArchive`: built with `SALDIRFLAG_CASESENSITIVE`, kept only when
  `SalDirTreeHasCaseTwins` finds names differing only in case (feature 252's rule, as TAR).
- `CHANGELOG.md` entry under 0.1.11 — unreleased.

## Measurements (before / after, commands)

- `specs/326-uniso-rrip-without-rr/probe/iso326_probe.ps1` (seeds: `probe/mkimg326.sh`, xorriso
  1.5.6 in WSL) through `tools\run_on_hidden_desktop.ps1`:
  - main's binary: PASS 13, FAIL 5 (`result_before.txt`) - RR `TOP.TXT`, OLDRR `TOP.TXT`, RR-DIR
    `FOLDER\NOTE.TXT`, RR-LONG 31 letters, SEMI `SEMI_COLON.TXT`;
  - the rows added after review 1 on the pre-fix branch build: PASS 24, FAIL 4
    (`result_review1_before.txt`) - ESC written outside the target, COLON into a stream, TDOT,
    DEV as they were; DEEP "Error" at the open with the folder lost;
  - final: **PASS 28, FAIL 0** (`result_after_review2.txt`).
- `probe/twins326_probe.ps1` (feature 252's probe with an ISO kind, `probe/mkiso326.sh`): before the
  fix PASS 5, FAIL 3 (`result_twins_before.txt`); after **8 / 0** (`result_twins_after.txt`).
- Feature 322's probe on the final build: **18 / 0** (`result_322_after.txt`).
- Root record dump (scratch Python): xorriso's `.` record `SP PX TF CE`, `ER RRIP_1991A` in the
  continuation area, no `RR` entry even with `-compliance old_rr`.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> BUILD SUCCEEDED (one pre-existing warning C4267 in `AddFileDir`).
- `saltests.exe` -> `saltests: 27937 checks, 0 failed` (TestSusp326: 53 checks); mutants of the
  rule (no-rr, no-check, no-skip, no-pad, no-backslash, no-device, no-trail) each fail 1-5 checks.
- Probes: iso326 28 / 0, twins326 8 / 0, iso322 18 / 0; registry restored identical every run.
- No UI string, dialog or menu changed: no `.slt` refresh, `build.cmd full` not needed.

## Reviews (findings and what was done)

- Review 1: MUST M1 (Rock Ridge names uncleaned: `..\escape.txt` written outside the target,
  `12:30.txt` into a stream) - fixed; N2 led to the DEEP measurement (a deep Rock Ridge tree ended
  the listing with "Error") - fixed by the fit check; N1 / N3 / N4 accepted.
- Review 2 (four launches; the first three waited on their own probes and looked stopped): partial
  results found case-only twins (feature 252's defect now reachable) - fixed; the final report: no
  MUST; SHOULD S1 (cleaning before the code page conversion changed Shift-JIS letters) - fixed;
  N1 (CHANGELOG wording) - fixed; N2 (fit pass reads twice, read-error dialogs twice), N3
  (collisions after cleaning ask before overwriting) - accepted, recorded in `fix-log.md`.

## Owed to a person (with the new person-step items)

- `check-iso-rock-ridge-names-in-a-shift-jis-image-on-a` - Check ISO Rock Ridge names in a
  Shift-JIS image on a Japanese-locale Windows (the S1 order could not be driven on code page 1250).

## New Inbox items (slug - title)

- `iso-plug-in-joliet-and-iso-9660-names-are-not-made-safe` - ISO plug-in: Joliet and ISO 9660
  names are not made safe before extraction
- `iso-plug-in-an-entry-the-listing-refuses-ends-the-listing` - ISO plug-in: an entry the listing
  refuses ends the listing with Error, a folder lost
- `check-iso-rock-ridge-names-in-a-shift-jis-image-on-a` - Check ISO Rock Ridge names in a
  Shift-JIS image on a Japanese-locale Windows (person step)
