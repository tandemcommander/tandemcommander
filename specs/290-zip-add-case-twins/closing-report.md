# Closing report - 290-zip-add-case-twins
Backlog item: adding-a-file-into-a-zip-that-holds-names-differing-only-in - Adding a file into a ZIP that holds names differing only in case can replace the other twin
Outcome: closed

## What changed

- `src/plugins/zip/add.cpp` `CZipPack::MatchFiles`: the members' names (as `ProcessName` gives them
  to the listing) are collected from the central directory the add already holds; when some folder
  holds case twins (271's rule), each added item is matched by its exact name - the panel's folder
  and the part below it - in Windows- and Unix-made ZIPs alike. Without twins nothing changes. Low
  memory refuses the add (IDS_LOWMEM) before any question.
- `src/common/salcasetwins.h`: `SalPathsHaveCaseTwins` - 252's twin test on flat paths, part by part
  within each folder (the folder told apart by its bytes), the same decision as
  `SalDirTreeHasCaseTwins` on the tree.
- `src/common/salzipname.h`: `SalZipMemberIs` / `SalZipMemberIsOrIsIn` gain `nameIgnoreCase`
  (default TRUE = unchanged for every other caller).
- `src/saltests/saltests.cpp`: `TestPathTwins290` (item cases, edges, legacy pair, the reviewer's
  invalid-WTF-8 folder case, an 8000-round randomized cross-check against the tree rule, the new
  `nameIgnoreCase` variants).
- `specs/110-zip-plugin-name-matching/probe/zipname_probe.ps1`: nine `r_3*` rows (twin archives)
  re-baselined to 290's behaviour; two duplicate-member rows (`v_dupys`, `v_dupyc`) keep 110's
  mixed-answer path driven.
- Known change: in a twin archive `B.txt` is added beside `b.txt` without a question (item
  *Expected*: exact names).

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\290-zip-add-case-twins\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\290-zip-add-case-twins\probe\zip290_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`

- before (1e402ea2): 6 FAIL / 12 PASS - ZIP-ADDDIR (D/x.txt lost), ZIP-ADDFILE (A.txt lost, 2
  questions), ZIP-ADDFOLDER (D/x.txt lost), ZIP-NEWNAME (b.txt replaced), UNIX-ADDFILE (A.txt
  replaced for a.txt), UNIX-ADDFOLDER (D/x.txt replaced).
- after (final build): 18 PASS / 0 FAIL / 0 NOT DRIVEN; every row asserts its question count.
- negative control (twin switch short-circuited): 12 PASS / 6 FAIL - the six rows of the before-run.
- Registry restored and identical (SHA-256 8079B0...0CAE) in every run.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED` (attempt 1 failed on `deflate.h`'s `Len` macro; fixed).
- `saltests.exe` -> `saltests: 25281 checks, 0 failed`; unit negative controls: prefixes disabled ->
  9 failed; whole-prefix comparison -> 3 failed.
- Regression probes: 110 `zipname_probe` 44 / 0 (after re-baselining 9 twin-archive rows, first run
  33 / 9); 271 `zip271_probe` 16 / 0; 108 `namecoll_probe` 30 / 0.

## Reviews (findings and what was done)

One refute-first review, no MUST. SHOULD 1 (whole prefixes missed ordinal twins below a folder that
is not valid WTF-8) fixed - the rule compares part by part per folder, with saltests and a negative
control. SHOULD 2 (110's SF1 path no longer driven) fixed - duplicate-member rows. NOTE 6 (question
counts) fixed. NOTE 3 (~1-3 s per add into a 200,000-member ZIP), NOTE 4 (a legacy-fold pair makes
the archive exact), NOTE 5 (typed folder in another case: existing backlog item) recorded as limits.

## Owed to a person (with the new person-step items)

None - every row was driven on the hidden desktop (no clipboard, keyboard or printer involved).

## New Inbox items (slug - title)

None.
