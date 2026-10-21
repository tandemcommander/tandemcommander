# Closing report - 280-user-menu-long-paths
Backlog item: user-menu-long-paths - User Menu on items in folders of 260 or more bytes: work, or refuse aloud
Outcome: closed

## What changed

- Every value the User Menu inserts into a command is whole, or the command is refused with
  "Cannot finish operation because of too long name." before anything runs. Per route (spec
  *Clarifications*): item folder + name (panel focus / selection, Find results) - refuse, from
  whole values; route without a shell - prepare all, then start; `$(FullPathLeft/Right/Inactive)`
  - refuse (was: the parent folder, or "not defined"); names to compare - refuse when chosen,
  a guessed one that does not fit is no match (as before); panel's `$(ListOfSelectedFullNames)` -
  work (whole).
- `src/common/salumvalue.h` (new, saltests `TestUserMenuValue280`); `src/mainwnd.h` (the internal
  enumeration contract `UM_GetNextFileName` -> `UMNEXT_*`, `UM_ITEM_TEXT_SIZE`;
  `CUMDataFromPanel::EndReached`; `UserMenu` returns BOOL); `src/execute.h` (five "too long"
  flags); `src/mainwnd4.cpp`, `src/mainwnd3.cpp`, `src/finddlg1.cpp`.
- No UI strings, no plug-in interface, no registry, no network change.

## Measurements (before / after, commands)

- Probe `probe/um280_probe.ps1` on the hidden desktop
  (`powershell -File tools\run_on_hidden_desktop.ps1 ... um280_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe`):
  before (d7405c6a, first version of the probe, 10 cases) 15 PASS / 5 FAIL - FPRCUT (the command
  got the parent folder), FPRLONG, MIXDIRECT, LISTFULL, CMPLONG; before re-measured by review 2 with
  the final probe on main's sources: 23 / 5 (the same five); after: **30 PASS / 0 FAIL** (15
  cases), registry restored identical (`probe/result_after.txt`).
- Negative controls: the old copy / start loop put back -> MIXDIRECT, FPRCUT, FPRLONG fail
  (review 1); review 1's bugs put back -> CMPGUESS, LAUNCHFAIL fail (review 2); the selection never
  cleared -> CLEARSEL fails (`-Only CLEARSEL`, reverted and rebuilt).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd` (Debug x64): BUILD SUCCEEDED.
- `saltests.exe`: `saltests: 24986 checks, 0 failed`.
- Probes: um280 30 / 0; regression 226 `28 / 0`, 229 `34 / 0`, 234 `5 / 0, NOT DRIVEN 3` (as
  recorded by 234).

## Reviews (findings and what was done)

- Review 1: no MUST. SHOULD - a failed start without a shell cleared the selection (fixed:
  `EndReached`, `UserMenu`'s result, the caller clears); SHOULD - a guessed second compare name
  that does not fit refused the command (fixed: no match). NOTEs fixed: low memory silent,
  indentation, a header comment; list-order limit recorded (Inbox).
- Review 2: no MUST. SHOULD - no row proved the selection is still cleared after success (fixed:
  row CLEARSEL + negative control). NOTEs: stale contract / research text and SC-001 counting
  (fixed); a focused second compare name counts as chosen (kept, the spec's rule); a one-name
  compare command is not reachable (validation needs both).

## Owed to a person (with the new person-step items)

- `user-menu-from-find-results-in-folders-of-260-or-more-bytes` - the Find window's User Menu
  with results in a 260+ byte folder (a popup menu, not driven on the hidden desktop).

## New Inbox items (slug - title)

- user-menu-from-find-results-in-folders-of-260-or-more-bytes - User Menu from Find results in folders of 260 or more bytes driven by a person
- user-menu-list-commands-refused-when-the-first-selected-item - User Menu list commands refused when the first selected item does not fit 259 bytes
