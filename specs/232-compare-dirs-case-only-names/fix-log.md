# Fix log: 232 - names that differ only in case are one name again (Compare Directories, refresh)

Backlog (231's review): `CmpNameExtIgnCase` (`sort.cpp`) - feature 004 (cfb8213d) added a tie-break
for canonically equivalent names (NFC vs NFD - two files, FR-009 of 004) that also made names
differing only in case unequal. Its callers use it as an equality test.

## Measured (before)

Probe `probe/cmp232_probe.ps1`. The build at 231 (`probe/result_before.txt`): **4 FAIL**:
- **FILE / DIR: Compare Directories marked "Readme.txt" (left) and "README.txt" (right) - the same
  content and time, an ordinary folder - as different** (both unpaired); the same for a folder
  "Sub" / "SUB" with the same content. A regression against upstream that anyone could hit;
- **RENSEL: after another program renamed a selected Readme.txt to README.txt, a refresh lost the
  selection - and Change Attributes then acted on the focused z.txt**;
- **CSKEEP2: in a case-sensitive folder (231) holding a.txt and A.txt, the selected twin that sorts
  second was lost on every refresh** (the merge walked twins in another order than the list);
- CONTROL (sizes differ), FILECS (the same case), NFD (NFC vs NFD stay two names), CSKEEP1: as
  expected.

## Work

`src/sort.cpp` `CmpNameExtIgnCase`: the tie-break is now the file system's ordinal ignore-case order
(`SalNameCompareOrdinalCI`) - its equality is exactly "the same name", so a case-only pair compares
equal (as upstream) while NFC / NFD stay apart, and the comparison is a strict weak order also for
mixed case + normalization groups (review); the result is normalized to -1 / 0 / 1 (Compare
Directories tests `== -1` / `== 1` and took anything else for "equal" - a raw `memcmp` of a fallback
for names that are not UTF-8 paired two different names; review).

`src/fileswn0.cpp` refresh merge: a flag (selection, size, cut mark, overlay) moves to a name in
another case only when the old listing did not hold that name byte for byte (`OldGroupHasExactName`) -
a twin that was there before on a source that does not declare case sensitivity (SFTP, 7-Zip, TAR)
never inherits the other twin's selection (review).

Build: BUILD SUCCEEDED; saltests 22,682 checks, 0 failed; `check_encoding.py` TOTAL 0.

## Measured (after)

`probe/result_after.txt` **16 / 0**. The negative control above is the final probe on the build
without 232.

## Review

Refute-first review: no MUST. Taken: the tie-break as one ordinal ignore-case comparison (NIT 4 -
transitivity), the twin guard in the refresh merge (SHOULD 1 - an undeclared case-sensitive source),
the CSKEEP rows (SHOULD 2), the -1 / 0 / 1 normalization (NIT 5). Recorded in NEXT-WORK: in Turkish /
Azeri locales the locale comparison never makes "index.html" and "INDEX.HTML" equal (upstream);
Compare Directories may pair the wrong twin in case-sensitive folders (compare with `CmpNameExt`
when both panels are case-sensitive); SFTP should declare its case sensitivity.
