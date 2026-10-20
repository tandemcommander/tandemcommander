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

- `src/common/salnamerun.h` (feature 230's header, core only): `SalNamePickIndex` - a lookup takes
  the byte-identical candidate, else the only one equal by `SalNameEqualOrdinalCI`, never one of
  two; `SalHasCaseTwinInRun` - a twin is a neighbour of the same first sort key, byte-different and
  the same name ignoring case; `SalTwinAwarePairCmp` - byte-exact order when either side has a twin,
  else 232's comparison.
- `src/mainwnd5.cpp` Compare Directories: `CmpDirsNames` (first key `RegSetStrICmpEx`, twins on
  either list -> `CmpNameExt`, the lists' sort order; else `CmpNameExtIgnCase`) in the panel merge
  of files and directories and in the sub-folder check (files, directories).
- `src/fileswnb.cpp` viewer next / previous (WM_USER_ENUMFILENAMES): the remembered index counts
  only with the byte-identical name; otherwise `SalNamePickIndex` over `Files`.
- `src/mainwnd3.cpp` User Menu compare name 2: `SalNamePickIndex` over the other panel's dirs +
  files, then the file / directory kind check (before: the first case-insensitive match, and a
  kind mismatch of that one gave no name even when the exact twin had the right kind).
- `src/shellsup.cpp` Ctrl+X ghosting in the other panel on the same folder: `SalNamePickIndex`
  over its `Dirs` / `Files`.
- `src/saltests/saltests.cpp` `TestNameRules261`: the pick (exact, single CI, two CI, none, NULL,
  given length, WTF-8 lone surrogate, caron, duplicates, NFC vs NFD), twin detection, the pair
  comparison and a merge simulation of the probe rows plus twins against a third case.
- Not changed: `CDirectorySizesHolder` (unreachable); the Find window's viewer enumeration
  (`finddlg1.cpp`) has the same first-match lookup - not named by the item, Inbox (`measure:261`).

Decisions (spec Clarifications): a lookup keeps its single case-insensitive fallback (today's
behaviour); twins against a third case pair nothing. The item's hint "`CmpNameExt` when both panels
are case-sensitive" generalised to "where a twin exists" (research R1).

## Checks

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.uild.cmd`: BUILD SUCCEEDED.
- `saltests`: 24,594 checks, 0 failed.
- Negative control (saltests): `SalTwinAwarePairCmp` returning the 232 comparison always and
  `SalNamePickIndex` taking the first case-insensitive match: **7 failed** (the pick of "A.TXT"
  among two twins, the pair comparison, merges CMPTWIN2 / CMPSUB / third case both ways). The
  merges CMPTWIN1 / CMPTWINR pass even then - in the test's byte tie-break "A.txt" sorts before
  "a.txt" so the first CI match happens to be right; CMPTWIN2 is their mirror and catches it. (The
  panel's locale order puts "a.txt" first, which is why the probe's CMPTWIN1 failed before.)
  Restored, rebuilt, 0 failed.
- Negative control (probe): the before run on the build without the fix - 5 FAIL.

## Measured (after)

`probe/result_after.txt`: **PASS 14, FAIL 0, NOT DRIVEN 0** - CMPTWIN1 only `a.txt` marked,
CMPTWINR left `A.txt` paired, CMPSUB `Sub` marked different, CMPSINGLE still one name, VIEWNEXT
`z.txt`, VIEWPREV `a.txt`; registry restored and identical.
Regression: `cmp232_probe.ps1` on this build (`probe/result_cmp232.txt`): PASS 16, FAIL 0.

## NOT DRIVEN (owed to a person)

- Ctrl+X ghosting: the hidden desktop shares the maintainer's clipboard - not driven.
- User Menu compare names: needs a configured User Menu item with `$(CompareName2)` - not driven.
Both use the rule checked by `saltests`; person-step item at closing.
