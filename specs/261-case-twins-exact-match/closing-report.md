# Closing report - 261-case-twins-exact-match
Backlog item: case-sensitive-twins-first-match - Case-sensitive folders: several features take the first case-insensitive twin
Outcome: closed

## What changed

- `src/common/salnamerun.h`: `SalNamePickIndex` (a lookup takes the byte-identical item, else the
  only one equal ignoring case, never one of two); `SalHasCaseTwinInRun`; `SalTwinRunPairs`,
  `SalTwinRunOrder`, `SalTwinRunSlotCmp` (a run of one sort key that holds twins is paired as a set
  and walked pairs first).
- `src/mainwnd5.cpp` Compare Directories: `CmpDirsNames` with `CCmpDirsRun` / `CmpDirsAlignRun` in
  the panel merge (files, directories, both passes) and the sub-folder check; ignored names are
  skipped again after a rearrangement; the copies are sorted back to the panel's order before the
  marks are transferred also in name mode when a run was rearranged.
- `src/fileswnb.cpp` viewer next / previous; `src/mainwnd3.cpp` User Menu compare name 2 (within
  the item's kind); `src/shellsup.cpp` Ctrl+X ghosting - all through `SalNamePickIndex`.
- `src/saltests/saltests.cpp` `TestNameRules261`.
- Not changed: remembered folder sizes (`CDirectorySizesHolder`) - unreachable (its Store /
  Restore calls are commented out); the Turkish / Azeri locale comparison - its own Inbox item.

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\261-case-twins-exact-match\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\261-case-twins-exact-match\probe\twin261_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`

- Before (61ceb283): 5 FAIL of 14 rows - CMPTWIN1, CMPTWINR, CMPSUB, VIEWNEXT, VIEWPREV.
- After (final build): PASS 16, FAIL 0 (row CMPSHY added by review 1; it failed on the first
  version of the fix and passes on 0.1.10 and now).
- Regression `specs\232-compare-dirs-case-only-names\probe\cmp232_probe.ps1`: PASS 16, FAIL 0.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd` (Debug x64): BUILD SUCCEEDED.
- `saltests`: 24,603 checks, 0 failed. Negative controls: the first rules broken - 7 failed; the
  case-only step of `SalTwinRunPairs` removed - 5 failed.
- Probes: twin261 16 / 0, cmp232 16 / 0; registry restored and identical every run.

## Reviews (findings and what was done)

- Review 1: no MUST. S1 (pair-by-pair comparison inconsistent with the locale sort order; a
  case-only pair beside twins missed, measured) - fixed by the set pairing of runs, probe row
  CMPSHY; S2 (tests modelled only the ordinal key) - a coarser key and a model of `CmpDirsNames`;
  N1 (User Menu within the kind) and N5 (shadowed lambda parameter) - fixed; N2 - Inbox; N3 -
  Inbox items filed; N4 cost - accepted.
- Review 2: no MUST. S1 (the same defect in runs without twins, pre-existing on 0.1.10) - Inbox;
  S2 (the test model's tie-break order) - fixed; NOTE 1 (ignore mask before a rearrangement) -
  fixed; NOTE 2 (duplicate names in a ZIP with twins in one run, unstable re-sort) - accepted and
  recorded; NOTE 3 pre-existing; NOTE 4 accepted. The reviewer's extended probe (both panels, every
  sort mode, by content, twin folders) passed on the fix.

## Owed to a person (with the new person-step items)

- `check-ctrl-x-ghosting-and-user-menu-compare-names-with-case` - Ctrl+X ghosting and the User
  Menu's compare names with case twins (the hidden desktop has no own clipboard; a User Menu item
  must be configured).

## New Inbox items (slug - title)

- find-window-the-viewer-next-previous-file-takes-the-first - Find window: the viewer next / previous file takes the first case-insensitive twin
- turkish-azeri-locale-index-html-and-index-html-never-compare - Turkish / Azeri locale: index.html and INDEX.HTML never compare as one name
- ctrl-x-ghosts-a-name-in-the-other-panel-that-shows-a-case - Ctrl+X ghosts a name in the other panel that shows a case twin folder
- compare-directories-misses-a-case-only-pair-beside-a-soft - Compare Directories misses a case-only pair beside a soft-hyphen or NFD name
- check-ctrl-x-ghosting-and-user-menu-compare-names-with-case - Check Ctrl+X ghosting and User Menu compare names with case twins (person step)
