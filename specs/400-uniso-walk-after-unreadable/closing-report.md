# Closing report - 400-uniso-walk-after-unreadable
Backlog item: iso-plug-in-after-a-folder-that-cannot-be-read-no-later - ISO plug-in: after a folder that cannot be read, no later folder of the image is listed
Outcome: closed

## What changed

- `src/common/salisowalk.h` (new, header-only): the walk state `SalIsoWalk { Stopped, BoxShown }` and
  three rules - `SalIsoWalkDescends` (descend every listed folder unless out of memory stopped the
  walk), `SalIsoWalkAfterChild` (a failure below keeps the directory incomplete and is never forgotten
  by a later folder that walks whole), `SalIsoWalkBoxQuiet` (one error box per walk; quiet walks stay
  quiet).
- `src/plugins/uniso/iso9660.*`: `CISO9660::ListDirectoryRe` descends by the rule; out-of-memory sites
  go through `WalkOutOfMemory()`; the "Error reading directory structure" boxes of the walk and of
  368's `ChainNotListed` are shown once per walk; a fresh walk state for the boot record, the fit walk
  and the listing walk; `CountUnder` keeps its own.
- `src/plugins/uniso/udf.*`, `xdvdfs.*`: the same rule in `ScanDir`; a visited set per listing walk
  (UDF: the folder's file entry; Xbox: start sector and size - review 1); a folder met again is listed
  empty and marks the listing incomplete (review 2: fail closed).
- `src/saltests/saltests.cpp`: `TestIsoWalk400` (38 checks on model trees).
- No UI string, no translation change, no plug-in interface change.

## Measurements (before / after, commands)

- Before (main aaf95b94): `iso330_probe.ps1 -Only RD-EXT,RD-REC,UD-EXT,UD-TAG,XD-EXT` on the hidden
  desktop - each extracts `top.txt` but not `zlast/z.txt` of the damaged file system.
- New probe `probe/iso400_probe.ps1` (tools\run_on_hidden_desktop.ps1): before 28 / 12
  (`result_before.txt`, `result_before_rows2.txt`; XD-LOOP2 did not answer - a pre-existing exponential
  walk) -> after 40 / 0 (`result_after.txt`) -> after review 1 44 / 0 -> after review 2 48 / 0
  (`result_after_review2.txt`, 24 RUN rows). The item's rows RD-EXT, RD-REC, RD-ZERO, UD-EXT, UD-TAG,
  XD-EXT now extract `zlast/z.txt` with one box (none for RD-ZERO) and keep the image.
- Negative control (visited sets off, every box shown; `result_negctl.txt`): 5 / 7 - two boxes for
  two damaged folders, 67 boxes and no listing for XD-LOOP, a hang for XD-LOOP2, the "(206)" report
  for UD-LOOP.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` -> BUILD SUCCEEDED (Debug x64).
- saltests 282,271 -> 282,309 checks, 0 failed (run from E:; the total depends on the volume, tests
  304 / 305). Mutants of the three rules: 6, 5 and 3 failed checks.
- Probes: 400 48 / 0; regressions 328 20 / 0 (LOOP rows), 329 14 / 0 (again after both review fixes),
  327 77 / 0. Registry restored and identical after every run.

## Reviews (findings and what was done)

- Review 1: MUST 1 - the Xbox visited key by start sector alone listed a larger folder at the same
  sector empty and Unpack deleted the image (regression against main) -> keyed by sector and size,
  rows XD-SHARE / XD-MANY. SHOULD 1 - the ISO 9660 walk (328) has the same key -> Inbox. NOTEs recorded.
- Review 2: no MUST. SHOULD 1 - two folders naming one directory lost the second path and the image
  was deleted -> a folder met again marks the listing incomplete, rows XD-HLINK / UD-HLINK; spec
  FR-005 / FR-006 updated. NOTE 3 (pre-existing Xbox name over-read) -> Inbox. Saltests total
  difference explained (volume-dependent tests).

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below to `CHANGELOG.md` (no `## [Unreleased]` section exists; versions are
  the maintainer's):

  ```text
  - **A disc image with a folder that cannot be read lists its later folders** (feature 400).
    - **Before:** when the ISO plug-in could not read one folder of an ISO 9660, UDF or Xbox image
      (its directory past the end of the image, a damaged record), every later folder of that image
      was shown empty - its files could not be viewed or extracted, although they were readable.
    - **Now:** every folder that can be read is listed, before and after the damaged one; the error
      box is shown once per listing (not once per damaged folder), and a whole Unpack with "Delete
      archive after unpacking" still keeps such an image. A crafted image whose folders point back
      to themselves opens at once; an image whose two folders name one directory lists the second
      one empty and is kept by such an Unpack.
    - **Limitation:** the rest of a damaged folder itself is not listed; out of memory still ends
      the listing of later folders.
  ```

- Nothing else: every probe row was driven on the hidden desktop.

## New Inbox items (slug - title)

- `iso-plug-in-an-iso-9660-folder-met-again-with-a-larger` - ISO plug-in: an ISO 9660 folder met
  again with a larger length is listed empty (review:400)
- `iso-plug-in-an-xbox-entry-name-can-be-read-past-the-end-of` - ISO plug-in: an Xbox entry name can
  be read past the end of its directory (review:400)
