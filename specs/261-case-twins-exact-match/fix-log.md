# Fix log: 261 - case twins are addressed exactly (Compare Directories, viewer, User Menu, Ctrl+X)

Backlog item `case-sensitive-twins-first-match` (leftover of 230-232). A case-sensitive folder can
hold `a.txt` and `A.txt`; four places took the first name equal ignoring case.

## Measured (before, at 61ceb283)

Probe `probe/twin261_probe.ps1` on the hidden desktop, `probe/result_before.txt`: **5 FAIL**
(14 rows: 7 RUN + 7 END):

- **CMPTWIN1** (left case-sensitive `a.txt` "lower!" + `A.txt` "UP", right `A.txt` "UP"): both
  left twins marked - `a.txt` was paired with the right `A.txt` (by size: different), the left
  `A.txt` then had no pair;
- **CMPTWINR** (left `A.txt` "UP12", right case-sensitive `a.txt` "x" + `A.txt` "UP12"): left
  `A.txt` paired with the right `a.txt` and marked;
- **CMPSUB** (sub-folders `aB.txt` + `Ab.txt` vs `ab.txt` + `AB.txt`, sizes equal by position):
  "The files in two directories appear to be identical";
- **VIEWNEXT** (viewer - the Code Viewer plug-in, the default for .txt - on `A.txt` of `a.txt`,
  `A.txt`, `z.txt`; another program creates `0.txt`; Refresh): next file shows `A.txt` again -
  the remembered index now holds `a.txt`, accepted ignoring case;
- **VIEWPREV**: previous file shows `0.txt` instead of `a.txt`;
- controls CMPTWIN2 (the twin that sorts first is paired right) and CMPSINGLE (`Readme.txt` /
  `README.txt` in two case-sensitive folders without twins: one name, feature 232) PASS.

(The first before run posted the internal viewer's command ids to the Code Viewer window - no
effect; the probe now picks the ids by the window title. Recorded result is the second run.)

By reading (callers enumerated with Grep):
- User Menu compare name 2 (`mainwnd3.cpp`, the other panel's loop) and Ctrl+X ghosting in the
  other panel on the same folder (`shellsup.cpp`, dirs and files loops) break at the first
  `SalNameEqualOrdinalCI` match.
- Remembered folder sizes (`CDirectorySizesHolder`, `salamdr6.cpp`): **unreachable** - the only
  `Store` / `Restore` calls are commented out (`fileswn8.cpp` "//            DirectorySizesHolder.Store(this)",
  `fileswn3.cpp` "// to DirectorySizesHolder.Restore(this)"), `Get` has no caller. No change.
- Turkish / Azeri: `RegSetStrICmpEx` is the panel's sort key - out of scope, own Inbox item.

## Work

Final state (after review 1; the first version is described under *Review*):

- `src/common/salnamerun.h` (feature 230's header, core only): `SalNamePickIndex` - a lookup takes
  the byte-identical candidate, else the only one equal by `SalNameEqualOrdinalCI`, never one of
  two; `SalHasCaseTwinInRun` - a twin is a neighbour of the same first sort key, byte-different and
  the same name ignoring case; `SalTwinRunPairs` - a run pair (one first key on both sides) is
  paired as a set: byte-identical names, then case-only pairs between names without twins;
  `SalTwinRunOrder` / `SalTwinRunSlotCmp` - the run is walked pairs first.
- `src/mainwnd5.cpp` Compare Directories: `CmpDirsNames` with the context `CCmpDirsRun`: when the
  merge meets a run pair and either run holds a twin, `CmpDirsAlignRun` pairs it and rearranges both
  runs of the comparison's copies pairs first (low memory: no pair - every name of the run reported
  alone); positions are then compared. Without twins `CmpNameExtIgnCase` as before (232). The panel
  merge (files, directories, both passes) and the sub-folder check (files, directories) use it; the
  copies are sorted back to the panel's order before the marks are transferred by index also when
  the panel sorts by name and a run was rearranged (`LeftMoved` / `RightMoved`).
- `src/fileswnb.cpp` viewer next / previous (WM_USER_ENUMFILENAMES): the remembered index counts
  only with the byte-identical name; otherwise `SalNamePickIndex` over `Files`.
- `src/mainwnd3.cpp` User Menu compare name 2: `SalNamePickIndex` over the other panel's items of
  the same kind (dirs or files, as Ctrl+X - review N1).
- `src/shellsup.cpp` Ctrl+X ghosting in the other panel on the same folder: `SalNamePickIndex`
  over its `Dirs` / `Files`.
- `src/saltests/saltests.cpp` `TestNameRules261`: the pick (exact, single CI, two CI, none, NULL,
  given length, WTF-8 lone surrogate, caron, duplicates, NFC vs NFD), twin detection, the run
  pairing / order / slot comparison, and a model of `CmpDirsNames` (first key ignoring a soft hyphen,
  as the locale key does; lazy alignment; two passes) over the probe rows, twins against a third
  case, several runs and the soft-hyphen case of the review.
- Not changed: `CDirectorySizesHolder` (unreachable); the Find window's viewer enumeration
  (`finddlg1.cpp`) has the same first-match lookup - not named by the item, Inbox (`measure:261`).

Decisions (spec Clarifications): a lookup keeps its single case-insensitive fallback (today's
behaviour); twins against a third case pair nothing. The item's hint "`CmpNameExt` when both panels
are case-sensitive" replaced by set pairing of runs with twins (research R1).

## Checks

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `build.cmd` (Debug x64): BUILD SUCCEEDED.
- `saltests`: 24,600 checks, 0 failed.
- Negative control 1 (first version): `SalTwinAwarePairCmp` always the 232 comparison and
  `SalNamePickIndex` taking the first case-insensitive match: 7 failed. Restored.
- Negative control 2 (final version): `SalTwinRunPairs` without its case-only step: **5 failed**
  (the run pairing checks, the soft-hyphen merges both ways). Restored, rebuilt, 0 failed.
- Negative control (probe): the before run on the build without the fix - 5 FAIL; CMPSHY on the
  first version FAIL and on 0.1.10 PASS (measured by the review).

## Measured (after)

`probe/result_after.txt` (final build): **PASS 16, FAIL 0, NOT DRIVEN 0** - CMPTWIN1 only `a.txt`
marked (its run was rearranged, the marks land on the right file after the re-sort), CMPTWINR left
`A.txt` paired, CMPSUB `Sub` marked different, CMPSINGLE still one name, CMPSHY the case-only pair
beside twins paired, VIEWNEXT `z.txt`, VIEWPREV `a.txt`; registry restored and identical.
Regression: `cmp232_probe.ps1` on the final build (`probe/result_cmp232.txt`): PASS 16, FAIL 0.

## NOT DRIVEN (owed to a person)

- Ctrl+X ghosting: the hidden desktop shares the maintainer's clipboard - not driven.
- User Menu compare names: needs a configured User Menu item with `$(CompareName2)` - not driven.
Both use the rule checked by `saltests`; person-step item at closing.

## Review

Review 1 (refute-first, independent agent): no MUST. Re-ran the probe (14 / 0 on the fix, 5 FAIL
on the installed 0.1.10 - the rows do fail without the fix) and `cmp232_probe` 16 / 0.
- **S1 (taken)**: the first version chose per pair between `CmpNameExt` (a twin involved) and
  `CmpNameExtIgnCase`; the locale first key ignores a soft hyphen (and folds NFC / NFD), so the two
  orders disagree inside one run and the merge stepped past a partner: L `a<SHY>b.txt`, R (CS)
  `ab.txt`, `AB.txt`, `A<SHY>B.txt` - the left file marked on the fix build, not on 0.1.10. Fixed by
  set pairing of runs (Work above); probe row CMPSHY.
- **S2 (taken)**: the tests modelled the first key with the ordinal rule only - now a coarser key
  (soft hyphen ignored) and a model of `CmpDirsNames` with both passes.
- N1 (taken): User Menu looks up within the item's kind. N5 (taken): shadowed lambda parameter.
- N2 (Inbox): Ctrl+X decides "the same folder" by `SalPathEqualOrdinalCI` - twin folders `Sub` /
  `SUB` count as one.
- N3 (closing): the promised Inbox items (Find window, Turkish / Azeri) are filed at closing.
- N4 (accepted): a pair of one first key costs a few more locale comparisons (run ends, twin
  neighbours); only on the first comparison of a run pair.
